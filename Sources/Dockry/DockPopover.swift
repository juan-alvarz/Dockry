import AppKit
import DockryCore
import SwiftUI

extension View {
    /// A popover from a dock item, on the side facing the middle of the screen. While it's
    /// open Dockry is the active app, so text fields in it get the keyboard; closing it hands
    /// the keyboard back to the app that had it.
    func dockPopover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(DockPopoverModifier(isPresented: isPresented, popoverContent: content))
    }
}

private struct DockPopoverModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let popoverContent: () -> PopoverContent
    @Environment(\.dockMetrics) private var metrics

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented, arrowEdge: metrics.position.innerEdge, content: popoverContent)
            .onChange(of: isPresented) { _, isShown in
                isShown ? PopoverFocus.begin() : PopoverFocus.end()
            }
    }
}

@MainActor
enum PopoverFocus {
    private static var previousApp: NSRunningApplication?

    static func begin() {
        DockInteraction.shared.begin()
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost != .current {
            previousApp = frontmost
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func end() {
        DockInteraction.shared.end()
        // Unless the user already moved on to another app, or is using Dockry's settings.
        if NSApp.isActive && !SettingsWindow.isOpen {
            previousApp?.activate()
        }
        previousApp = nil
    }
}

/// Launch arguments CI uses to show parts of the UI for screenshots, e.g.
/// `open Dockry.app --args -openPopover spotify`. Arguments aren't saved, so these never
/// stick around in a real install.
enum ScreenshotHook {
    static var popover: String? { UserDefaults.standard.string(forKey: "openPopover") }
    static var spotifySearchQuery: String? { UserDefaults.standard.string(forKey: "spotifySearchQuery") }
    static var settingsTab: String? { UserDefaults.standard.string(forKey: "showSettings") }
    /// The widget to show in Settings › Widgets.
    static var settingsWidget: WidgetKind? { UserDefaults.standard.string(forKey: "showWidget").flatMap(WidgetKind.init(rawValue:)) }
    /// Logs when the pointer enters and leaves a dock, to see what the magnification sees.
    static var logsPointer: Bool { UserDefaults.standard.bool(forKey: "logPointer") }
    /// Playback to show without Spotify, as SpotifyPlayback's AppleScript output with commas
    /// for line breaks: position,duration,volume,shuffling,repeating.
    static var spotifyPlayback: String? {
        UserDefaults.standard.string(forKey: "spotifyTestPlayback")?.replacingOccurrences(of: ",", with: "\n")
    }
    /// Album art for the song CI's notification announces, which (like Spotify's own) has none.
    static var spotifyArtwork: URL? {
        UserDefaults.standard.string(forKey: "spotifyTestArtwork").map { URL(fileURLWithPath: $0) }
    }
    /// A saved Spotify search response to show instead of searching, for CI's screenshots.
    static var spotifySearchResponse: URL? {
        UserDefaults.standard.string(forKey: "spotifyTestSearchResponse").map { URL(fileURLWithPath: $0) }
    }

    /// Opens a widget's popover a moment after the widget appears, if CI asked for it.
    static func openPopoverIfRequested(_ name: String, _ open: @escaping () -> Void) {
        guard popover == name else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: open)
    }
}
