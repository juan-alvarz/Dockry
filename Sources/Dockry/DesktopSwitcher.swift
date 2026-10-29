import AppKit
import DockryCore

/// Switches macOS desktops (Spaces) by sending the system's own "Switch to Desktop N"
/// shortcut. macOS has no public API for Spaces; this keeps SIP on and uses the normal
/// switching animation.
enum DesktopSwitcher {
    enum Status {
        case ready(KeyShortcut)
        /// Posting keyboard events needs Accessibility access.
        case needsAccessibility
        /// The "Switch to Desktop N" shortcut is off in Keyboard Shortcuts › Mission Control.
        case shortcutOff
    }

    static func status(for desktop: Int) -> Status {
        guard AXIsProcessTrusted() else { return .needsAccessibility }
        let domain = "com.apple.symbolichotkeys" as CFString
        CFPreferencesAppSynchronize(domain)
        let hotKeys = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, domain) as? [String: Any] ?? [:]
        guard let shortcut = KeyShortcut.switchToDesktop(desktop, in: hotKeys) else { return .shortcutOff }
        return .ready(shortcut)
    }

    static func switchTo(desktop: Int) {
        guard case .ready(let shortcut) = status(for: desktop) else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for isKeyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: isKeyDown)
            event?.flags = CGEventFlags(rawValue: shortcut.modifierFlags)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Adds Dockry to Privacy & Security › Accessibility and opens that list.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // macOS shows its prompt only while Dockry isn't in the list yet. An entry left by an
        // older build (a new signature after an update) gets no prompt, so open the list itself.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openKeyboardShortcutsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
