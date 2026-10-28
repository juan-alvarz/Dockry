import AppKit
import DockryCore
import SwiftUI

/// The Claude plan's 5-hour and weekly usage, like `/usage` in Claude Code. Clicking it opens
/// the usage page on claude.ai. In a dock on the side of the screen it's a ring for the
/// 5-hour limit.
struct ClaudeUsageWidget: View {
    @ObservedObject private var monitor = ClaudeUsageMonitor.shared
    @Environment(\.dockMetrics) private var metrics

    /// The size it's designed at, for 48-point icons; it scales with the dock from there.
    private static let designSize = CGSize(width: 120, height: 48)

    var body: some View {
        Button(action: openUsagePage) {
            Group {
                if metrics.axis == .vertical {
                    ring
                } else {
                    bars
                        .frame(width: Self.designSize.width, height: Self.designSize.height)
                        .scaleEffect(metrics.unit)
                        .frame(width: Self.designSize.width * metrics.unit, height: metrics.iconSize)
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12 * metrics.unit, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        // Fetch only while the widget is on screen.
        .onAppear { monitor.widgetAppeared() }
        .onDisappear { monitor.widgetDisappeared() }
    }

    private var ring: some View {
        let used: Double? = if case .usage(let usage) = monitor.state { usage.session.percentUsed } else { nil }
        let lineWidth = 4 * metrics.unit
        return ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: (used ?? 0) / 100)
                .stroke(UsageBar.color(for: used ?? 0), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(used.map { "\(Int($0.rounded()))" } ?? "–")
                .font(.system(size: 11 * metrics.unit, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .padding(8 * metrics.unit)
        .frame(width: metrics.iconSize, height: metrics.iconSize)
    }

    private var bars: some View {
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
    }

    private func openUsagePage() {
        if let url = URL(string: "https://claude.ai/settings/usage") {
            NSWorkspace.shared.open(url)
        }
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
    static func color(for percentUsed: Double) -> Color {
        percentUsed >= 90 ? .red : Color(red: 0.85, green: 0.47, blue: 0.34)
    }

    private var color: Color { Self.color(for: window.percentUsed) }

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
