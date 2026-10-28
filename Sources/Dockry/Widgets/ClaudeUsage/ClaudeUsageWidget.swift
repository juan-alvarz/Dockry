import AppKit
import DockryCore
import SwiftUI

/// The Claude plan's 5-hour and weekly usage, like `/usage` in Claude Code. Clicking it shows
/// the details. In a dock on the side of the screen it's Claude's icon with the 5-hour
/// percentage on a badge, which tells it apart from the Claude app.
struct ClaudeUsageWidget: View {
    static let widget = DockWidget(
        info: WidgetKind.claude.info,
        makeView: { AnyView(ClaudeUsageWidget()) },
        makeSettings: { AnyView(ClaudeUsageSettings()) })

    @ObservedObject private var monitor = ClaudeUsageMonitor.shared
    @Environment(\.dockMetrics) private var metrics
    @State private var showsDetails = false

    /// The size it's designed at, for 48-point icons; it scales with the dock from there.
    private static let designSize = CGSize(width: 120, height: 48)

    var body: some View {
        Button { showsDetails.toggle() } label: {
            Group {
                if metrics.axis == .vertical {
                    badgedIcon
                } else {
                    bars
                        .frame(width: Self.designSize.width, height: Self.designSize.height)
                        .scaleEffect(metrics.unit)
                        .frame(width: Self.designSize.width * metrics.unit, height: metrics.iconSize)
                        .widgetTile()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(monitor.state.explanation)
        .dockPopover(isPresented: $showsDetails) { ClaudeUsagePopover() }
        // Fetch only while the widget is on screen.
        .onAppear {
            monitor.widgetAppeared()
            ScreenshotHook.openPopoverIfRequested("claude") { showsDetails = true }
        }
        .onDisappear { monitor.widgetDisappeared() }
    }

    private var badgedIcon: some View {
        let used: Double? = if case .usage(let usage) = monitor.state { usage.session.percentUsed } else { nil }
        return WidgetIcon(info: WidgetKind.claude.info, size: metrics.iconSize)
            .overlay(alignment: .bottomTrailing) {
                Text(used.map { "\(Int($0.rounded()))%" } ?? "!")
                    .font(.system(size: 10 * metrics.unit, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4 * metrics.unit)
                    .frame(minWidth: 18 * metrics.unit, minHeight: 16 * metrics.unit)
                    .background(used.map(UsageBar.color(for:)) ?? .gray, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    .offset(x: 3 * metrics.unit, y: 3 * metrics.unit)
            }
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

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
    }
}

struct UsageBar: View {
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
