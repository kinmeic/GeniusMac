import Foundation

struct CaptureEvent {
    enum Error: Int {
        case success = 0
        case noWindowHandle = 1
        case processExited = 2
        case notResponding = 3
        case permissionDenied = 4
    }

    var error: Error = .success
    var r: Int = 0
    var g: Int = 0
    var b: Int = 0
    var rgb: Int = 0
}
