import AppKit
import SwiftUI

@main
struct AutoTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("macOS_sucks", systemImage: "keyboard.fill") {
            MenuBarView(model: appDelegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    let model = AppModel()
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        model.startAfterLaunch()
        DispatchQueue.main.async { [weak self] in
            self?.showSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "macOS_sucks"
            window.minSize = NSSize(width: 740, height: 460)
            window.isReleasedWhenClosed = false
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            window.setFrameAutosaveName("MacOSSucksSettings")
            settingsWindow = window
        }
        guard let window = settingsWindow else { return }
        if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) == false {
            window.center()
        }
        window.deminiaturize(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct MenuBarView: View {
    @Bindable var model: AppModel

    var body: some View {
        Button(model.t.settings) {
            AppDelegate.shared?.showSettings()
        }
        Divider()
        if model.snippets.isEmpty {
            Text(model.t.noSnippets)
        } else {
            ForEach(model.snippets) { snippet in
                Button {
                    model.runSnippet(id: snippet.id)
                } label: {
                    if snippet.hasHotkey {
                        Text("\(snippet.title)  (\(snippet.hotkeyDisplay))")
                    } else {
                        Text(snippet.title)
                    }
                }
                .disabled(!snippet.enabled || snippet.text.isEmpty)
            }
        }
        Divider()
        Button(model.t.quit) {
            NSApp.terminate(nil)
        }
    }
}
