import Foundation
import AppKit

final class WindowObserver: ObservableObject {
    @Published var targetProcessID: pid_t?
    @Published var isTargetForeground: Bool = false

    private var timer: Timer?

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkForeground()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isTargetForeground = false
    }

    private func checkForeground() {
        guard let targetPID = targetProcessID else {
            isTargetForeground = false
            return
        }
        let frontApp = NSWorkspace.shared.frontmostApplication
        isTargetForeground = (frontApp?.processIdentifier == targetPID)
    }
}
