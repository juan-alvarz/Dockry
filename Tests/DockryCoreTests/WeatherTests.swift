import XCTest
@testable import DockryCore

final class WeatherTests: XCTestCase {
    func testReadsOpenMeteosAnswer() throws {
        let json = """
            {"latitude": 4.7, "current": {"time": "2026-10-28T08:00", "temperature_2m": 14.6, "weather_code": 2, "is_day": 0},
             "daily": {"time": ["2026-10-28"], "temperature_2m_max": [21.3], "temperature_2m_min": [9.8]}}
            """
        let weather = try XCTUnwrap(Weather(responseJSON: Data(json.utf8)))
        XCTAssertEqual(weather, Weather(temperature: 14.6, high: 21.3, low: 9.8, code: 2, isDay: false))
        XCTAssertEqual(weather.symbolName, "cloud.moon.fill")
        XCTAssertEqual(weather.summary, "Partly cloudy")
    }

    func testIncompleteAnswersGiveNothing() {
        XCTAssertNil(Weather(responseJSON: Data(#"{"current": {"temperature_2m": 1, "weather_code": 0}}"#.utf8)))
        XCTAssertNil(Weather(responseJSON: Data(#"{"error": true, "reason": "Latitude must be in range"}"#.utf8)))
    }

    func testDayAndNightSymbols() {
        XCTAssertEqual(Weather(temperature: 0, high: 0, low: 0, code: 0, isDay: true).symbolName, "sun.max.fill")
        XCTAssertEqual(Weather(temperature: 0, high: 0, low: 0, code: 0, isDay: false).symbolName, "moon.stars.fill")
        XCTAssertEqual(Weather(temperature: 0, high: 0, low: 0, code: 95, isDay: true).symbolName, "cloud.bolt.rain.fill")
    }

    func testRequestAsksForTheRightUnits() throws {
        let url = Weather.requestURL(latitude: 4.711, longitude: -74.072, fahrenheit: true)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertTrue(items.contains(URLQueryItem(name: "temperature_unit", value: "fahrenheit")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "latitude", value: "4.711")))
    }

    func testTheTemperatureUnitChoice() {
        XCTAssertTrue(TemperatureUnit.system.usesFahrenheit(systemSetting: "Fahrenheit", regionUsesUS: false))
        XCTAssertFalse(TemperatureUnit.system.usesFahrenheit(systemSetting: "Celsius", regionUsesUS: true))
        XCTAssertTrue(TemperatureUnit.system.usesFahrenheit(systemSetting: nil, regionUsesUS: true))
        XCTAssertFalse(TemperatureUnit.celsius.usesFahrenheit(systemSetting: "Fahrenheit", regionUsesUS: true))
        XCTAssertTrue(TemperatureUnit.fahrenheit.usesFahrenheit(systemSetting: "Celsius", regionUsesUS: false))
    }
}
