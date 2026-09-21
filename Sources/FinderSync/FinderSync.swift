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
        guard FinderSyncSettings.isMenuEnabled() else { return nil }
        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForItems:
            let menu = NSMenu(title: "")
            let strings = L10n(FinderSyncSettings.resolvedLanguage())
            let item = NSMenuItem(
                title: strings.finderMenuItem,
                action: #selector(createTextDocument(_:)),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
            return menu
        default:
            return nil
        }
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
