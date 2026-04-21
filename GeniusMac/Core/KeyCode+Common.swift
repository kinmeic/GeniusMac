import CoreGraphics

// MARK: - Common macOS Key Codes (CGKeyCode = UInt16)
// Reference: https://eastmanreference.com/complete-list-of-applescript-key-codes

extension CGKeyCode {
    // Number row
    static let k1: CGKeyCode = 0x12
    static let k2: CGKeyCode = 0x13
    static let k3: CGKeyCode = 0x14
    static let k4: CGKeyCode = 0x15
    static let k5: CGKeyCode = 0x17
    static let k6: CGKeyCode = 0x16
    static let k7: CGKeyCode = 0x1A
    static let k8: CGKeyCode = 0x1C
    static let k9: CGKeyCode = 0x19
    static let k0: CGKeyCode = 0x1D

    // Function keys
    static let f1: CGKeyCode = 0x7A
    static let f2: CGKeyCode = 0x78
    static let f3: CGKeyCode = 0x63
    static let f4: CGKeyCode = 0x76
    static let f5: CGKeyCode = 0x60
    static let f6: CGKeyCode = 0x61
    static let f7: CGKeyCode = 0x62
    static let f8: CGKeyCode = 0x64
    static let f9: CGKeyCode = 0x65
    static let f10: CGKeyCode = 0x6D
    static let f11: CGKeyCode = 0x67
    static let f12: CGKeyCode = 0x6F

    // Special
    static let space: CGKeyCode = 0x31
    static let grave: CGKeyCode = 0x32  // `
    static let tab: CGKeyCode = 0x30
    static let enter: CGKeyCode = 0x24
    static let escape: CGKeyCode = 0x35

    // Modifiers
    static let command: CGKeyCode = 0x37
    static let shift: CGKeyCode = 0x38
    static let option: CGKeyCode = 0x3A
    static let control: CGKeyCode = 0x3B
}
