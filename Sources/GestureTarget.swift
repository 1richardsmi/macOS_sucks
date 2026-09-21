import Foundation

struct GestureTarget: Identifiable, Codable, Equatable {
    var bundleIdentifier: String
    var name: String
    var enabled: Bool
    var locked: Bool

    var id: String { bundleIdentifier }

    static func defaults() -> [GestureTarget] {
        [
            GestureTarget(
                bundleIdentifier: "com.apple.finder",
                name: "Finder",
                enabled: true,
                locked: true
            ),
            GestureTarget(
                bundleIdentifier: "com.apple.systempreferences",
                name: "Системные настройки",
                enabled: true,
                locked: true
            )
        ]
    }

    static let aliases: [String: [String]] = [
        "com.apple.systempreferences": [
            "com.apple.SystemSettings",
            "com.apple.Preferences"
        ]
    ]

    static func matches(_ bundleID: String, enabledTargets: [GestureTarget]) -> Bool {
        enabledTargets.contains { target in
            guard target.enabled else { return false }
            if target.bundleIdentifier == bundleID {
                return true
            }
            return Self.aliases[target.bundleIdentifier]?.contains(bundleID) == true
        }
    }
}
