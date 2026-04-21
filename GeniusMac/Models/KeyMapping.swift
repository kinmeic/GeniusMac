import Foundation

struct KeyMapping {
    private var mappings: [Int: Int]

    init(from dict: [Int: Int]) {
        self.mappings = dict
    }

    func getKey(for color: Int) -> Int {
        mappings[color] ?? 0
    }

    mutating func setMapping(color: Int, key: Int) {
        mappings[color] = key
    }
}
