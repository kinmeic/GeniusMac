import Foundation
import AppKit
import CoreGraphics

protocol PixelMonitorDelegate: AnyObject {
    func pixelMonitor(_ monitor: PixelMonitor, didUpdate event: CaptureEvent)
}

final class PixelMonitor {
    weak var delegate: PixelMonitorDelegate?

    private var timer: Timer?
    private var isRunning = false

    var targetPID: pid_t?
    var x: Int = 1
    var y: Int = 1
    var interval: TimeInterval = 0.1

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
        rescheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        guard isRunning else { return }
        rescheduleTimer()
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let pid = targetPID else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .processExited))
            return
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .processExited))
            return
        }

        guard !app.isTerminated else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .processExited))
            return
        }

        guard hasScreenRecordingPermission() else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .permissionDenied))
            return
        }

        if let windowInfo = findWindowInfo(forPID: pid) {
            capturePixelViaScreen(at: windowInfo)
            return
        }

        delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .noWindowHandle))
    }

    private func capturePixelViaScreen(at windowInfo: WindowInfo) {
        let screenX = windowInfo.bounds.origin.x + CGFloat(x)
        let screenY = windowInfo.bounds.origin.y + CGFloat(y)
        let captureBounds = CGRect(x: screenX, y: screenY, width: 1, height: 1)

        guard let image = CGWindowListCreateImage(
            captureBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .noWindowHandle))
            return
        }

        let capturePoint = CGPoint(x: screenX, y: screenY)
        let displayColorSpace = colorSpaceForDisplay(containing: capturePoint)
        extractAndReportColor(from: image, displayColorSpace: displayColorSpace)
    }

    private func extractAndReportColor(from image: CGImage, displayColorSpace: CGColorSpace?) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .noWindowHandle))
            return
        }

        let sourceColorSpace = displayColorSpace ?? image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let targetColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: sourceColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            delegate?.pixelMonitor(self, didUpdate: CaptureEvent(error: .noWindowHandle))
            return
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

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
