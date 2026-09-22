import Cocoa
import FinderSync

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        refreshWatchedDirectories()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshWatchedDirectories),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshWatchedDirectories),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let strings = L10n(FinderSyncSettings.resolvedLanguage())
        let menu = NSMenu(title: "")
        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForItems:
            if FinderSyncSettings.isMenuEnabled() {
                menu.addItem(menuItem(strings.finderMenuItem, #selector(createTextDocument(_:))))
            }
            if FinderSyncSettings.isOpenTerminalEnabled() {
                menu.addItem(menuItem(strings.openTerminalHere, #selector(openTerminalHere(_:))))
            }
            if FinderSyncSettings.isCopyPathEnabled() {
                menu.addItem(menuItem(strings.copyFolderPath, #selector(copyFolderPath(_:))))
            }
        default:
            return nil
        }
        return menu.items.isEmpty ? nil : menu
    }

    @objc private func refreshWatchedDirectories() {
        var urls: Set<URL> = [
            URL(fileURLWithPath: NSHomeDirectory()),
            URL(fileURLWithPath: "/")
        ]
        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            urls.formUnion(volumes)
        }
        FIFinderSyncController.default().directoryURLs = urls
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openTerminalHere(_ sender: Any?) {
        guard let folder = terminalFolder(), !isTrash(folder) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", folder.path]
        try? process.run()
    }

    @objc private func copyFolderPath(_ sender: Any?) {
        guard let text = pathToCopy() else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    private func pathToCopy() -> String? {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), !selected.isEmpty {
            return selected.map(\.path).joined(separator: "\n")
        }
        return currentFolder()?.path
    }

    @objc private func createTextDocument(_ sender: Any?) {
        guard let destination = destinationFolder() else { return }
        guard let fileURL = uniqueTextFileURL(in: destination.folder) else { return }
        let created = FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard created else { return }
        FinderSyncSettings.requestReveal(
            file: fileURL,
            folder: destination.folder,
            expandFolder: destination.expand
        )
    }

    private func currentFolder() -> URL? {
        FIFinderSyncController.default().targetedURL()
    }

    private func terminalFolder() -> URL? {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), selected.count == 1, let only = selected.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: only.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return only
            }
            return only.deletingLastPathComponent()
        }
        return currentFolder()
    }

    private func isTrash(_ url: URL) -> Bool {
        let path = url.path
        return path.hasSuffix("/.Trash") || path.contains("/.Trash/")
    }

    private func destinationFolder() -> (folder: URL, expand: Bool)? {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), selected.count == 1, let only = selected.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: only.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return (only, true)
            }
        }
        guard let target = controller.targetedURL() else { return nil }
        return (target, false)
    }

    private func uniqueTextFileURL(in folder: URL) -> URL? {
        let fm = FileManager.default
        let base = L10n(FinderSyncSettings.resolvedLanguage()).newDocumentName
        let first = folder.appendingPathComponent("\(base).txt")
        if !fm.fileExists(atPath: first.path) {
            return first
        }
        for index in 2...999 {
            let candidate = folder.appendingPathComponent("\(base) \(index).txt")
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
