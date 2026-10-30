import CoreLocation
import DockryCore
import Foundation

/// Today's weather where the Mac is, refreshed every half hour while a weather widget is
/// showing. Shared, so switching profiles doesn't start new requests or lose the reading.
@MainActor
final class WeatherMonitor: ObservableObject {
    static let shared = WeatherMonitor()

    enum State: Equatable {
        case loading
        /// Location Services is off for Dockry, or the Mac couldn't tell where it is.
        case noLocation
        case unavailable
        case weather(Weather)
    }

    @Published private(set) var state = State.loading

    private static let refreshInterval: TimeInterval = 30 * 60
    private static let retryInterval: TimeInterval = 5 * 60
    /// For CI, where nobody can answer the location prompt: "latitude,longitude".
    private static let testLocation = UserDefaults.standard.string(forKey: "weatherTestLocation")

    private let location = OneShotLocation()
    private var refreshTask: Task<Void, Never>?
    private var nextRefresh = Date.distantPast
    private var visibleWidgets = 0

    private init() {
        // Turning location on in System Settings should show the weather right away.
        location.onAuthorizationChange = { [weak self] in self?.refreshNow() }
    }

    func widgetAppeared() {
        visibleWidgets += 1
        startRefreshing()
    }

    func widgetDisappeared() {
        visibleWidgets -= 1
        guard visibleWidgets == 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func startRefreshing() {
        guard refreshTask == nil else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                let wait = nextRefresh.timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                } else {
                    let interval = await refresh()
                    // A refresh cut short by the widget going away doesn't count.
                    if !Task.isCancelled { nextRefresh = Date().addingTimeInterval(interval) }
                }
            }
        }
    }

    private func refreshNow() {
        nextRefresh = .distantPast
        guard visibleWidgets > 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
        startRefreshing()
    }

    /// Returns how long to wait before the next refresh. After a failure the last reading
    /// stays on screen and the next try comes sooner.
    private func refresh() async -> TimeInterval {
        guard let coordinate = await currentCoordinate() else {
            if case .weather = state {} else { state = .noLocation }
            return Self.retryInterval
        }
        let url = Weather.requestURL(
            latitude: coordinate.latitude, longitude: coordinate.longitude, fahrenheit: Self.usesFahrenheit)
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let weather = Weather(responseJSON: data)
        else {
            if !Task.isCancelled, case .loading = state { state = .unavailable }
            return Self.retryInterval
        }
        state = .weather(weather)
        return Self.refreshInterval
    }

    /// The Temperature setting in System Settings › General › Language & Region.
    /// The unit chosen in Settings › Widgets › Weather; System follows the Temperature
    /// setting in System Settings › General › Language & Region.
    static let unitKey = "weatherTemperatureUnit"

    private static var usesFahrenheit: Bool {
        let unit = UserDefaults.standard.string(forKey: unitKey).flatMap(TemperatureUnit.init) ?? .system
        return unit.usesFahrenheit(
            systemSetting: UserDefaults.standard.string(forKey: "AppleTemperatureUnit"),
            regionUsesUS: Locale.current.measurementSystem == .us)
    }

    /// Fetches again in the unit just chosen.
    func unitChanged() {
        refreshNow()
    }

    private func currentCoordinate() async -> CLLocationCoordinate2D? {
        if let testLocation = Self.testLocation {
            let parts = testLocation.split(separator: ",").compactMap { Double($0) }
            return parts.count == 2 ? CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1]) : nil
        }
        return await location.current()?.coordinate
    }
}

/// Asks Core Location for one position, asking the user for permission the first time.
/// Weather only needs the town, so it asks for city-level accuracy.
@MainActor
private final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    var onAuthorizationChange: (() -> Void)?

    private let manager = CLLocationManager()
    /// Everyone waiting for the position being looked up; they all get the same answer.
    private var waiting: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.delegate = self
    }

    func current() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            guard waiting.count == 1 else { return }  // a lookup is already under way
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()  // continues in the authorization callback
            case .denied, .restricted:
                finish(with: nil)
            default:
                manager.requestLocation()
            }
        }
    }

    private func finish(with location: CLLocation?) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(returning: location) }
    }

    // Core Location calls these on the main thread, where the manager was created.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard !waiting.isEmpty else {
                onAuthorizationChange?()
                return
            }
            switch manager.authorizationStatus {
            case .notDetermined: break
            case .denied, .restricted: finish(with: nil)
            default: manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated { finish(with: locations.last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(with: nil) }
    }
}
