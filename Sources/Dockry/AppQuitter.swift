import AppKit
import Carbon

/// Quits other apps from the dock's menu, as choosing Quit in the app would (so it can ask to
/// save first).
///
/// With Accessibility access, Dockry presses the app's own Quit menu item: one permission
/// for every app. Without it, it sends the quit Apple event, which macOS only allows once
/// you've let Dockry control that app (Privacy & Security › Automation), asking once per
/// app. Without that, the request fails silently, so check, and say how to allow it.
@MainActor
enum AppQuitter {
    static func quit(_ app: NSRunningApplication) {
        guard AXIsProcessTrusted() else {
            quitWithAppleEvent(app)
            return
        }
        let pid = app.processIdentifier
        Task {
            // Off the main thread: a busy app can take a moment to answer Accessibility.
            let pressed = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: pressQuitMenuItem(of: pid))
                }
            }
            if !pressed {
                quitWithAppleEvent(app)
            }
        }
    }

    /// Presses the ⌘Q item in the app's menu (the one after the Apple menu), whatever the
    /// app's language calls it. False if there's no such item, e.g. an app without menus.
    private nonisolated static func pressQuitMenuItem(of pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2)
        guard let menuBar = element(kAXMenuBarAttribute, of: app),
              let menus = children(of: menuBar), menus.count > 1,
              let appMenu = children(of: menus[1])?.first,
              let items = children(of: appMenu)
        else { return false }
        let quit = items.last { item in
            var key: CFTypeRef?
            var modifiers: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &key)
            AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &modifiers)
            // No modifiers besides ⌘.
            return (key as? String)?.uppercased() == "Q" && (modifiers as? Int ?? 0) == 0
        }
        guard let quit else { return false }
        return AXUIElementPerformAction(quit, kAXPressAction as CFString) == .success
    }

    private nonisolated static func element(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private nonisolated static func children(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    private static func quitWithAppleEvent(_ app: NSRunningApplication) {
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
