import AppKit
import Carbon
import CoreGraphics
import Foundation

final class SwipeGestureMonitor {
    var isSuppressed = false
    var isListening = false
    var lastStatus: String?
    var onNavigate: ((Bool) -> Void)?
    var onStatus: ((String) -> Void)?
    var strings: () -> L10n = { L10n(AppLanguage.system.resolved) }

    private var enabled = true
    private var targets: [GestureTarget] = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var dx: CGFloat = 0
    private var dy: CGFloat = 0
    private var fired = false
    private var consuming = false
    private var tracking = false
    private var lastFireAt: Date = .distantPast

    private let fireThreshold: CGFloat = 48
    private let directionRatio: CGFloat = 1.15

    deinit {
        stop()
    }

    func start() {
        stop()
        _ = CGRequestListenEventAccess()
        installTap()
        installMonitors()
        isListening = tap != nil || localMonitor != nil || globalMonitor != nil
        let t = strings()
        report(isListening ? t.gesturesListening : t.gesturesFailed)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        tap = nil
        runLoopSource = nil
        localMonitor = nil
        globalMonitor = nil
        isListening = false
        resetGesture()
    }

    func update(enabled: Bool, targets: [GestureTarget]) {
        self.enabled = enabled
        self.targets = targets
    }

    fileprivate func handleTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }
        if let nsEvent = NSEvent(cgEvent: event), process(nsEvent, consumeIfMatched: true) {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    @discardableResult
    private func process(_ event: NSEvent, consumeIfMatched: Bool) -> Bool {
        guard enabled, !isSuppressed else { return false }

        if event.type == .swipe {
            return handleDiscreteSwipe(event)
        }

        guard event.type == .scrollWheel else { return false }
        guard event.hasPreciseScrollingDeltas else { return false }

        if event.momentumPhase != [] && event.momentumPhase != .mayBegin {
            if event.momentumPhase == .ended || event.momentumPhase == .cancelled {
                resetGesture()
            }
            return consumeIfMatched && consuming
        }

        let phase = event.phase
        let hasPhases = phase != []

        if phase.contains(.began) {
            resetGesture()
            tracking = true
        }
        if phase.contains(.cancelled) {
            let wasConsuming = consuming
            resetGesture()
            return consumeIfMatched && wasConsuming
        }

        var fingerX = event.scrollingDeltaX
        var fingerY = event.scrollingDeltaY
        if fingerX == 0 && fingerY == 0 {
            fingerX = event.deltaX
            fingerY = event.deltaY
        }
        if event.isDirectionInvertedFromDevice {
            fingerX = -fingerX
            fingerY = -fingerY
        }
        dx += fingerX
        dy += fingerY
        tracking = true

        if !fired, abs(dx) >= fireThreshold, abs(dx) >= abs(dy) * directionRatio {
            fire(leftToRight: dx > 0)
        }

        if !hasPhases {
            let wasConsuming = consuming
            if fired { resetGesture() }
            return consumeIfMatched && wasConsuming
        }

        if phase.contains(.ended) {
            if !fired, abs(dx) >= fireThreshold * 0.75, abs(dx) >= abs(dy) {
                fire(leftToRight: dx > 0)
            }
            let wasConsuming = consuming
            resetGesture()
            return consumeIfMatched && wasConsuming
        }

        return consumeIfMatched && consuming
    }

    private func handleDiscreteSwipe(_ event: NSEvent) -> Bool {
        guard enabled, !isSuppressed else { return false }
        guard abs(event.deltaX) >= abs(event.deltaY) else { return false }
        var dx = event.deltaX
        if event.isDirectionInvertedFromDevice {
            dx = -dx
        }
        fire(leftToRight: dx > 0)
        return true
    }

    private func fire(leftToRight: Bool) {
        guard !fired else { return }
        guard isFrontmostAllowed() else {
            report(strings().swipeWrongApp)
            return
        }
        let now = Date()
        guard now.timeIntervalSince(lastFireAt) > 0.35 else { return }
        fired = true
        consuming = true
        lastFireAt = now
        let t = strings()
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? t.unknownApp
        report(leftToRight ? t.swipeRight(in: name) : t.swipeLeft(in: name))
        DispatchQueue.main.async { [weak self] in
            self?.onNavigate?(leftToRight)
        }
    }

    private func isFrontmostAllowed() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        guard let bundleID = app.bundleIdentifier else { return false }
        if bundleID == Bundle.main.bundleIdentifier { return false }
        return GestureTarget.matches(bundleID, enabledTargets: targets)
    }

    private func resetGesture() {
        dx = 0
        dy = 0
        fired = false
        consuming = false
        tracking = false
    }

    private func report(_ text: String) {
        lastStatus = text
        NSLog("AutoText gestures: \(text)")
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?(text)
        }
    }

    private func installTap() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let attempts: [(CGEventTapLocation, CGEventTapOptions)] = [
            (.cgSessionEventTap, .listenOnly),
            (.cghidEventTap, .listenOnly),
            (.cgSessionEventTap, .defaultTap)
        ]
        for (location, options) in attempts {
            if let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: options,
                eventsOfInterest: mask,
                callback: swipeTapCallback,
                userInfo: userInfo
            ) {
                self.tap = tap
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                runLoopSource = source
                CGEvent.tapEnable(tap: tap, enable: true)
                report(strings().tapEnabled)
                return
            }
        }
        report(strings().tapFallback)
    }

    private func installMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
            self?.process(event, consumeIfMatched: false)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
            self?.process(event, consumeIfMatched: false)
        }
    }
}

private func swipeTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<SwipeGestureMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handleTap(type: type, event: event)
}

enum NavigationShortcut {
    static func postBracket(leftToRight: Bool) {
        let original = KeyboardMap.currentSource()
        if let ascii = KeyboardMap.asciiCapableSource(),
           original.flatMap(KeyboardMap.sourceID) != KeyboardMap.sourceID(ascii) {
            TISSelectInputSource(ascii)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                postNow(leftToRight: leftToRight)
                if let original {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        TISSelectInputSource(original)
                    }
                }
            }
        } else {
            postNow(leftToRight: leftToRight)
        }
    }

    private static func postNow(leftToRight: Bool) {
        let keyCode: CGKeyCode = leftToRight
            ? CGKeyCode(kVK_ANSI_LeftBracket)
            : CGKeyCode(kVK_ANSI_RightBracket)
        let source = CGEventSource(stateID: .hidSystemState)
        let command = CGKeyCode(kVK_Command)

        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: true)
        commandDown?.flags = .maskCommand
        commandDown?.post(tap: .cghidEventTap)

        usleep(8000)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        usleep(8000)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        usleep(8000)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: false)
        commandUp?.flags = []
        commandUp?.post(tap: .cghidEventTap)
    }
}
