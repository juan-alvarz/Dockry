import DockryCore
import SwiftUI

/// Weather's part of Settings › Widgets: the temperature unit.
struct WeatherSettings: View {
    @AppStorage(WeatherMonitor.unitKey) private var unit = TemperatureUnit.system

    var body: some View {
        Section("Temperature") {
            Picker("Temperature", selection: $unit) {
                Text("System").tag(TemperatureUnit.system)
                Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.segmented)
            .onChange(of: unit) { _, _ in WeatherMonitor.shared.unitChanged() }
            Text("System follows the Temperature setting in System Settings › General › Language & Region.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
