import AppKit
import DockryCore
import SwiftUI

/// Claude Usage's part of Settings › Widgets: what the widget last found.
struct ClaudeUsageSettings: View {
    @ObservedObject private var monitor = ClaudeUsageMonitor.shared

    var body: some View {
        Section("Usage") {
            if case .usage(let usage) = monitor.state {
                UsageBar(label: "5h", window: usage.session)
                UsageBar(label: "7d", window: usage.week)
            }
            Text(monitor.isWatching
                ? monitor.state.explanation
                : "Dockry checks your usage while the widget is in the dock. Turn it on for a profile above.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open Usage Page on claude.ai") { NSWorkspace.shared.open(ClaudeUsageMonitor.usagePage) }
        }
    }
}

extension ClaudeUsageMonitor.State {
    /// For the widget's tooltip and Settings.
    var explanation: String {
        switch self {
        case .usage(let usage):
            return [("5-hour limit", usage.session), ("Weekly limit", usage.week)]
                .map { name, window in
                    let resets = window.resetsAt.map { ", resets \($0.formatted(.relative(presentation: .named)))" } ?? ""
                    return "\(name): \(Int(window.percentUsed.rounded()))% used\(resets)"
                }
                .joined(separator: "\n")
        case .signedOut:
            return "Sign in to Claude Code, and allow Dockry to read its saved sign-in when macOS asks."
        case .accessDenied:
            return "Dockry wasn't allowed to read Claude Code's sign-in. It asks again the next time it starts."
        case .expired:
            return "Open Claude Code to refresh its sign-in."
        case .unavailable:
            return "Couldn't get your Claude usage. Dockry tries again in a few minutes."
        case .loading:
            return "Getting your Claude usage…"
        }
    }
}
