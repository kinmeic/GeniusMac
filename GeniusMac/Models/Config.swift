import Foundation

struct Config: Codable {
    var captureX: Int = 1
    var captureY: Int = 1
    var interval: Int = 100
    var backgroundInterval: Int = 500
    var filterG: Int = 0
    var filterB: Int = 0
    var gamePath: String = ""
    var keyMappings: [String: Int] = [:]
    var accounts: [Account] = []

    func getKeyMapping(for color: Int) -> Int? {
        keyMappings[String(color)]
    }
}

struct Account: Codable, Identifiable, Hashable {
    let id = UUID()
    var username: String
    var password: String

    enum CodingKeys: String, CodingKey {
        case username, password
    }
}
