import Foundation
import AppKit

struct RunningProcess: Identifiable, Equatable {
    let id: Int
    let name: String
    let pid: pid_t

    var displayName: String {
        "\(name) - \(pid)"
    }
}

final class ProcessManager {
    func listVisibleProcesses() -> [RunningProcess] {
        let apps = NSWorkspace.shared.runningApplications
        return apps
            .filter { $0.activationPolicy == .regular }
            .map { app in
                RunningProcess(
                    id: Int(app.processIdentifier),
                    name: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
                    pid: app.processIdentifier
                )
            }
            .sorted { $0.name < $1.name }
    }

    func findProcess(byPID pid: pid_t) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
    }

    func launchGame(at path: URL) async -> NSRunningApplication? {
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        do {
            return try await NSWorkspace.shared.openApplication(
                at: path,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } catch {
            print("Failed to launch game: \(error)")
            return nil
        }
    }
}
