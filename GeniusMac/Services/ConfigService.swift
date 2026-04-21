import Foundation

final class ConfigService {
    private let filename = "Config.json"

    private var configURL: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("GeniusMac", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent(filename)
    }

    func load() -> Config {
        let fm = FileManager.default

        if !fm.fileExists(atPath: configURL.path) {
            // Copy default config from bundle if available
            if let bundleURL = Bundle.main.url(forResource: "Config", withExtension: "json"),
               let data = try? Data(contentsOf: bundleURL) {
                try? data.write(to: configURL)
            } else {
                let defaultConfig = defaultConfigWithMappings()
                save(defaultConfig)
                return defaultConfig
            }
        }

        guard let data = try? Data(contentsOf: configURL) else {
            return defaultConfigWithMappings()
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Config.self, from: data)
        } catch {
            print("Failed to decode config: \(error)")
            return defaultConfigWithMappings()
        }
    }

    private func defaultConfigWithMappings() -> Config {
        var config = Config()
        config.captureX = 100
        config.captureY = 100
        config.interval = 100
        config.backgroundInterval = 500
        config.filterG = 0
        config.filterB = 0
        config.keyMappings = [
            "10": 18,   // 1
            "15": 19,   // 2
            "20": 20,   // 3
            "25": 21,   // 4
            "30": 23,   // 5
            "35": 22,   // 6
            "40": 26,   // 7
            "45": 28,   // 8
            "50": 25,   // 9
            "55": 29,   // 0
            "60": 0,    // -
            "65": 11,   // =
            "70": 122,  // F1
            "75": 120,  // F2
            "80": 99,   // F3
            "85": 118,  // F4
            "90": 96,   // F5
            "95": 97,   // F6
            "100": 98,  // F7
            "105": 100, // F8
            "110": 101, // F9
            "115": 109, // F10
            "120": 103, // F11
            "125": 111, // F12
            "130": 50,  // `
            "200": 49   // Space
        ]
        return config
    }

    func save(_ config: Config) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
}
