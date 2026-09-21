import ApplicationServices
import AppKit
import FinderSync
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
final class AppModel {
    var snippets: [Snippet] = []
    var keyDelayMs: Int = 30
    var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    var statusMessage: String?
    var hotkeyFailures: [UUID: String] = [:]
    var registeredHotkeyIDs: Set<UUID> = []
    var swipeGesturesEnabled: Bool = true
    var swipeApps: [GestureTarget] = GestureTarget.defaults()
    var swipeStatus: String?
    var middleClickEnabled: Bool = true
    var middleClickStatus: String?
    var finderSyncEnabled: Bool = FinderSyncSettings.isMenuEnabled()
    var finderExtensionEnabledInSystem: Bool = false
    var language: AppLanguage = .system
    var openAtLogin: Bool = true

    var t: L10n { L10n(language.resolved) }

    @ObservationIgnored
    private let hotkeys = HotkeyCenter()
    @ObservationIgnored
    private let typer = KeystrokeTyper()
    @ObservationIgnored
    private let swipes = SwipeGestureMonitor()
    @ObservationIgnored
    private let middleClick = MiddleClickMonitor()
    @ObservationIgnored
    private var accessibilityTimer: Timer?
    @ObservationIgnored
    private var finderRevealObserver: NSObjectProtocol?

    private let snippetsKey = "snippets"
    private let delayKey = "keyDelayMs"
    private let swipeEnabledKey = "swipeGesturesEnabled"
    private let swipeAppsKey = "swipeApps"
    private let middleClickKey = "middleClickEnabled"
    private let languageKey = "interfaceLanguage"
    private let openAtLoginKey = "openAtLogin"

    init() {
        load()
        hotkeys.onHotkey = { [weak self] id in
            self?.runSnippet(id: id)
        }
    }

    var isRecordingHotkey: Bool = false {
        didSet { updateHotkeySuppression() }
    }
    @ObservationIgnored
    private var isTyping = false

    func startAfterLaunch() {
        applyHotkeyReload(hotkeys.start(with: snippets, strings: t))
        swipes.strings = { [weak self] in
            self?.t ?? L10n(.en)
        }
        swipes.onNavigate = { fingerMovedRight in
            NavigationShortcut.postBracket(leftToRight: !fingerMovedRight)
        }
        swipes.onStatus = { [weak self] text in
            self?.swipeStatus = text
        }
        middleClick.strings = { [weak self] in
            self?.t ?? L10n(.en)
        }
        middleClick.onStatus = { [weak self] text in
            self?.middleClickStatus = text
        }
        updateSwipeMonitor()
        updateMiddleClickMonitor()
        swipes.start()
        middleClick.start()
        FinderSyncSettings.setLanguage(language)
        registerFinderExtension()
        refreshFinderExtensionStatus()
        listenForFinderReveal()
        applyOpenAtLogin()
        startAccessibilityPolling()
        refreshAccessibility()
    }

    func persistOpenAtLogin() {
        persist()
        applyOpenAtLogin()
    }

    func persistFinderSync() {
        FinderSyncSettings.setMenuEnabled(finderSyncEnabled)
        FinderSyncSettings.setLanguage(language)
    }

    func persistLanguage() {
        persist()
        FinderSyncSettings.setLanguage(language)
        applyHotkeyReload(hotkeys.reload(snippets, strings: t))
    }

    func openFinderExtensionSettings() {
        registerFinderExtension()
        FIFinderSyncController.showExtensionManagementInterface()
    }

    func refreshFinderExtensionStatus() {
        finderExtensionEnabledInSystem = isFinderExtensionEnabledInSystem()
    }

    func addSnippet() {
        let snippet = Snippet(title: t.newSnippet)
        snippets.insert(snippet, at: 0)
        persistAndReloadHotkeys()
    }

    func removeSnippet(id: UUID) {
        snippets.removeAll { $0.id == id && !$0.usesClipboard }
        persistAndReloadHotkeys()
    }

    func persistSwipeSettings() {
        persist()
        updateSwipeMonitor()
    }

    func persistMiddleClick() {
        persist()
        updateMiddleClickMonitor()
    }

    func persistText() {
        persist()
    }

    func testSwipe(_ leftToRight: Bool) {
        swipeStatus = t.testSendingLeft(leftToRight)
        NavigationShortcut.postBracket(leftToRight: leftToRight)
    }

    func testMiddleClick() {
        middleClickStatus = t.testMiddleClickSoon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            MiddleClickPoster.postAtCursor()
            self.middleClickStatus = self.t.middleClickTestSent
        }
    }

    func pickSwipeApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = t.pickSwipeApp
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                self?.addSwipeApp(url: url)
            }
        }
    }

    func removeSwipeApp(bundleIdentifier: String) {
        swipeApps.removeAll { $0.bundleIdentifier == bundleIdentifier && !$0.locked }
        persistSwipeSettings()
    }

    func displayName(for app: GestureTarget) -> String {
        if app.bundleIdentifier == "com.apple.systempreferences" {
            return t.systemSettingsName
        }
        return app.name
    }

    func icon(for bundleIdentifier: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(size: NSSize(width: 22, height: 22))
    }

    func persistAndReloadHotkeys() {
        persist()
        applyHotkeyReload(hotkeys.reload(snippets, strings: t))
    }

    func setHotkey(id: UUID, keyCode: UInt32?, modifiers: UInt32) {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[index].keyCode = keyCode
        snippets[index].carbonModifiers = modifiers
        persistAndReloadHotkeys()
    }

    func runSnippet(id: UUID) {
        guard let snippet = snippets.first(where: { $0.id == id }) else { return }
        if snippet.usesClipboard {
            guard let text = Self.plainTextFromClipboard() else { return }
            runText(text, fromHotkey: true, requireNonEmpty: false)
            return
        }
        runText(snippet.text, fromHotkey: true)
    }

    func runText(_ text: String, fromHotkey: Bool = false, requireNonEmpty: Bool = true) {
        refreshAccessibility()
        let payload = requireNonEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : text
        guard !payload.isEmpty else {
            if requireNonEmpty {
                statusMessage = t.enterMacroText
            }
            return
        }
        guard isAccessibilityTrusted else {
            statusMessage = t.cannotTypeNeedAccess
            if fromHotkey {
                AppDelegate.shared?.showSettings()
                NSApp.requestUserAttention(.informationalRequest)
            }
            return
        }

        statusMessage = fromHotkey ? t.firingMacro : t.typingText
        isTyping = true
        updateHotkeySuppression()
        typer.typeAsync(payload, delayMs: keyDelayMs) { [weak self] error in
            guard let self else { return }
            self.isTyping = false
            self.updateHotkeySuppression()
            if let error {
                if let typing = error as? TypingError {
                    self.statusMessage = typing.message(using: self.t)
                } else {
                    self.statusMessage = error.localizedDescription
                }
                if fromHotkey {
                    AppDelegate.shared?.showSettings()
                }
            } else {
                self.statusMessage = self.t.typedOK
            }
        }
    }

    func requestAccessibility() {
        isAccessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
        AccessibilityPermission.openSystemSettings()
        if !isAccessibilityTrusted {
            statusMessage = t.replaceOldCopy
        }
    }

    var bundlePath: String { Bundle.main.bundlePath }

    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: bundlePath)])
    }

    func refreshAccessibility() {
        isAccessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
    }

    func relaunch() {
        persist()
        AccessibilityPermission.relaunch()
    }

    func hotkeyConflict(for snippet: Snippet) -> Bool {
        guard let keyCode = snippet.keyCode else { return false }
        return snippets.contains {
            $0.id != snippet.id && $0.keyCode == keyCode && $0.carbonModifiers == snippet.carbonModifiers
        }
    }

    func hotkeyStatus(for snippet: Snippet) -> String? {
        if let failure = hotkeyFailures[snippet.id] {
            return failure
        }
        if snippet.hasHotkey, snippet.enabled, registeredHotkeyIDs.contains(snippet.id) {
            return nil
        }
        return nil
    }

    private func updateHotkeySuppression() {
        hotkeys.suppressEvents = isRecordingHotkey || isTyping
        swipes.isSuppressed = isRecordingHotkey || isTyping
        middleClick.isSuppressed = isRecordingHotkey || isTyping
    }

    private func applyHotkeyReload(_ result: HotkeyReloadResult) {
        registeredHotkeyIDs = result.registeredIDs
        hotkeyFailures = result.failures
    }

    private func load() {
        if let stored = UserDefaults.standard.string(forKey: languageKey),
           let parsed = AppLanguage(rawValue: stored) {
            language = parsed
        }
        if let data = UserDefaults.standard.data(forKey: snippetsKey),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        }
        ensureClipboardSnippet()
        let storedDelay = UserDefaults.standard.integer(forKey: delayKey)
        keyDelayMs = storedDelay == 0 ? 30 : storedDelay
        if UserDefaults.standard.object(forKey: swipeEnabledKey) != nil {
            swipeGesturesEnabled = UserDefaults.standard.bool(forKey: swipeEnabledKey)
        }
        if let data = UserDefaults.standard.data(forKey: swipeAppsKey),
           let decoded = try? JSONDecoder().decode([GestureTarget].self, from: data) {
            swipeApps = mergeSwipeApps(saved: decoded)
        }
        if UserDefaults.standard.object(forKey: openAtLoginKey) != nil {
            openAtLogin = UserDefaults.standard.bool(forKey: openAtLoginKey)
        }
        if UserDefaults.standard.object(forKey: middleClickKey) != nil {
            middleClickEnabled = UserDefaults.standard.bool(forKey: middleClickKey)
        }
    }

    private func ensureClipboardSnippet() {
        if snippets.contains(where: \.usesClipboard) { return }
        snippets.insert(Snippet.clipboardDefault(title: t.clipboardSnippet), at: 0)
    }

    private static func plainTextFromClipboard() -> String? {
        let board = NSPasteboard.general
        guard board.availableType(from: [.string]) != nil else { return nil }
        guard let text = board.string(forType: .string), !text.isEmpty else { return nil }
        return text
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(data, forKey: snippetsKey)
        }
        UserDefaults.standard.set(keyDelayMs, forKey: delayKey)
        UserDefaults.standard.set(swipeGesturesEnabled, forKey: swipeEnabledKey)
        if let data = try? JSONEncoder().encode(swipeApps) {
            UserDefaults.standard.set(data, forKey: swipeAppsKey)
        }
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        UserDefaults.standard.set(openAtLogin, forKey: openAtLoginKey)
        UserDefaults.standard.set(middleClickEnabled, forKey: middleClickKey)
    }

    private func applyOpenAtLogin() {
        do {
            try LoginLaunch.setEnabled(openAtLogin)
            if openAtLogin, !LoginLaunch.isEnabled {
                statusMessage = t.loginItemFailed
            }
        } catch {
            openAtLogin = LoginLaunch.isEnabled
            statusMessage = t.loginItemFailed
        }
    }

    private func addSwipeApp(url: URL) {
        let bundle = Bundle(url: url)
        guard let identifier = bundle?.bundleIdentifier else { return }
        if swipeApps.contains(where: { $0.bundleIdentifier == identifier }) {
            if let index = swipeApps.firstIndex(where: { $0.bundleIdentifier == identifier }) {
                swipeApps[index].enabled = true
            }
            persistSwipeSettings()
            return
        }
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        swipeApps.append(
            GestureTarget(bundleIdentifier: identifier, name: name, enabled: true, locked: false)
        )
        persistSwipeSettings()
    }

    private func mergeSwipeApps(saved: [GestureTarget]) -> [GestureTarget] {
        var result = GestureTarget.defaults()
        for index in result.indices {
            if let match = saved.first(where: { $0.bundleIdentifier == result[index].bundleIdentifier }) {
                result[index].enabled = match.enabled
            }
        }
        let extras = saved.filter { candidate in
            !result.contains(where: { $0.bundleIdentifier == candidate.bundleIdentifier })
        }
        result.append(contentsOf: extras.map {
            GestureTarget(
                bundleIdentifier: $0.bundleIdentifier,
                name: $0.name,
                enabled: $0.enabled,
                locked: false
            )
        })
        return result
    }

    private func updateSwipeMonitor() {
        swipes.update(enabled: swipeGesturesEnabled, targets: swipeApps)
    }

    private func updateMiddleClickMonitor() {
        middleClick.update(enabled: middleClickEnabled)
    }

    private func listenForFinderReveal() {
        if let finderRevealObserver {
            DistributedNotificationCenter.default().removeObserver(finderRevealObserver)
        }
        finderRevealObserver = DistributedNotificationCenter.default().addObserver(
            forName: FinderSyncSettings.revealNotification,
            object: nil,
            queue: .main
        ) { notification in
            FinderReveal.handle(notification)
        }
    }

    private func registerFinderExtension() {
        guard let url = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("AutoTextFinderSync.appex")
        else {
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        task.arguments = ["-a", url.path]
        try? task.run()
        task.waitUntilExit()
    }

    private func isFinderExtensionEnabledInSystem() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        task.arguments = ["-m", "-i", "local.autotext.FinderSync"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.contains("+") && output.contains("local.autotext.FinderSync")
    }

    private func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshAccessibility()
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        accessibilityTimer = timer
    }
}

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if AXIsProcessTrusted() {
            return true
        }
        return canUseAccessibilityAPI()
    }

    static func canUseAccessibilityAPI() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &value
        )
        return result == .success
    }

    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    static func relaunch() {
        let path = Bundle.main.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}
