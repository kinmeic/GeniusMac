import Foundation
import AppKit
import CoreGraphics
import Darwin

protocol PixelMonitorDelegate: AnyObject {
    func pixelMonitor(_ monitor: PixelMonitor, didUpdate event: CaptureEvent)
    func pixelMonitor(_ monitor: PixelMonitor, didTriggerKey keyCode: CGKeyCode, event: CaptureEvent)
}

final class PixelMonitor {
    weak var delegate: PixelMonitorDelegate?

    private let queue = DispatchQueue(label: "com.genius.mac.pixel-monitor", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    private var cachedWindowInfo: WindowInfo?
    private var cachedDisplayColorSpace: CGColorSpace?
    private var lastWindowRefreshTime: CFTimeInterval = 0
    private var lastProcessCheckTime: CFTimeInterval = 0
    private var lastPermissionCheckTime: CFTimeInterval = 0
    private var lastUIReportTime: CFTimeInterval = 0
    private var lastReportedRGB: Int?
    private var screenCaptureAllowed = true
    private var pixelData = [UInt8](repeating: 0, count: 16)
    private let targetColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    var targetPID: pid_t?
    var x: Int = 1
    var y: Int = 1
    var interval: TimeInterval = 0.1
    var filterG: Int = 0
    var filterB: Int = 0
    var keyMappings: [Int: CGKeyCode] = [:]

    private var isTargetForeground = false

    private let windowRefreshInterval: CFTimeInterval = 0.5
    private let processCheckInterval: CFTimeInterval = 1.0
    private let permissionCheckInterval: CFTimeInterval = 1.0
    private let uiReportInterval: CFTimeInterval = 0.1

    var isEnabled: Bool { isRunning }

    func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        queue.async { [weak self] in
            self?.cachedWindowInfo = nil
            self?.cachedDisplayColorSpace = nil
            self?.lastWindowRefreshTime = 0
            self?.lastProcessCheckTime = 0
            self?.lastPermissionCheckTime = 0
            self?.lastUIReportTime = 0
            self?.lastReportedRGB = nil
            self?.screenCaptureAllowed = self?.hasScreenRecordingPermission() ?? false
            self?.rescheduleTimer()
        }
    }

    func stop() {
        isRunning = false
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
            self?.cachedWindowInfo = nil
            self?.cachedDisplayColorSpace = nil
        }
    }

    func updateInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        guard isRunning else { return }
        queue.async { [weak self] in
            self?.rescheduleTimer()
        }
    }

    func updateForegroundState(_ isForeground: Bool) {
        queue.async { [weak self] in
            self?.isTargetForeground = isForeground
        }
    }

    private func rescheduleTimer() {
        timer?.cancel()

        let source = DispatchSource.makeTimerSource(queue: queue)
        let repeating = DispatchTimeInterval.nanoseconds(max(Int(interval * 1_000_000_000), 1_000_000))
        source.schedule(deadline: .now(), repeating: repeating, leeway: .milliseconds(1))
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = source
        source.resume()
    }

    private func tick() {
        guard let pid = targetPID else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .processExited))
            return
        }

        let now = CFAbsoluteTimeGetCurrent()

        if now - lastProcessCheckTime >= processCheckInterval {
            lastProcessCheckTime = now
            guard isProcessAlive(pid) else {
                delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .processExited))
                return
            }
        }

        if now - lastPermissionCheckTime >= permissionCheckInterval {
            lastPermissionCheckTime = now
            screenCaptureAllowed = hasScreenRecordingPermission()
        }

        guard screenCaptureAllowed else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .permissionDenied))
            return
        }

        guard let windowInfo = currentWindowInfo(forPID: pid, now: now) else {
            report(CaptureEvent(error: .noWindowHandle), now: now, force: false)
            return
        }

        capturePixelViaScreen(at: windowInfo, now: now)
    }

    private func isProcessAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private func currentWindowInfo(forPID pid: pid_t, now: CFTimeInterval) -> WindowInfo? {
        if let cachedWindowInfo, now - lastWindowRefreshTime < windowRefreshInterval {
            return cachedWindowInfo
        }

        guard let refreshed = findWindowInfo(forPID: pid) else {
            cachedWindowInfo = nil
            cachedDisplayColorSpace = nil
            lastWindowRefreshTime = now
            return nil
        }

        cachedWindowInfo = refreshed
        cachedDisplayColorSpace = colorSpaceForDisplay(
            containing: CGPoint(
                x: refreshed.bounds.origin.x + CGFloat(x),
                y: refreshed.bounds.origin.y + CGFloat(y)
            )
        )
        lastWindowRefreshTime = now
        return refreshed
    }

    private func capturePixelViaScreen(at windowInfo: WindowInfo, now: CFTimeInterval) {
        let screenX = windowInfo.bounds.origin.x + CGFloat(x)
        let screenY = windowInfo.bounds.origin.y + CGFloat(y)
        let captureBounds = CGRect(x: screenX, y: screenY, width: 1, height: 1)

        guard let image = CGWindowListCreateImage(
            captureBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            cachedWindowInfo = nil
            cachedDisplayColorSpace = nil
            report(CaptureEvent(error: .noWindowHandle), now: now, force: false)
            return
        }

        if let event = extractColor(from: image, displayColorSpace: cachedDisplayColorSpace) {
            triggerKeyIfNeeded(for: event)
            report(event, now: now, force: false)
        } else {
            report(CaptureEvent(error: .noWindowHandle), now: now, force: false)
        }
    }

    private func extractColor(from image: CGImage, displayColorSpace: CGColorSpace?) -> CaptureEvent? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let sourceColorSpace = displayColorSpace ?? image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let requiredByteCount = width * height * bytesPerPixel
        if pixelData.count < requiredByteCount {
            pixelData = [UInt8](repeating: 0, count: requiredByteCount)
        }

        let drewImage = pixelData.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: sourceColorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard drewImage else { return nil }

        let r = CGFloat(pixelData[0]) / 255.0
        let g = CGFloat(pixelData[1]) / 255.0
        let b = CGFloat(pixelData[2]) / 255.0
        let a = CGFloat(pixelData[3]) / 255.0

        let convertedComponents: [CGFloat]
        if let sourceColor = CGColor(colorSpace: sourceColorSpace, components: [r, g, b, a]),
           let convertedColor = sourceColor.converted(to: targetColorSpace, intent: .defaultIntent, options: nil),
           let components = convertedColor.components {
            convertedComponents = components
        } else {
            convertedComponents = [r, g, b, a]
        }

        let red = Int((convertedComponents[0] * 255.0).rounded())
        let green = Int((convertedComponents[1] * 255.0).rounded())
        let blue = Int((convertedComponents[2] * 255.0).rounded())

        var event = CaptureEvent(error: .success)
        event.r = red
        event.g = green
        event.b = blue
        event.rgb = (red) | (green << 8) | (blue << 16)
        return event
    }

    private func triggerKeyIfNeeded(for event: CaptureEvent) {
        guard isTargetForeground,
              event.g == filterG,
              event.b == filterB,
              let keyCode = keyMappings[event.r] else {
            return
        }

        KeySimulator.press(keyCode: keyCode)
        delegate?.pixelMonitor(self, didTriggerKey: keyCode, event: event)
    }

    private func report(_ event: CaptureEvent, now: CFTimeInterval, force: Bool) {
        if force {
            delegate?.pixelMonitor(self, didUpdate: event)
            return
        }

        guard now - lastUIReportTime >= uiReportInterval || event.rgb != lastReportedRGB else {
            return
        }

        lastUIReportTime = now
        lastReportedRGB = event.rgb
        delegate?.pixelMonitor(self, didUpdate: event)
    }

    private func colorSpaceForDisplay(containing point: CGPoint) -> CGColorSpace? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen.colorSpace?.cgColorSpace
            }
        }
        return nil
    }

    private struct WindowInfo {
        let bounds: CGRect
    }

    private func findWindowInfo(forPID pid: pid_t) -> WindowInfo? {
        if AXIsProcessTrusted(), let focused = findFocusedWindowViaAX(forPID: pid) {
            return focused
        }

        return findWindowInfoViaCGWindow(forPID: pid)
    }

    // MARK: - Strategy 1: CGWindowListCopyWindowInfo

    private func findWindowInfoViaCGWindow(forPID pid: pid_t) -> WindowInfo? {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        guard let windows = windowList else { return nil }

        var candidates: [(bounds: CGRect, area: CGFloat)] = []

        for window in windows {
            guard let windowPID = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, windowPID == pid else {
                continue
            }

            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard layer == 0 else { continue }

            let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha > 0 else { continue }

            let x = (boundsDict["X"] as? NSNumber)?.doubleValue ?? 0
            let y = (boundsDict["Y"] as? NSNumber)?.doubleValue ?? 0
            let w = (boundsDict["Width"] as? NSNumber)?.doubleValue ?? 0
            let h = (boundsDict["Height"] as? NSNumber)?.doubleValue ?? 0

            // Skip tiny helper windows and permission-blocked 1×1 placeholders
            guard w > 50, h > 50 else { continue }

            let bounds = CGRect(x: x, y: y, width: w, height: h)
            let area = CGFloat(w * h)
            candidates.append((bounds: bounds, area: area))
        }

        guard let best = candidates.max(by: { $0.area < $1.area }) else { return nil }
        return WindowInfo(bounds: best.bounds)
    }

    // MARK: - Strategy 2: Accessibility API

    private func findFocusedWindowViaAX(forPID pid: pid_t) -> WindowInfo? {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindowValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        if focusedResult == .success,
           let focusedWindow = focusedWindowValue {
            return windowInfoFromAXElement(focusedWindow as! AXUIElement)
        }

        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return nil
        }

        var candidates: [(bounds: CGRect, area: CGFloat)] = []

        for window in windows {
            guard let info = windowInfoFromAXElement(window) else { continue }
            let area = info.bounds.width * info.bounds.height
            candidates.append((bounds: info.bounds, area: area))
        }

        guard let best = candidates.max(by: { $0.area < $1.area }) else { return nil }
        return WindowInfo(bounds: best.bounds)
    }

    private func windowInfoFromAXElement(_ window: AXUIElement) -> WindowInfo? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let posValue,
              let sizeValue else {
            return nil
        }

        let posAX = posValue as! AXValue
        let sizeAX = sizeValue as! AXValue

        var pos = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posAX, .cgPoint, &pos),
              AXValueGetValue(sizeAX, .cgSize, &size),
              size.width > 50,
              size.height > 50 else {
            return nil
        }

        return WindowInfo(bounds: CGRect(origin: pos, size: size))
    }
}
