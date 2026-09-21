import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

enum TypingError: LocalizedError {
    case notTrusted
    case alreadyTyping
    case emptyText
    case modifiersHeld
    case unsupportedCharacters([Character])

    var errorDescription: String? {
        message(using: L10n(AppLanguage.system.resolved))
    }

    func message(using strings: L10n) -> String {
        switch self {
        case .notTrusted:
            return strings.typingNotTrusted
        case .alreadyTyping:
            return strings.typingBusy
        case .emptyText:
            return strings.typingEmpty
        case .modifiersHeld:
            return strings.typingModifiers
        case .unsupportedCharacters(let chars):
            let preview = chars.prefix(8).map { String($0) }.joined(separator: " ")
            return strings.typingUnsupported(preview)
        }
    }
}

private enum Stroke {
    case key(PhysicalKeystroke)
    case unicode(Character)
}

final class KeystrokeTyper {
    private let lock = NSLock()
    private var typing = false
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var keyboardType: Int64 = Int64(LMGetKbdType())

    func typeAsync(_ text: String, delayMs: Int, completion: @escaping (Error?) -> Void) {
        let work = {
            let trusted = AXIsProcessTrusted() || AccessibilityPermission.canUseAccessibilityAPI()
            guard trusted else {
                completion(TypingError.notTrusted)
                return
            }
            self.prepareLayoutAndType(text, delayMs: delayMs, completion: completion)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func prepareLayoutAndType(
        _ text: String,
        delayMs: Int,
        completion: @escaping (Error?) -> Void
    ) {
        let original = KeyboardMap.currentSource()
        let currentMap = KeyboardMap.currentMap()
        let needsASCII = !KeyboardMap.canType(text, with: currentMap)
        let ascii = needsASCII ? KeyboardMap.asciiCapableSource() : nil
        let originalID = original.flatMap(KeyboardMap.sourceID)
        let asciiID = ascii.flatMap(KeyboardMap.sourceID)
        let shouldSwitch = needsASCII && ascii != nil && originalID != asciiID

        if shouldSwitch, let ascii {
            TISSelectInputSource(ascii)
            waitForLayout(ascii, attemptsLeft: 10) { map in
                self.startTyping(
                    text,
                    delayMs: delayMs,
                    map: map,
                    restore: original,
                    completion: completion
                )
            }
        } else {
            startTyping(
                text,
                delayMs: delayMs,
                map: currentMap,
                restore: nil,
                completion: completion
            )
        }
    }

    private func waitForLayout(
        _ source: TISInputSource,
        attemptsLeft: Int,
        ready: @escaping ([Character: PhysicalKeystroke]) -> Void
    ) {
        let map = KeyboardMap.currentMap()
        let currentID = KeyboardMap.currentSource().flatMap(KeyboardMap.sourceID)
        let targetID = KeyboardMap.sourceID(source)
        if currentID == targetID || attemptsLeft == 0 {
            ready(map)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.waitForLayout(source, attemptsLeft: attemptsLeft - 1, ready: ready)
        }
    }

    private func startTyping(
        _ text: String,
        delayMs: Int,
        map: [Character: PhysicalKeystroke],
        restore: TISInputSource?,
        completion: @escaping (Error?) -> Void
    ) {
        let keyboardType = Int64(LMGetKbdType())
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.type(text, delayMs: delayMs, map: map, keyboardType: keyboardType)
                DispatchQueue.main.async {
                    if let restore {
                        TISSelectInputSource(restore)
                    }
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    if let restore {
                        TISSelectInputSource(restore)
                    }
                    completion(error)
                }
            }
        }
    }

    func type(
        _ text: String,
        delayMs: Int,
        map: [Character: PhysicalKeystroke],
        keyboardType: Int64
    ) throws {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.isEmpty else { throw TypingError.emptyText }

        lock.lock()
        if typing {
            lock.unlock()
            throw TypingError.alreadyTyping
        }
        typing = true
        lock.unlock()
        defer {
            lock.lock()
            typing = false
            lock.unlock()
        }

        self.keyboardType = keyboardType
        var strokes: [Stroke] = []
        strokes.reserveCapacity(normalized.count)

        for character in normalized {
            if let stroke = map[character] {
                strokes.append(.key(stroke))
            } else {
                strokes.append(.unicode(character))
            }
        }

        guard waitUntilPhysicalModifiersReleased() else {
            throw TypingError.modifiersHeld
        }
        pause(80)

        let delay = max(delayMs, 1)
        var held: CGEventFlags = []

        for stroke in strokes {
            switch stroke {
            case .key(let keystroke):
                let needed = keystroke.flags.intersection([.maskShift, .maskAlternate, .maskControl, .maskCommand])
                applyModifierChange(from: held, to: needed, pauseMs: min(delay, 12))
                held = needed
                tap(keystroke.keyCode, flags: needed)
            case .unicode(let character):
                applyModifierChange(from: held, to: [], pauseMs: min(delay, 12))
                held = []
                tapUnicode(character)
            }
            pause(delay)
        }

        applyModifierChange(from: held, to: [], pauseMs: min(delay, 12))
    }

    private func waitUntilPhysicalModifiersReleased(timeout: TimeInterval = 5) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if heldModifiers().isEmpty {
                pause(40)
                if heldModifiers().isEmpty {
                    let modifierCodes: [CGKeyCode] = [
                        CGKeyCode(kVK_Command),
                        CGKeyCode(kVK_RightCommand),
                        CGKeyCode(kVK_Shift),
                        CGKeyCode(kVK_RightShift),
                        CGKeyCode(kVK_Option),
                        CGKeyCode(kVK_RightOption),
                        CGKeyCode(kVK_Control),
                        CGKeyCode(kVK_RightControl)
                    ]
                    for code in modifierCodes {
                        post(code, down: false, flags: [])
                    }
                    pause(40)
                    return heldModifiers().isEmpty
                }
            }
            pause(20)
        }
        return false
    }

    private func heldModifiers() -> CGEventFlags {
        CGEventSource.flagsState(.hidSystemState)
            .intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private func applyModifierChange(from old: CGEventFlags, to new: CGEventFlags, pauseMs: Int) {
        let releaseOrder: [CGEventFlags] = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        var current = old
        for flag in releaseOrder where current.contains(flag) && !new.contains(flag) {
            current.remove(flag)
            post(modifierKeyCode(flag), down: false, flags: current)
            pause(pauseMs)
        }

        let pressOrder: [CGEventFlags] = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        for flag in pressOrder where new.contains(flag) && !current.contains(flag) {
            current.insert(flag)
            post(modifierKeyCode(flag), down: true, flags: current)
            pause(pauseMs)
        }
    }

    private func tap(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        post(keyCode, down: true, flags: flags)
        pause(8)
        post(keyCode, down: false, flags: flags)
    }

    private func tapUnicode(_ character: Character) {
        let units = Array(String(character).utf16)
        guard !units.isEmpty else { return }
        units.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            if let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) {
                down.flags = []
                down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
                down.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
                down.post(tap: .cghidEventTap)
            }
            pause(8)
            if let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) {
                up.flags = []
                up.post(tap: .cghidEventTap)
            }
        }
    }

    private func post(_ keyCode: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down) else {
            return
        }
        event.flags = flags
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        event.setIntegerValueField(.keyboardEventKeyboardType, value: keyboardType)
        event.post(tap: .cghidEventTap)
    }

    private func modifierKeyCode(_ flag: CGEventFlags) -> CGKeyCode {
        if flag.contains(.maskCommand) { return CGKeyCode(kVK_Command) }
        if flag.contains(.maskShift) { return CGKeyCode(kVK_Shift) }
        if flag.contains(.maskAlternate) { return CGKeyCode(kVK_Option) }
        return CGKeyCode(kVK_Control)
    }

    private func pause(_ milliseconds: Int) {
        let usec = useconds_t(max(milliseconds, 0) * 1000)
        if usec > 0 {
            usleep(usec)
        }
    }
}
