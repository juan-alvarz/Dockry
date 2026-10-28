import DockryCore
import SwiftUI

struct WidgetView: View {
    let kind: WidgetKind

    var body: some View {
        TimelineView(.everyMinute) { context in
            switch kind {
            case .clock: ClockWidget(date: context.date)
            case .date: DateWidget(date: context.date)
            }
        }
    }
}

private struct ClockWidget: View {
    let date: Date

    var body: some View {
        Text(date, format: .dateTime.hour().minute())
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .frame(minWidth: 72, minHeight: 48)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A calendar-style tile: month on top, day of the month below.
private struct DateWidget: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.month(.abbreviated))
                .textCase(.uppercase)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.red)
            Text(date, format: .dateTime.day())
                .font(.system(size: 22, weight: .medium, design: .rounded))
        }
        .frame(width: 48, height: 48)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
