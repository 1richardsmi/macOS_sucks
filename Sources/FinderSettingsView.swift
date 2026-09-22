import SwiftUI

struct FinderSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section(model.t.finderMenuSection) {
                Toggle(model.t.finderMenuToggle, isOn: $model.finderSyncEnabled)
                    .onChange(of: model.finderSyncEnabled) { _, _ in
                        model.persistFinderSync()
                    }
                Text(model.t.finderMenuHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(model.t.extensionSection) {
                if model.finderExtensionEnabledInSystem {
                    Label(model.t.extensionOn, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(model.t.extensionOff, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text(model.t.extensionHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button(model.t.openFinderExtensions) {
                    model.openFinderExtensionSettings()
                }
                Button(model.t.checkStatus) {
                    model.refreshFinderExtensionStatus()
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .navigationTitle("macOS_sucks")
        .onAppear {
            model.refreshFinderExtensionStatus()
        }
    }
}

struct FinderPathSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section(model.t.finderPathSection) {
                Toggle(model.t.openTerminalToggle, isOn: $model.finderOpenTerminalEnabled)
                    .onChange(of: model.finderOpenTerminalEnabled) { _, _ in
                        model.persistFinderFolderActions()
                    }
                Toggle(model.t.copyPathToggle, isOn: $model.finderCopyPathEnabled)
                    .onChange(of: model.finderCopyPathEnabled) { _, _ in
                        model.persistFinderFolderActions()
                    }
                Text(model.t.finderPathHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .navigationTitle("macOS_sucks")
    }
}
