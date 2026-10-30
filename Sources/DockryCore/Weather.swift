import Foundation

/// Which unit the weather widget shows temperatures in.
public enum TemperatureUnit: String, CaseIterable {
    /// The Temperature setting in System Settings › General › Language & Region.
    case system
    case celsius
    case fahrenheit

    /// `systemSetting` is the Mac's `AppleTemperatureUnit` ("Celsius" or "Fahrenheit"), if
    /// set; without it, the region decides.
    public func usesFahrenheit(systemSetting: String?, regionUsesUS: Bool) -> Bool {
        switch self {
        case .celsius: false
        case .fahrenheit: true
        case .system: systemSetting.map { $0 == "Fahrenheit" } ?? regionUsesUS
        }
    }
}

/// Today's weather from Open-Meteo (open-meteo.com), which needs no API key.
public struct Weather: Equatable {
    public let temperature: Double
    public let high: Double
    public let low: Double
    /// WMO weather interpretation code, as Open-Meteo reports it.
    public let code: Int
    public let isDay: Bool

    public init(temperature: Double, high: Double, low: Double, code: Int, isDay: Bool) {
        self.temperature = temperature
        self.high = high
        self.low = low
        self.code = code
        self.isDay = isDay
    }

    public static func requestURL(latitude: Double, longitude: Double, fahrenheit: Bool) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
        ]
        return components.url!
    }

    /// Reads the answer to `requestURL`.
    public init?(responseJSON data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = object["current"] as? [String: Any],
              let daily = object["daily"] as? [String: Any],
              let temperature = (current["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (current["weather_code"] as? NSNumber)?.intValue,
              let high = (daily["temperature_2m_max"] as? [NSNumber])?.first?.doubleValue,
              let low = (daily["temperature_2m_min"] as? [NSNumber])?.first?.doubleValue
        else { return nil }
        let isDay = (current["is_day"] as? NSNumber)?.boolValue ?? true
        self.init(temperature: temperature, high: high, low: low, code: code, isDay: isDay)
    }

    /// The SF Symbol for the conditions, drawn in its multicolor style.
    public var symbolName: String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55: "cloud.drizzle.fill"
        case 56, 57, 66, 67: "cloud.sleet.fill"
        case 61, 63, 80, 81: "cloud.rain.fill"
        case 65, 82: "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "thermometer.medium"
        }
    }

    public var summary: String {
        switch code {
        case 0: "Clear"
        case 1: "Mostly clear"
        case 2: "Partly cloudy"
        case 3: "Cloudy"
        case 45, 48: "Fog"
        case 51, 53, 55: "Drizzle"
        case 56, 57: "Freezing drizzle"
        case 61, 63, 80, 81: "Rain"
        case 65, 82: "Heavy rain"
        case 66, 67: "Freezing rain"
        case 71, 73, 75, 77, 85, 86: "Snow"
        case 95: "Thunderstorm"
        case 96, 99: "Thunderstorm with hail"
        default: "Weather"
        }
    }
}
