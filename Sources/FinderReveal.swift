import ApplicationServices
import AppKit
import Foundation

enum FinderReveal {
    static func handle(_ notification: Notification) {
        guard let request = FinderSyncSettings.parseRevealRequest(notification) else { return }
        if request.expand {
            expandFolder(at: request.folder)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                selectFile(at: request.file, fallbackReveal: false)
            }
        } else {
            selectFile(at: request.file, fallbackReveal: false)
        }
    }

    private static func expandFolder(at path: String) {
        if expandSelectedRowsInFinder() {
            return
        }
        runAppleScript("""
        tell application "Finder"
            try
                set expanded of (\(posixFile(path)) as alias) to true
            end try
        end tell
        """)
    }

    private static func selectFile(at path: String, fallbackReveal: Bool) {
        let revealed = runAppleScript("""
        tell application "Finder"
            try
                select (\(posixFile(path)) as alias)
                return "ok"
            on error
                return "err"
            end try
        end tell
        """)
        if revealed != "ok", fallbackReveal {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }

    private static func posixFile(_ path: String) -> String {
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "POSIX file \"\(escaped)\""
    }

    @discardableResult
    private static func runAppleScript(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return result?.stringValue
    }

    private static func expandSelectedRowsInFinder() -> Bool {
        guard
            let pid = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.finder")
                .first?
                .processIdentifier
        else {
            return false
        }
        let app = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let window = windowRef
        else {
            return false
        }
        return expandSelectedRows(in: unsafeBitCast(window, to: AXUIElement.self), depth: 0)
    }

    private static func expandSelectedRows(in element: AXUIElement, depth: Int) -> Bool {
        guard depth < 18 else { return false }
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String

        if role == kAXOutlineRole as String || role == kAXTableRole as String {
            var selectedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSelectedRowsAttribute as CFString, &selectedRef) == .success,
               let rows = selectedRef as? [AXUIElement],
               !rows.isEmpty
            {
                var expandedAny = false
                for row in rows {
                    if AXUIElementSetAttributeValue(row, kAXExpandedAttribute as CFString, kCFBooleanTrue) == .success {
                        expandedAny = true
                    }
                }
                if expandedAny {
                    return true
                }
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement]
        else {
            return false
        }
        for child in children {
            if expandSelectedRows(in: child, depth: depth + 1) {
                return true
            }
        }
        return false
    }
}
