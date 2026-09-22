import SwiftUI

enum SidebarItem: Hashable {
    case snippet(UUID)
    case swipes
    case middleClick
    case finder
    case finderPath
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: SidebarItem?
    @State private var countdown: Int?

    var body: some View {
        VStack(spacing: 0) {
            accessibilityBanner

            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 340)
            } detail: {
                switch selection {
                case .snippet(let id):
                    if let binding = snippetBinding(id) {
                        SnippetEditor(
                            snippet: binding,
                            model: model,
                            countdown: $countdown
                        )
                    } else {
                        ContentUnavailableView(
                            model.t.chooseSnippet,
                            systemImage: "keyboard",
                            description: Text(model.t.chooseSnippetHint)
                        )
                    }
                case .swipes:
                    GestureSettingsView(model: model)
                case .middleClick:
                    MiddleClickSettingsView(model: model)
                case .finder:
                    FinderSettingsView(model: model)
                case .finderPath:
                    FinderPathSettingsView(model: model)
                case nil:
                    ContentUnavailableView(
                        model.t.chooseSection,
                        systemImage: "sidebar.left",
                        description: Text(model.t.chooseSectionHint)
                    )
                }
            }

            footer
        }
        .onAppear {
            model.refreshAccessibility()
            if selection == nil {
                selection = model.snippets.first.map { .snippet($0.id) } ?? .swipes
            }
        }
        .onChange(of: model.snippets.map(\.id)) { _, ids in
            if case .snippet(let id) = selection, ids.contains(id) { return }
            if case .swipes = selection { return }
            if case .middleClick = selection { return }
            if case .finder = selection { return }
            if case .finderPath = selection { return }
            selection = ids.first.map { .snippet($0) } ?? .swipes
        }
        .overlay {
            if let countdown {
                ZStack {
                    Color.black.opacity(0.28)
                    VStack(spacing: 8) {
                        Text(model.t.switchWindow)
                            .font(.headline)
                        Text("\(countdown)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section(model.t.macrosSection) {
                if model.snippets.isEmpty {
                    Text(model.t.noSnippets)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.snippets) { snippet in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snippet.title.isEmpty ? (snippet.usesClipboard ? model.t.clipboardSnippet : model.t.untitledSnippet) : snippet.title)
                                .font(.headline)
                                .lineLimit(1)
                            HStack {
                                Text(snippet.hasHotkey ? snippet.hotkeyDisplay : model.t.noHotkey)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Spacer()
                                if !snippet.enabled {
                                    Text(model.t.disabledShort)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .tag(SidebarItem.snippet(snippet.id))
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(model.t.gesturesSection) {
                Label(model.t.twoFingerSwipe, systemImage: "hand.draw")
                    .tag(SidebarItem.swipes)
                Label(model.t.threeFingerClick, systemImage: "hand.tap")
                    .tag(SidebarItem.middleClick)
            }

            Section(model.t.finderSection) {
                Label(model.t.newTextFile, systemImage: "doc.badge.plus")
                    .tag(SidebarItem.finder)
                Label(model.t.finderPathSection, systemImage: "terminal")
                    .tag(SidebarItem.finderPath)
            }

            Section(model.t.startupSection) {
                Toggle(model.t.openAtLogin, isOn: $model.openAtLogin)
                    .onChange(of: model.openAtLogin) { _, _ in
                        model.persistOpenAtLogin()
                    }
            }

            Section(model.t.languageSection) {
                Picker(model.t.languageSection, selection: $model.language) {
                    Text(model.t.languageSystem).tag(AppLanguage.system)
                    Text(model.t.languageRussian).tag(AppLanguage.russian)
                    Text(model.t.languageEnglish).tag(AppLanguage.english)
                }
                .labelsHidden()
                .onChange(of: model.language) { _, _ in
                    model.persistLanguage()
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.addSnippet()
                    selection = .snippet(model.snippets.first?.id ?? UUID())
                } label: {
                    Image(systemName: "plus")
                }
                .help(model.t.addSnippetHelp)

                Button {
                    if case .snippet(let id) = selection {
                        model.removeSnippet(id: id)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(!canDeleteSelectedSnippet)
                .help(model.t.removeSnippetHelp)
            }
        }
        .navigationTitle("macOS_sucks")
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(model.t.keyDelay)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(model.keyDelayMs) },
                    set: {
                        model.keyDelayMs = Int($0)
                        model.persistText()
                    }
                ),
                in: 8...80,
                step: 1
            )
            .frame(maxWidth: 220)
            Text(model.t.milliseconds(model.keyDelayMs))
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
            Spacer()
            if let status = model.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var accessibilityBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            if model.isAccessibilityTrusted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.large)
                    .padding(.top, 2)
                Text(model.t.accessGranted)
                    .font(.callout)
                Spacer()
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .imageScale(.large)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t.staleCopyTitle)
                        .font(.headline)
                    Text(model.t.staleCopyBody)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(model.bundlePath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Text(model.t.thenRelaunch)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Button(model.t.revealInFinder) {
                        model.revealAppInFinder()
                    }
                    Button(model.t.openAccessibility) {
                        model.requestAccessibility()
                    }
                    Button(model.t.relaunchApp) {
                        model.relaunch()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(model.isAccessibilityTrusted ? Color.green.opacity(0.12) : Color.orange.opacity(0.18))
    }

    private var isSnippetSelected: Bool {
        if case .snippet = selection { return true }
        return false
    }

    private var canDeleteSelectedSnippet: Bool {
        guard case .snippet(let id) = selection,
              let snippet = model.snippets.first(where: { $0.id == id })
        else {
            return false
        }
        return !snippet.usesClipboard
    }

    private func snippetBinding(_ id: UUID) -> Binding<Snippet>? {
        guard let index = model.snippets.firstIndex(where: { $0.id == id }) else { return nil }
        return $model.snippets[index]
    }
}

struct SnippetEditor: View {
    @Binding var snippet: Snippet
    @Bindable var model: AppModel
    @Binding var countdown: Int?

    @State private var recording = false
    @State private var testTask: DispatchWorkItem?

    var body: some View {
        Form {
            Section(model.t.howToUse) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t.howTo1)
                    if snippet.usesClipboard {
                        Text(model.t.howToClipboard2)
                        Text(model.t.howToClipboard3)
                    } else {
                        Text(model.t.howTo2)
                        Text(model.t.howTo3)
                    }
                    Text(model.t.howTo4)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section(model.t.macroSection) {
                TextField(model.t.name, text: $snippet.title)
                    .onChange(of: snippet.title) { _, _ in
                        model.persistText()
                    }
                Toggle(model.t.enabled, isOn: $snippet.enabled)
                    .onChange(of: snippet.enabled) { _, _ in
                        model.persistAndReloadHotkeys()
                    }
            }

            Section(model.t.textSection) {
                if snippet.usesClipboard {
                    Text(model.t.clipboardHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(model.t.textHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $snippet.text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                        .onChange(of: snippet.text) { _, _ in
                            model.persistText()
                        }
                }
            }

            Section(model.t.shortcutSection) {
                HStack(spacing: 12) {
                    Text(recording ? model.t.pressShortcut : (snippet.hasHotkey ? snippet.hotkeyDisplay : model.t.noHotkey))
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(recording ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(recording ? Color.accentColor : Color.secondary.opacity(0.25))
                        )

                    Button(recording ? model.t.cancel : model.t.record) {
                        recording.toggle()
                        model.isRecordingHotkey = recording
                    }
                    Button(model.t.clear) {
                        recording = false
                        model.isRecordingHotkey = false
                        model.setHotkey(id: snippet.id, keyCode: nil, modifiers: 0)
                    }
                    .disabled(snippet.keyCode == nil && !recording)
                }
                .overlay {
                    HotkeyRecorder(
                        isRecording: recording,
                        onHotkey: { keyCode, modifiers in
                            recording = false
                            model.isRecordingHotkey = false
                            model.setHotkey(id: snippet.id, keyCode: keyCode, modifiers: modifiers)
                        },
                        onCancel: {
                            recording = false
                            model.isRecordingHotkey = false
                        }
                    )
                    .frame(width: 0, height: 0)
                }

                if model.hotkeyConflict(for: snippet) {
                    Label(model.t.shortcutTaken, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                }

                if let failure = model.hotkeyFailures[snippet.id] {
                    Label(failure, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                } else if snippet.hasHotkey, snippet.enabled, model.registeredHotkeyIDs.contains(snippet.id) {
                    Label(model.t.shortcutActive(snippet.hotkeyDisplay), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if snippet.hasHotkey, !snippet.enabled {
                    Label(model.t.macroDisabled, systemImage: "pause.circle")
                        .foregroundStyle(.secondary)
                }

                Text(model.t.shortcutRules)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(model.t.testSection) {
                Button(countdown == nil ? model.t.testIdle : model.t.testCounting) {
                    startCountdown()
                }
                .disabled(countdown != nil)
                Text(model.t.testHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .navigationTitle("macOS_sucks")
        .onDisappear {
            testTask?.cancel()
            if recording {
                recording = false
                model.isRecordingHotkey = false
            }
        }
    }

    private func startCountdown() {
        if !snippet.usesClipboard {
            let trimmed = snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                model.statusMessage = model.t.enterMacroText
                return
            }
        }
        guard model.isAccessibilityTrusted else {
            model.statusMessage = model.t.grantAccessToTest
            model.requestAccessibility()
            return
        }
        testTask?.cancel()
        countdown = 5
        scheduleTick()
    }

    private func scheduleTick() {
        let work = DispatchWorkItem {
            guard let value = countdown else { return }
            if value <= 1 {
                countdown = nil
                if snippet.usesClipboard {
                    model.runSnippet(id: snippet.id)
                } else {
                    model.runText(snippet.text)
                }
            } else {
                countdown = value - 1
                scheduleTick()
            }
        }
        testTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }
}
