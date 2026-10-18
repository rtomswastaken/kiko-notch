import Foundation
import Combine

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case celsius = "°C"
    case fahrenheit = "°F"
}

public struct HourlyForecastItem: Identifiable, Sendable, Codable, Equatable {
    public var id: String { timeString }
    public let timeString: String
    public let temperature: Double
    public let weatherCode: Int
    public let precipitationProbability: Int
    
    public init(timeString: String, temperature: Double, weatherCode: Int, precipitationProbability: Int) {
        self.timeString = timeString
        self.temperature = temperature
        self.weatherCode = weatherCode
        self.precipitationProbability = precipitationProbability
    }
}

public struct WeatherSnapshot: Sendable, Codable, Equatable {
    public let timestamp: Date
    public let cityName: String
    public let currentTempCelsius: Double
    public let weatherCode: Int
    public let minTempCelsius: Double
    public let maxTempCelsius: Double
    public let precipitationProbability: Int
    public let hourly: [HourlyForecastItem]
    public let isOffline: Bool
    
    public init(
        timestamp: Date = Date(),
        cityName: String,
        currentTempCelsius: Double,
        weatherCode: Int,
        minTempCelsius: Double,
        maxTempCelsius: Double,
        precipitationProbability: Int,
        hourly: [HourlyForecastItem] = [],
        isOffline: Bool = false
    ) {
        self.timestamp = timestamp
        self.cityName = cityName
        self.currentTempCelsius = currentTempCelsius
        self.weatherCode = weatherCode
        self.minTempCelsius = minTempCelsius
        self.maxTempCelsius = maxTempCelsius
        self.precipitationProbability = precipitationProbability
        self.hourly = hourly
        self.isOffline = isOffline
    }
    
    public var conditionDescription: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55, 61, 63, 65: return "Rain"
        case 71, 73, 75, 77, 85, 86: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Overcast"
        }
    }
    
    public var conditionIcon: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...65: return "cloud.rain.fill"
        case 71...77, 85, 86: return "snowflake"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

/// Weather service using Open-Meteo REST API with offline caching and unit conversion.
/// Implements WX-001, WX-003, WX-004, and ERR-001.
@MainActor
public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()
    
    @Published public private(set) var currentWeather: WeatherSnapshot?
    @Published public private(set) var isLoading: Bool = false
    @Published public var unit: TemperatureUnit {
        didSet {
            UserDefaults.standard.set(unit.rawValue, forKey: "kiko.weather.unit")
        }
    }
    
    private let urlSession: URLSession
    private let cacheKey = "kiko.weather.cache"
    
    public init(session: URLSession = .shared) {
        self.urlSession = session
        let storedUnit = UserDefaults.standard.string(forKey: "kiko.weather.unit")
            .flatMap { TemperatureUnit(rawValue: $0) } ?? .celsius
        self.unit = storedUnit
        
        loadCachedWeather()
    }
    
    public func formattedTemperature(_ celsius: Double) -> String {
        switch unit {
        case .celsius:
            return "\(Int(round(celsius)))°C"
        case .fahrenheit:
            let f = (celsius * 9.0 / 5.0) + 32.0
            return "\(Int(round(f)))°F"
        }
    }
    
    public func refreshWeather() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        let loc = LocationManager.shared.currentLocation
        let lat = loc.latitude
        let lon = loc.longitude
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code&hourly=temperature_2m,precipitation_probability,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto"
        
        guard let url = URL(string: urlStr) else { return }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                markAsOffline()
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any],
               let temp = current["temperature_2m"] as? Double,
               let code = current["weather_code"] as? Int,
               let daily = json["daily"] as? [String: Any] {
                
                let minTemps = daily["temperature_2m_min"] as? [Double] ?? [temp]
                let maxTemps = daily["temperature_2m_max"] as? [Double] ?? [temp]
                let rainProbs = daily["precipitation_probability_max"] as? [Int] ?? [0]
                
                var hourlyItems: [HourlyForecastItem] = []
                if let hourly = json["hourly"] as? [String: Any],
                   let hTimes = hourly["time"] as? [String],
                   let hTemps = hourly["temperature_2m"] as? [Double],
                   let hCodes = hourly["weather_code"] as? [Int],
                   let hRain = hourly["precipitation_probability"] as? [Int] {
                    
                    let count = min(6, hTimes.count, hTemps.count, hCodes.count, hRain.count)
                    for i in 0..<count {
                        let rawTime = hTimes[i]
                        let displayTime = rawTime.split(separator: "T").last.map { String($0) } ?? rawTime
                        hourlyItems.append(HourlyForecastItem(
                            timeString: displayTime,
                            temperature: hTemps[i],
                            weatherCode: hCodes[i],
                            precipitationProbability: hRain[i]
                        ))
                    }
                }
                
                let snapshot = WeatherSnapshot(
                    timestamp: Date(),
                    cityName: loc.cityName,
                    currentTempCelsius: temp,
                    weatherCode: code,
                    minTempCelsius: minTemps.first ?? temp,
                    maxTempCelsius: maxTemps.first ?? temp,
                    precipitationProbability: rainProbs.first ?? 0,
                    hourly: hourlyItems,
                    isOffline: false
                )
                
                self.currentWeather = snapshot
                saveCache(snapshot)
            }
        } catch {
            // Graceful degradation (ERR-001)
            markAsOffline()
        }
    }
    
    private func markAsOffline() {
        if let existing = currentWeather {
            self.currentWeather = WeatherSnapshot(
                timestamp: existing.timestamp,
                cityName: existing.cityName,
                currentTempCelsius: existing.currentTempCelsius,
                weatherCode: existing.weatherCode,
                minTempCelsius: existing.minTempCelsius,
                maxTempCelsius: existing.maxTempCelsius,
                precipitationProbability: existing.precipitationProbability,
                hourly: existing.hourly,
                isOffline: true
            )
        }
    }
    
    private func saveCache(_ snapshot: WeatherSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    private func loadCachedWeather() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let snapshot = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) {
            self.currentWeather = snapshot
        }
    }
}
