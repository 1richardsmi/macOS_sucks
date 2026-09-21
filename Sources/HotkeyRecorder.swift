import AppKit
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    var isRecording: Bool
    var onHotkey: (UInt32, UInt32) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onHotkey = onHotkey
        view.onCancel = onCancel
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onHotkey = onHotkey
        nsView.onCancel = onCancel
        nsView.isRecording = isRecording
    }
}

final class RecorderNSView: NSView {
    var onHotkey: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?

    var isRecording = false {
        didSet {
            if isRecording != oldValue {
                updateMonitor()
            }
        }
    }

    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func updateMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        guard isRecording else { return }
        window?.makeFirstResponder(self)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let isFunctionKey = HotkeyFormatting.functionKeyCodes.contains(event.keyCode)
        let hasModifier = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)

        guard hasModifier || isFunctionKey else {
            NSSound.beep()
            return
        }

        onHotkey?(UInt32(event.keyCode), HotkeyFormatting.carbonModifiers(from: flags))
    }
}
