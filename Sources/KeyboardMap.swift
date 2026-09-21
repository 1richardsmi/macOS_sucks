import Carbon
import CoreGraphics
import Foundation

struct PhysicalKeystroke: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
}

enum KeyboardMap {
    /// TIS layout APIs must run on the main thread — calling them off-main
    /// crashes with `_dispatch_assert_queue_fail` on current macOS.
    static func currentMap() -> [Character: PhysicalKeystroke] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return [:]
        }
        return map(for: source)
    }

    static func map(for source: TISInputSource) -> [Character: PhysicalKeystroke] {
        withLayout(source) { layout in
            var map: [Character: PhysicalKeystroke] = [:]
            let combos: [(UInt32, CGEventFlags)] = [
                (0, []),
                (UInt32(shiftKey), .maskShift),
                (UInt32(optionKey), .maskAlternate),
                (UInt32(shiftKey | optionKey), [.maskShift, .maskAlternate])
            ]

            for (modifiers, flags) in combos {
                for code in UInt16(0)..<128 {
                    guard
                        let string = translate(layout: layout, keyCode: code, carbonModifiers: modifiers),
                        string.count == 1,
                        let character = string.first
                    else {
                        continue
                    }
                    if map[character] == nil {
                        map[character] = PhysicalKeystroke(keyCode: CGKeyCode(code), flags: flags)
                    }
                }
            }

            map["\n"] = PhysicalKeystroke(keyCode: CGKeyCode(kVK_Return), flags: [])
            map["\r"] = PhysicalKeystroke(keyCode: CGKeyCode(kVK_Return), flags: [])
            map["\t"] = PhysicalKeystroke(keyCode: CGKeyCode(kVK_Tab), flags: [])
            return map
        } ?? [:]
    }

    static func currentSource() -> TISInputSource? {
        TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
    }

    static func asciiCapableSource() -> TISInputSource? {
        TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
    }

    static func sourceID(_ source: TISInputSource) -> String? {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }

    static func glyph(forKeyCode keyCode: UInt16, carbonModifiers: UInt32 = 0) -> String? {
        guard let source = currentSource() else { return nil }
        return withLayout(source) { layout in
            translate(layout: layout, keyCode: keyCode, carbonModifiers: carbonModifiers)
        } ?? nil
    }

    static func canType(_ text: String, with map: [Character: PhysicalKeystroke]) -> Bool {
        text.allSatisfy { map[$0] != nil }
    }

    private static func withLayout<T>(_ source: TISInputSource, _ body: (UnsafePointer<UCKeyboardLayout>) -> T) -> T? {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        return withExtendedLifetime(source) {
            withExtendedLifetime(data) {
                guard let bytes = CFDataGetBytePtr(data) else { return nil }
                let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
                return Optional(body(layout))
            }
        }
    }

    private static func translate(
        layout: UnsafePointer<UCKeyboardLayout>,
        keyCode: UInt16,
        carbonModifiers: UInt32
    ) -> String? {
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength = 0
        let status = UCKeyTranslate(
            layout,
            keyCode,
            UInt16(kUCKeyActionDown),
            (carbonModifiers >> 8) & 0xFF,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &actualLength,
            &chars
        )
        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: actualLength)
    }
}
