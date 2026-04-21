import Foundation
import CoreGraphics

enum KeySimulator {
    static func press(keyCode: CGKeyCode) {
        keyDown(keyCode: keyCode)
        keyUp(keyCode: keyCode)
    }

    static func keyDown(keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        event.flags = .maskNonCoalesced
        event.post(tap: .cghidEventTap)
    }

    static func keyUp(keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        event.flags = .maskNonCoalesced
        event.post(tap: .cghidEventTap)
    }

    static func tab() {
        press(keyCode: 0x30)
    }

    static func enter() {
        press(keyCode: 0x24)
    }

    static func paste() {
        // Command+V sequence with proper modifier flags
        let commandKey: CGKeyCode = 0x37
        let vKey: CGKeyCode = 0x09

        // Command down
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: commandKey, keyDown: true) else { return }
        cmdDown.flags = .maskCommand
        cmdDown.post(tap: .cghidEventTap)

        // V down (with Command held)
        guard let vDown = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true) else { return }
        vDown.flags = .maskCommand
        vDown.post(tap: .cghidEventTap)

        // V up (with Command held)
        guard let vUp = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false) else { return }
        vUp.flags = .maskCommand
        vUp.post(tap: .cghidEventTap)

        // Command up
        guard let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: commandKey, keyDown: false) else { return }
        cmdUp.flags = .maskCommand
        cmdUp.post(tap: .cghidEventTap)
    }
}
