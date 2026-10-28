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
    /// For CI, where nobody can answer the location prompt: "latitude,longitude".
    private static let testLocation = UserDefaults.standard.string(forKey: "weatherTestLocation")

    private let location = OneShotLocation()
    private var refreshTask: Task<Void, Never>?
    private var nextRefresh = Date.distantPast
    private var visibleWidgets = 0

    private init() {}

    func widgetAppeared() {
        visibleWidgets += 1
        guard refreshTask == nil else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                let wait = nextRefresh.timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                } else {
                    await refresh()
                    nextRefresh = Date().addingTimeInterval(Self.refreshInterval)
                }
            }
        }
    }

    func widgetDisappeared() {
        visibleWidgets -= 1
        guard visibleWidgets == 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func refresh() async {
        guard let coordinate = await currentCoordinate() else {
            state = .noLocation
            return
        }
        let url = Weather.requestURL(
            latitude: coordinate.latitude, longitude: coordinate.longitude,
            fahrenheit: Locale.current.measurementSystem == .us)
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            // Offline: keep showing the last reading.
            if case .loading = state { state = .unavailable }
            return
        }
        state = Weather(responseJSON: data).map(State.weather) ?? .unavailable
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
    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.delegate = self
    }

    func current() async -> CLLocation? {
        guard waiting == nil else { return nil }
        return await withCheckedContinuation { continuation in
            waiting = continuation
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
        waiting?.resume(returning: location)
        waiting = nil
    }

    // Core Location calls these on the main thread, where the manager was created.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard waiting != nil else { return }
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
