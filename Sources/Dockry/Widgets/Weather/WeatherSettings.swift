import DockryCore
import SwiftUI

/// Weather's part of Settings › Widgets: the temperature unit.
struct WeatherSettings: View {
    @AppStorage(WeatherMonitor.unitKey) private var saved: String?

    var body: some View {
        Section("Temperature") {
            Picker("Temperature", selection: unit) {
                Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.segmented)
        }
    }

    /// Celsius when nothing (or an older "system") is saved.
    private var unit: Binding<TemperatureUnit> {
        Binding(
            get: { TemperatureUnit(saved: saved) },
            set: { unit in
                saved = unit.rawValue
                WeatherMonitor.shared.unitChanged()
            })
    }
}
