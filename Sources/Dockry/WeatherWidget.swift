import DockryCore
import SwiftUI

/// Current conditions and temperature, with today's high and low.
struct WeatherWidget: View {
    @ObservedObject private var monitor = WeatherMonitor.shared

    var body: some View {
        Group {
            switch monitor.state {
            case .weather(let weather):
                HStack(spacing: 6) {
                    Image(systemName: weather.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(weather.temperature.rounded()))°")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text("H\(Int(weather.high.rounded()))° L\(Int(weather.low.rounded()))°")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .help(weather.summary)
            case .loading:
                ProgressView().controlSize(.small)
            case .noLocation:
                Image(systemName: "location.slash")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .help("Turn on Location Services for Dockry in System Settings › Privacy & Security to see the weather.")
            case .unavailable:
                Image(systemName: "cloud")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .help("Couldn't get the weather. Dockry tries again in half an hour.")
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(minWidth: 48, minHeight: 48)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        // Fetch only while the widget is on screen.
        .onAppear { monitor.widgetAppeared() }
        .onDisappear { monitor.widgetDisappeared() }
    }
}
