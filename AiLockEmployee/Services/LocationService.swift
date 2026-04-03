import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Returns the last cached location instantly — no GPS wait.
    func getLastKnown() -> CLLocation? {
        if let last = lastLocation { return last }
        return manager.location
    }

    /// Requests a fresh location with a 10-second timeout.
    /// Falls back to last known location if timeout expires.
    func getCurrentLocation() async -> CLLocation? {
        requestPermission()

        // If we already have a recent location (within 30s), return it
        if let last = lastLocation, Date().timeIntervalSince(last.timestamp) < 30 {
            return last
        }

        // Race GPS request against a 10s timeout
        let result: CLLocation? = await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
                    self.locationContinuation = continuation
                    self.manager.requestLocation()
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        if let result = result {
            return result
        }

        // Timeout — clean up pending continuation, return last known
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
        return getLastKnown()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            lastLocation = location
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }

}
