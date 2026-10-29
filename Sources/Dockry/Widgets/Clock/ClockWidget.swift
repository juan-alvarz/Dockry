import AppKit
import DockryCore
import SwiftUI

/// The time. Clicking it opens the Clock app. In a dock on the side of the screen the time
/// sits above the AM/PM, so it stays readable in a narrow tile.
struct ClockWidget: View {
    static let widget = DockWidget(info: WidgetKind.clock.info) {
        AnyView(TimelineView(.everyMinute) { ClockWidget(date: $0.date) })
    }

    let date: Date
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let u = metrics.unit
        Button(action: openClock) {
            Group {
                if metrics.axis == .vertical {
                    VStack(spacing: 0) {
                        Text(Self.timeFormatter.string(from: date))
                            .font(.system(size: 14 * u, weight: .semibold, design: .rounded))
                        if Self.usesAMPM {
                            Text(Self.amPMFormatter.string(from: date))
                                .font(.system(size: 9 * u, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: metrics.iconSize, height: metrics.iconSize)
                } else {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.system(size: 15 * u, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10 * u)
                        .frame(minWidth: 72 * u, minHeight: metrics.iconSize)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetTile()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open Clock")
    }

    /// Whether the user's locale shows a 12-hour clock.
    private static let usesAMPM = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") == true

    /// The time without AM/PM, which goes on its own line: "5:42", or "17:42" on a 24-hour clock.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = usesAMPM ? "h:mm" : "HH:mm"
        return formatter
    }()

    private static let amPMFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }()

    private func openClock() {
        if let clock = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.clock") {
            NSWorkspace.shared.openApplication(at: clock, configuration: NSWorkspace.OpenConfiguration())
        } else if let settings = URL(string: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension") {
            NSWorkspace.shared.open(settings)
        }
    }
}
