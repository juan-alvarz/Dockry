import AppKit
import DockryCore
import SwiftUI

/// Current conditions and temperature, with today's high and low. Clicking it opens the
/// Weather app. In a dock on the side of the screen it's just the symbol and temperature.
struct WeatherWidget: View {
    @ObservedObject private var monitor = WeatherMonitor.shared
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let u = metrics.unit
        Button(action: openWeather) {
            Group {
                switch monitor.state {
                case .weather(let weather):
                    conditions(weather)
                        .help(weather.summary)
                case .loading:
                    ProgressView().controlSize(.small)
                case .noLocation:
                    Image(systemName: "location.slash")
                        .font(.system(size: 18 * u))
                        .foregroundStyle(.secondary)
                        .help("Turn on Location Services for Dockry in System Settings › Privacy & Security to see the weather.")
                case .unavailable:
                    Image(systemName: "cloud")
                        .font(.system(size: 18 * u))
                        .foregroundStyle(.secondary)
                        .help("Couldn't get the weather. Dockry tries again in a few minutes.")
                }
            }
            .lineLimit(1)
            .padding(.horizontal, (metrics.axis == .vertical ? 2 : 10) * u)
            .frame(
                minWidth: metrics.iconSize, maxWidth: metrics.axis == .vertical ? metrics.iconSize : nil,
                minHeight: metrics.iconSize)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12 * u, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Fetch only while the widget is on screen.
        .onAppear { monitor.widgetAppeared() }
        .onDisappear { monitor.widgetDisappeared() }
    }

    @ViewBuilder private func conditions(_ weather: Weather) -> some View {
        let u = metrics.unit
        let temperature = Text("\(Int(weather.temperature.rounded()))°")
        let symbol = Image(systemName: weather.symbolName).symbolRenderingMode(.multicolor)
        if metrics.axis == .vertical {
            VStack(spacing: 1 * u) {
                symbol.font(.system(size: 16 * u))
                temperature.font(.system(size: 12 * u, weight: .semibold, design: .rounded))
            }
        } else {
            HStack(spacing: 6 * u) {
                symbol.font(.system(size: 20 * u))
                VStack(alignment: .leading, spacing: 0) {
                    temperature.font(.system(size: 17 * u, weight: .semibold, design: .rounded))
                    Text("H\(Int(weather.high.rounded()))° L\(Int(weather.low.rounded()))°")
                        .font(.system(size: 9 * u, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func openWeather() {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.weather") {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
