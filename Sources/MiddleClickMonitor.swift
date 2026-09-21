import AppKit
import CoreGraphics
import Darwin
import Foundation

final class MiddleClickMonitor {
    var isSuppressed = false
    var onStatus: ((String) -> Void)?
    var strings: () -> L10n = { L10n(AppLanguage.system.resolved) }

    private var enabled = true
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var gestureMonitor: Any?
    private var deviceList: CFArray?
    private var devices: [UnsafeMutableRawPointer] = []
    private var framework: UnsafeMutableRawPointer?
    private let stateLock = NSLock()
    private var threeDown = false
    private var wasThreeDown = false
    private var contactBegan: Date?
    private var lastNaturalClick: Date = .distantPast
    private var lastEmulatedTap: Date = .distantPast

    deinit {
        stop()
    }

    func update(enabled: Bool) {
        self.enabled = enabled
        if !enabled {
            resetState()
        }
    }

    func start() {
        stop()
        _ = CGRequestListenEventAccess()
        startMultitouch()
        installGestureFallback()
        installTap()
        let t = strings()
        if tap == nil {
            report(t.middleClickFailed)
        } else if devices.isEmpty {
            report(t.middleClickNoTrackpad)
        } else {
            report(t.middleClickListening)
        }
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        if let gestureMonitor {
            NSEvent.removeMonitor(gestureMonitor)
            self.gestureMonitor = nil
        }
        resetState()
        stopMultitouch()
    }

    fileprivate func handleTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard enabled, !isSuppressed else {
            return Unmanaged.passUnretained(event)
        }

        let down = type == .leftMouseDown || type == .rightMouseDown
        let up = type == .leftMouseUp || type == .rightMouseUp

        stateLock.lock()
        if threeDown && down {
            threeDown = false
            wasThreeDown = true
            lastNaturalClick = Date()
            contactBegan = nil
            stateLock.unlock()
            event.type = .otherMouseDown
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
            report(strings().middleClickFired)
            return Unmanaged.passUnretained(event)
        }
        if wasThreeDown && up {
            wasThreeDown = false
            stateLock.unlock()
            event.type = .otherMouseUp
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
            return Unmanaged.passUnretained(event)
        }
        stateLock.unlock()
        return Unmanaged.passUnretained(event)
    }

    fileprivate func handleFingers(_ count: Int32) {
        stateLock.lock()
        if count == 3 {
            if contactBegan == nil {
                contactBegan = Date()
            }
            threeDown = true
            stateLock.unlock()
            return
        }

        if count > 3 {
            threeDown = false
            contactBegan = nil
            stateLock.unlock()
            return
        }

        threeDown = false
        let began = contactBegan
        let alreadyClicked = Date().timeIntervalSince(lastNaturalClick) < 0.4
        contactBegan = nil
        stateLock.unlock()

        guard count == 0, !alreadyClicked, let began else { return }
        let elapsed = Date().timeIntervalSince(began)
        guard elapsed > 0.04, elapsed < 0.45 else { return }
        emulateTap()
    }

    private func emulateTap() {
        stateLock.lock()
        if Date().timeIntervalSince(lastEmulatedTap) < 0.25 {
            stateLock.unlock()
            return
        }
        lastEmulatedTap = Date()
        stateLock.unlock()
        MiddleClickPoster.postAtCursor()
        report(strings().middleClickFired)
    }

    private func resetState() {
        stateLock.lock()
        threeDown = false
        wasThreeDown = false
        contactBegan = nil
        stateLock.unlock()
    }

    private func installTap() {
        let mask =
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let attempts: [CGEventTapLocation] = [.cghidEventTap, .cgSessionEventTap]
        for location in attempts {
            if let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: middleClickTapCallback,
                userInfo: userInfo
            ) {
                self.tap = tap
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                runLoopSource = source
                CGEvent.tapEnable(tap: tap, enable: true)
                return
            }
        }
    }

    private func installGestureFallback() {
        gestureMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.beginGesture, .endGesture, .gesture]) { [weak self] event in
            let count = event.touches(matching: .touching, in: nil).count
            if count > 0 {
                self?.handleFingers(Int32(count))
            } else if event.type == .endGesture {
                self?.handleFingers(0)
            }
        }
    }

    private func startMultitouch() {
        MiddleClickMonitor.active = self
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        framework = handle

        guard
            let createList = dlsymFn(handle, "MTDeviceCreateList", MTDeviceCreateListFn.self),
            let register = dlsymFn(handle, "MTRegisterContactFrameCallback", MTRegisterCallbackFn.self),
            let start = dlsymFn(handle, "MTDeviceStart", MTDeviceStartFn.self)
        else {
            return
        }

        guard let unmanaged = createList() else { return }
        let list = unmanaged.takeRetainedValue()
        deviceList = list
        let count = CFArrayGetCount(list)
        for index in 0..<count {
            guard let device = CFArrayGetValueAtIndex(list, index) else { continue }
            let pointer = UnsafeMutableRawPointer(mutating: device)
            register(pointer, multitouchFrameCallback)
            start(pointer, 0)
            devices.append(pointer)
        }
    }

    private func stopMultitouch() {
        if let handle = framework, let stop = dlsymFn(handle, "MTDeviceStop", MTDeviceStopFn.self) {
            for device in devices {
                stop(device)
            }
        }
        devices = []
        deviceList = nil
        if MiddleClickMonitor.active === self {
            MiddleClickMonitor.active = nil
        }
        if let framework {
            dlclose(framework)
            self.framework = nil
        }
    }

    private func report(_ text: String) {
        NSLog("AutoText middle-click: \(text)")
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?(text)
        }
    }

    fileprivate static weak var active: MiddleClickMonitor?
}

enum MiddleClickPoster {
    static func postAtCursor() {
        let location = CGEvent(source: nil)?.location ?? .zero
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseDown,
            mouseCursorPosition: location,
            mouseButton: .center
        )
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseUp,
            mouseCursorPosition: location,
            mouseButton: .center
        )
        up?.post(tap: .cghidEventTap)
    }
}

private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTContactCallback = @convention(c) (
    UnsafeRawPointer?, UnsafeRawPointer?, Int32, Double, Int32
) -> Int32
private typealias MTRegisterCallbackFn = @convention(c) (UnsafeMutableRawPointer, MTContactCallback) -> Void
private typealias MTDeviceStartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
private typealias MTDeviceStopFn = @convention(c) (UnsafeMutableRawPointer) -> Void

private func dlsymFn<T>(_ handle: UnsafeMutableRawPointer, _ name: String, _ type: T.Type) -> T? {
    guard let symbol = dlsym(handle, name) else { return nil }
    return unsafeBitCast(symbol, to: T.self)
}

private func multitouchFrameCallback(
    device: UnsafeRawPointer?,
    data: UnsafeRawPointer?,
    nFingers: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    MiddleClickMonitor.active?.handleFingers(nFingers)
    return 0
}

private func middleClickTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<MiddleClickMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handleTap(type: type, event: event)
}
