import XCTest
@testable import KikoNotchKit

final class WeatherTests: XCTestCase {
    
    // MARK: - Weather Model & Icon Mapping Tests (WX-001, WX-003)
    
    func testWeatherSnapshotPropertiesAndConditionMapping() {
        let snapshot = WeatherSnapshot(
            cityName: "San Francisco",
            currentTempCelsius: 18.5,
            weatherCode: 0,
            minTempCelsius: 12.0,
            maxTempCelsius: 22.0,
            precipitationProbability: 10,
            hourly: [
                HourlyForecastItem(timeString: "14:00", temperature: 19.0, weatherCode: 0, precipitationProbability: 5),
                HourlyForecastItem(timeString: "15:00", temperature: 20.0, weatherCode: 1, precipitationProbability: 10)
            ],
            isOffline: false
        )
        
        XCTAssertEqual(snapshot.cityName, "San Francisco")
        XCTAssertEqual(snapshot.conditionDescription, "Clear")
        XCTAssertEqual(snapshot.conditionIcon, "sun.max.fill")
        XCTAssertEqual(snapshot.hourly.count, 2)
        XCTAssertFalse(snapshot.isOffline)
    }
    
    func testWeatherConditionCodes() {
        let rainSnapshot = WeatherSnapshot(
            cityName: "London",
            currentTempCelsius: 11.0,
            weatherCode: 61,
            minTempCelsius: 9.0,
            maxTempCelsius: 14.0,
            precipitationProbability: 80
        )
        XCTAssertEqual(rainSnapshot.conditionDescription, "Rain")
        XCTAssertEqual(rainSnapshot.conditionIcon, "cloud.rain.fill")
        
        let snowSnapshot = WeatherSnapshot(
            cityName: "Oslo",
            currentTempCelsius: -2.0,
            weatherCode: 71,
            minTempCelsius: -5.0,
            maxTempCelsius: 0.0,
            precipitationProbability: 40
        )
        XCTAssertEqual(snowSnapshot.conditionDescription, "Snow")
        XCTAssertEqual(snowSnapshot.conditionIcon, "snowflake")
    }
    
    // MARK: - Temperature Formatting & Units (WX-004)
    
    @MainActor
    func testTemperatureUnitConversion() {
        let service = WeatherService()
        
        service.unit = .celsius
        XCTAssertEqual(service.formattedTemperature(20.0), "20°C")
        XCTAssertEqual(service.formattedTemperature(0.0), "0°C")
        XCTAssertEqual(service.formattedTemperature(-5.0), "-5°C")
        
        service.unit = .fahrenheit
        // 20°C = (20 * 9/5) + 32 = 68°F
        XCTAssertEqual(service.formattedTemperature(20.0), "68°F")
        // 0°C = 32°F
        XCTAssertEqual(service.formattedTemperature(0.0), "32°F")
    }
    
    // MARK: - Location Manager Tests (WX-002)
    
    func testLocationCoordinatesAndManualFallback() {
        let locManager = LocationManager.shared
        
        let customCoord = LocationCoordinate(latitude: 48.8566, longitude: 2.3522, cityName: "Paris")
        locManager.setManualLocation(customCoord)
        
        XCTAssertTrue(locManager.useManualLocation)
        XCTAssertEqual(locManager.currentLocation.cityName, "Paris")
        XCTAssertEqual(locManager.currentLocation.latitude, 48.8566, accuracy: 0.001)
        XCTAssertEqual(locManager.currentLocation.longitude, 2.3522, accuracy: 0.001)
    }
}
