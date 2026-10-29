import DockryCore
import SwiftUI

/// A calendar-style tile: month on top, day of the month below. Clicking it shows the month.
struct DateWidget: View {
    static let widget = DockWidget(info: WidgetKind.date.info) {
        AnyView(TimelineView(.everyMinute) { DateWidget(date: $0.date) })
    }

    let date: Date
    @Environment(\.dockMetrics) private var metrics
    @State private var showsCalendar = false

    var body: some View {
        let u = metrics.unit
        Button { showsCalendar.toggle() } label: {
            VStack(spacing: 0) {
                Text(date, format: .dateTime.month(.abbreviated))
                    .textCase(.uppercase)
                    .font(.system(size: 9 * u, weight: .bold))
                    .foregroundStyle(.red)
                Text(date, format: .dateTime.day())
                    .font(.system(size: 22 * u, weight: .medium, design: .rounded))
            }
            .frame(width: metrics.iconSize, height: metrics.iconSize)
            .widgetTile()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dockPopover(isPresented: $showsCalendar) { CalendarPopover() }
        .onAppear { ScreenshotHook.openPopoverIfRequested("calendar") { showsCalendar = true } }
    }
}
