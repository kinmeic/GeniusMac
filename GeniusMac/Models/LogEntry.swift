import Foundation

struct LogEntry: Identifiable, Equatable {
    enum Level: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    let id = UUID()
    let timestamp: Date
    let level: Level
    let message: String
}
