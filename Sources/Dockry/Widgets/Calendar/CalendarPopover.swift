import AppKit
import DockryCore
import SwiftUI

/// A month at a glance, from the date widget.
struct CalendarPopover: View {
    @State private var month = Date()
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .help("Previous month")
                Button("Today") { month = Date() }
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .help("Next month")
            }
            .buttonStyle(.borderless)

            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    // Not by symbol: "T" is both Tuesday and Thursday.
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                }
                let weeks = MonthGrid.weeks(containing: month, calendar: calendar)
                ForEach(weeks.indices, id: \.self) { week in
                    GridRow {
                        ForEach(0..<7, id: \.self) { weekday in
                            DayCell(date: weeks[week][weekday], calendar: calendar)
                        }
                    }
                }
            }

            Divider()
            Button("Open Calendar") {
                if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                    NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
                }
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(width: 250)
    }

    /// Short weekday names, starting on the user's first day of the week.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func step(_ months: Int) {
        month = calendar.date(byAdding: .month, value: months, to: month) ?? month
    }
}

private struct DayCell: View {
    let date: Date?
    let calendar: Calendar

    var body: some View {
        if let date {
            let isToday = calendar.isDateInToday(date)
            Text(date, format: .dateTime.day())
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 26, height: 26)
                .background(isToday ? Color.red : Color.clear, in: Circle())
                .frame(width: 30)
        } else {
            Color.clear.frame(width: 30, height: 26)
        }
    }
}
