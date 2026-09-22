import Foundation

enum FinderSyncSettings {
    static let changedNotification = Notification.Name("local.autotext.finderSyncChanged")
    static let revealNotification = Notification.Name("local.autotext.finderReveal")

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AutoText/finder-sync.json")
    }

    static func isMenuEnabled() -> Bool {
        (readObject()["enabled"] as? Bool) ?? true
    }

    static func isOpenTerminalEnabled() -> Bool {
        (readObject()["openTerminal"] as? Bool) ?? true
    }

    static func isCopyPathEnabled() -> Bool {
        (readObject()["copyPath"] as? Bool) ?? true
    }

    static func resolvedLanguage() -> ResolvedLanguage {
        switch readObject()["language"] as? String {
        case "ru":
            return .ru
        case "en":
            return .en
        default:
            return AppLanguage.system.resolved
        }
    }

    static func setMenuEnabled(_ enabled: Bool) {
        write(["enabled": enabled])
    }

    static func setOpenTerminalEnabled(_ enabled: Bool) {
        write(["openTerminal": enabled])
    }

    static func setCopyPathEnabled(_ enabled: Bool) {
        write(["copyPath": enabled])
    }

    static func setLanguage(_ language: AppLanguage) {
        write(["language": language.rawValue])
    }

    static func requestReveal(file: URL, folder: URL, expandFolder: Bool) {
        let payload: [String: Any] = [
            "file": file.path,
            "folder": folder.path,
            "expand": expandFolder
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let object = String(data: data, encoding: .utf8)
        else {
            return
        }
        DistributedNotificationCenter.default().postNotificationName(
            revealNotification,
            object: object,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func parseRevealRequest(_ notification: Notification) -> (file: String, folder: String, expand: Bool)? {
        guard
            let raw = notification.object as? String,
            let data = raw.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let file = object["file"] as? String,
            let folder = object["folder"] as? String
        else {
            return nil
        }
        return (file, folder, object["expand"] as? Bool ?? false)
    }

    private static func readObject() -> [String: Any] {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return object
    }

    private static func write(_ updates: [String: Any]) {
        var object = readObject()
        for (key, value) in updates {
            object[key] = value
        }
        if object["enabled"] == nil {
            object["enabled"] = true
        }
        if object["openTerminal"] == nil {
            object["openTerminal"] = true
        }
        if object["copyPath"] == nil {
            object["copyPath"] = true
        }
        let directory = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        try? data?.write(to: settingsURL, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            changedNotification,
            object: nil,
            userInfo: object,
            deliverImmediately: true
        )
    }
}
