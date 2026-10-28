import AppKit
import Carbon

/// Quits other apps from the dock's menu. Asking an app to quit is an Apple event, which
/// macOS only lets Dockry send once you've allowed it to control that app (Privacy &
/// Security › Automation). Without that, the request fails silently, so check, and say
/// how to allow it.
@MainActor
enum AppQuitter {
    static func quit(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else {
            app.terminate()
            return
        }
        Task {
            switch await permission(toControl: bundleID) {
            case 0:
                if !app.terminate() {
                    NSLog("Dockry: \(bundleID) didn't accept the request to quit")
                }
            case OSStatus(errAEEventNotPermitted):
                explainAutomation(for: app.localizedName ?? bundleID)
            default:
                // Couldn't tell (the app is still launching, say); try anyway.
                app.terminate()
            }
        }
    }

    /// Asks macOS whether Dockry may send `bundleID` Apple events, showing the consent prompt
    /// the first time. This can block until the user answers, so it runs off the main thread.
    private static func permission(toControl bundleID: String) async -> OSStatus {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var target = AEAddressDesc()
                let created = bundleID.withCString { pointer in
                    AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target)
                }
                guard created == 0 else {
                    continuation.resume(returning: OSStatus(created))
                    return
                }
                defer { AEDisposeDesc(&target) }
                let status = AEDeterminePermissionToAutomateTarget(
                    &target, AEEventClass(kCoreEventClass), AEEventID(kAEQuitApplication), true)
                continuation.resume(returning: status)
            }
        }
    }

    private static func explainAutomation(for appName: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Dockry isn’t allowed to quit \(appName)"
        alert.informativeText = "To quit apps from the dock, turn on \(appName) under Dockry in System Settings › Privacy & Security › Automation."
        alert.addButton(withTitle: "Open Automation Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
