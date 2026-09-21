import AppKit
import Carbon
import Foundation

struct HotkeyReloadResult {
    var registeredIDs: Set<UUID> = []
    var failures: [UUID: String] = [:]
}

final class HotkeyCenter {
    var onHotkey: ((UUID) -> Void)?
    var suppressEvents = false

    private var handlerRef: EventHandlerRef?
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var idToSnippet: [UInt32: UUID] = [:]
    private var nextID: UInt32 = 1
    private var snippets: [Snippet] = []
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var lastFireAt: Date?
    private var started = false

    static let signature: OSType = 0x41545854 // 'ATXT'

    deinit {
        stop()
    }

    @discardableResult
    func start(with snippets: [Snippet], strings: L10n) -> HotkeyReloadResult {
        stop()
        started = true
        let result = reload(snippets, strings: strings)
        installMonitors()
        return result
    }

    func stop() {
        uninstallMonitors()
        unregisterAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        started = false
    }

    @discardableResult
    func reload(_ snippets: [Snippet], strings: L10n) -> HotkeyReloadResult {
        self.snippets = snippets
        unregisterAll()

        var result = HotkeyReloadResult()
        guard started else { return result }

        installHandlerIfNeeded()

        var seen: Set<String> = []
        for snippet in snippets where snippet.enabled {
            guard let keyCode = snippet.keyCode else { continue }
            let token = "\(keyCode)-\(snippet.carbonModifiers)"
            if seen.contains(token) {
                result.failures[snippet.id] = strings.hotkeyDuplicate
                continue
            }
            seen.insert(token)

            if let error = register(snippetID: snippet.id, keyCode: keyCode, modifiers: snippet.carbonModifiers, strings: strings) {
                result.failures[snippet.id] = error
            } else {
                result.registeredIDs.insert(snippet.id)
            }
        }
        return result
    }

    func handleCarbon(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == Self.signature else { return }
        guard let uuid = idToSnippet[hotKeyID.id] else { return }
        fire(uuid)
    }

    private func fire(_ id: UUID) {
        guard !suppressEvents else { return }
        let now = Date()
        if let lastFireAt, now.timeIntervalSince(lastFireAt) < 0.35 {
            return
        }
        lastFireAt = now
        DispatchQueue.main.async { [weak self] in
            self?.onHotkey?(id)
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let targets = [GetEventDispatcherTarget(), GetApplicationEventTarget()]

        for target in targets {
            let status = InstallEventHandler(
                target,
                carbonHotKeyHandler,
                1,
                &spec,
                userData,
                &handlerRef
            )
            if status == noErr, handlerRef != nil {
                return
            }
            handlerRef = nil
        }
        NSLog("AutoText: InstallEventHandler failed")
    }

    private func register(snippetID: UUID, keyCode: UInt32, modifiers: UInt32, strings: L10n) -> String? {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
        let target = GetEventDispatcherTarget()
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            target,
            0,
            &hotKeyRef
        )
        if status == noErr, let hotKeyRef {
            refs[nextID] = hotKeyRef
            idToSnippet[nextID] = snippetID
            nextID += 1
            return nil
        }

        if status == OSStatus(eventHotKeyExistsErr) {
            return strings.hotkeyTakenBySystem
        }
        return strings.hotkeyRegisterFailed(status)
    }

    private func unregisterAll() {
        for (_, ref) in refs {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        idToSnippet.removeAll()
    }

    private func installMonitors() {
        uninstallMonitors()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if self.handleNSEvent(event) {
                return nil
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            _ = self?.handleNSEvent(event)
        }
    }

    private func uninstallMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func handleNSEvent(_ event: NSEvent) -> Bool {
        guard !suppressEvents else { return false }
        let modifiers = HotkeyFormatting.carbonModifiers(from: event.modifierFlags)
        let keyCode = UInt32(event.keyCode)
        guard let snippet = snippets.first(where: {
            $0.enabled && $0.keyCode == keyCode && $0.carbonModifiers == modifiers
        }) else {
            return false
        }
        fire(snippet.id)
        return true
    }
}

private func carbonHotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard err == noErr else { return err }
    if let userData {
        Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue().handleCarbon(hotKeyID)
    }
    return noErr
}
