import Foundation
import CoreLocation
import Combine

public struct LocationCoordinate: Sendable, Equatable, Codable {
    public let latitude: Double
    public let longitude: Double
    public let cityName: String
    
    public init(latitude: Double, longitude: Double, cityName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
    }
    
    public static let sanFrancisco = LocationCoordinate(latitude: 37.7749, longitude: -122.4194, cityName: "San Francisco")
    public static let newYork = LocationCoordinate(latitude: 40.7128, longitude: -74.0060, cityName: "New York")
    public static let london = LocationCoordinate(latitude: 51.5074, longitude: -0.1278, cityName: "London")
    public static let tokyo = LocationCoordinate(latitude: 35.6762, longitude: 139.6503, cityName: "Tokyo")
}

/// Manages GPS location via CoreLocation and manual fallback coordinates.
/// Implements WX-002.
public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, @unchecked Sendable {
    public static let shared = LocationManager()
    
    @Published public private(set) var currentLocation: LocationCoordinate
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var useManualLocation: Bool {
        didSet {
            UserDefaults.standard.set(useManualLocation, forKey: "kiko.weather.useManualLocation")
        }
    }
    
    private let clManager = CLLocationManager()
    private let lock = NSLock()
    
    public override init() {
        let manual = UserDefaults.standard.bool(forKey: "kiko.weather.useManualLocation")
        self.useManualLocation = manual
        
        if let data = UserDefaults.standard.data(forKey: "kiko.weather.manualLocation"),
           let saved = try? JSONDecoder().decode(LocationCoordinate.self, from: data) {
            self.currentLocation = saved
        } else {
            self.currentLocation = .sanFrancisco
        }
        
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    public func requestLocation() {
        guard !useManualLocation else { return }
        
        #if os(macOS)
        let status = clManager.authorizationStatus
        self.authorizationStatus = status
        
        if status == .authorizedAlways || status == .authorized {
            clManager.startUpdatingLocation()
        } else if status == .notDetermined {
            clManager.requestAlwaysAuthorization()
        }
        #endif
    }
    
    public func setManualLocation(_ coord: LocationCoordinate) {
        lock.lock()
        defer { lock.unlock() }
        
        self.currentLocation = coord
        self.useManualLocation = true
        if let data = try? JSONEncoder().encode(coord) {
            UserDefaults.standard.set(data, forKey: "kiko.weather.manualLocation")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !useManualLocation else { return }
        manager.stopUpdatingLocation()
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let cityName = placemarks?.first?.locality ?? placemarks?.first?.name ?? "Current Location"
            DispatchQueue.main.async {
                self?.currentLocation = LocationCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    cityName: cityName
                )
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fallback remains active
        NSLog("[LocationManager] Location update failed: \(error.localizedDescription)")
    }
}
