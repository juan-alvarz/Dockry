import DockryCore
import SwiftUI

/// Weather's part of Settings › Widgets: the temperature unit.
struct WeatherSettings: View {
    @AppStorage(WeatherMonitor.unitKey) private var unit = TemperatureUnit.system

    var body: some View {
        Section("Temperature") {
            Picker("Temperature", selection: $unit) {
                // Which unit System is, as the Weather app shows it: macOS's, not Weather's own.
                Text("System (\(WeatherMonitor.usesFahrenheit(.system) ? "°F" : "°C"))").tag(TemperatureUnit.system)
                Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.segmented)
            .onChange(of: unit) { _, _ in WeatherMonitor.shared.unitChanged() }
            Text("System uses macOS’s Temperature setting in System Settings › General › Language & Region, which can differ from the Weather app’s own.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
