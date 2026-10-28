import DockryCore
import SwiftUI

/// The Claude plan's 5-hour and weekly usage, like `/usage` in Claude Code.
struct ClaudeUsageWidget: View {
    @ObservedObject private var monitor = ClaudeUsageMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Claude", systemImage: "sparkle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            switch monitor.state {
            case .usage(let usage):
                UsageBar(label: "5h", window: usage.session)
                UsageBar(label: "7d", window: usage.week)
            case .loading:
                ProgressView().controlSize(.small)
            case .signedOut:
                message("Not signed in")
            case .accessDenied:
                message("Access denied")
            case .expired:
                message("Sign-in expired")
            case .unavailable:
                message("Unavailable")
            }
        }
        .frame(width: 104, alignment: .leading)
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .help(helpText)
        // Fetch only while the widget is on screen.
        .onAppear { monitor.widgetAppeared() }
        .onDisappear { monitor.widgetDisappeared() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
    }

    private var helpText: String {
        switch monitor.state {
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

private struct UsageBar: View {
    let label: String
    let window: ClaudeUsage.Window

    /// Claude's orange, turning red near the limit.
    private var color: Color {
        window.percentUsed >= 90 ? .red : Color(red: 0.85, green: 0.47, blue: 0.34)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: 48 * window.percentUsed / 100)
                }
                .frame(width: 48, height: 5)
            Text("\(Int(window.percentUsed.rounded()))%")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .frame(width: 28, alignment: .trailing)
        }
    }
}
