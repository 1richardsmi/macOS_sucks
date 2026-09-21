import AppKit
import Carbon
import Foundation

struct Snippet: Identifiable, Codable, Equatable, Hashable {
    static let clipboardID = UUID(uuidString: "3f8c1a2b-6d4e-4a91-9c0f-7b2e5d8a1c44")!

    var id: UUID
    var title: String
    var text: String
    var keyCode: UInt32?
    var carbonModifiers: UInt32
    var enabled: Bool
    var usesClipboard: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, text, keyCode, carbonModifiers, enabled, usesClipboard
    }

    init(
        id: UUID = UUID(),
        title: String = "Новый макрос",
        text: String = "",
        keyCode: UInt32? = nil,
        carbonModifiers: UInt32 = 0,
        enabled: Bool = true,
        usesClipboard: Bool = false
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.enabled = enabled
        self.usesClipboard = usesClipboard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        keyCode = try container.decodeIfPresent(UInt32.self, forKey: .keyCode)
        carbonModifiers = try container.decode(UInt32.self, forKey: .carbonModifiers)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        usesClipboard = try container.decodeIfPresent(Bool.self, forKey: .usesClipboard) ?? false
    }

    static func clipboardDefault(title: String) -> Snippet {
        Snippet(id: clipboardID, title: title, usesClipboard: true)
    }

    var hasHotkey: Bool { keyCode != nil }

    var hotkeyDisplay: String {
        guard let keyCode else { return "не задано" }
        return HotkeyFormatting.display(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }
}

enum HotkeyFormatting {
    static func display(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(keyCode))
        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    static func keyName(_ keyCode: UInt32) -> String {
        if let special = specialNames[keyCode] {
            return special
        }
        if let glyph = KeyboardMap.glyph(forKeyCode: UInt16(keyCode)), !glyph.isEmpty {
            return glyph.uppercased()
        }
        return "Key \(keyCode)"
    }

    static let functionKeyCodes: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 113, 106, 64, 79, 80, 90
    ]

    private static let specialNames: [UInt32: String] = [
        36: "↩",
        48: "⇥",
        49: "Space",
        51: "⌫",
        53: "⎋",
        64: "F17",
        76: "⌅",
        79: "F18",
        80: "F19",
        90: "F20",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "⌦",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑"
    ]
}
