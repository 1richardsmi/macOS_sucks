import AppKit
import SwiftUI

struct GestureSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section(model.t.twoFingerSwipe) {
                Toggle(model.t.enableGestures, isOn: $model.swipeGesturesEnabled)
                    .onChange(of: model.swipeGesturesEnabled) { _, _ in
                        model.persistSwipeSettings()
                    }
                Text(model.t.swipeHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let status = model.swipeStatus {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(model.t.testLeftBracket) {
                        model.testSwipe(true)
                    }
                    Button(model.t.testRightBracket) {
                        model.testSwipe(false)
                    }
                }
                Text(model.t.swipeHowTo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(model.t.appsSection) {
                ForEach($model.swipeApps) { $app in
                    HStack(spacing: 10) {
                        Image(nsImage: model.icon(for: app.bundleIdentifier))
                            .resizable()
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName(for: app))
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Вкл", isOn: $app.enabled)
                            .labelsHidden()
                            .onChange(of: app.enabled) { _, _ in
                                model.persistSwipeSettings()
                            }
                        if !app.locked {
                            Button(role: .destructive) {
                                model.removeSwipeApp(bundleIdentifier: app.bundleIdentifier)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button(model.t.addApp) {
                    model.pickSwipeApp()
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .navigationTitle("macOS_sucks")
    }
}
