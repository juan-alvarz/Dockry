import AppKit
import DockryCore
import SwiftUI

/// The details that open from the Claude Usage widget: each limit with how much is used and
/// when it resets.
struct ClaudeUsagePopover: View {
    @ObservedObject private var monitor = ClaudeUsageMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                WidgetIcon(info: WidgetKind.claude.info, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude Usage").font(.headline)
                    if let updatedAt = monitor.updatedAt {
                        TimelineView(.everyMinute) { _ in
                            Text("Updated \(updatedAt.formatted(.relative(presentation: .named)))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button { monitor.refreshSoon() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Check again")
            }
            if case .usage(let usage) = monitor.state {
                limit("5-hour limit", usage.session)
                limit("Weekly limit", usage.week)
            } else {
                Text(monitor.state.explanation)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Button("Open Usage Page on claude.ai") { NSWorkspace.shared.open(ClaudeUsageMonitor.usagePage) }
                .buttonStyle(.link)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { monitor.refreshSoon() }
    }

    private func limit(_ name: String, _ window: ClaudeUsage.Window) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(window.percentUsed.rounded()))% used")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(UsageBar.color(for: window.percentUsed))
                            .frame(width: geometry.size.width * window.percentUsed / 100)
                    }
            }
            .frame(height: 8)
            if let resetsAt = window.resetsAt {
                TimelineView(.everyMinute) { _ in
                    Text("Resets \(resetsAt.formatted(.relative(presentation: .named))), \(resetsAt.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
