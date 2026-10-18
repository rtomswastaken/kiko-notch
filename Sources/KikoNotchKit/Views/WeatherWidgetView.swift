import SwiftUI

/// Weather widget in expanded island with condition icons and forecast.
/// Implements WX-003.
public struct WeatherWidgetView: View {
    @ObservedObject public var weatherService: WeatherService
    
    public init(weatherService: WeatherService? = nil) {
        self.weatherService = weatherService ?? WeatherService.shared
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let weather = weatherService.currentWeather {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: weather.conditionIcon)
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(weather.cityName)
                                .font(.system(size: 13, weight: .bold))
                            
                            if weather.isOffline {
                                Text("Offline")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.orange.opacity(0.3)))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text(weather.conditionDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(weatherService.formattedTemperature(weather.currentTempCelsius))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        
                        Text("H: \(weatherService.formattedTemperature(weather.maxTempCelsius))  L: \(weatherService.formattedTemperature(weather.minTempCelsius))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Hourly Forecast
                if !weather.hourly.isEmpty {
                    Divider().opacity(0.3)
                    
                    HStack(spacing: 12) {
                        ForEach(weather.hourly) { hour in
                            VStack(spacing: 4) {
                                Text(hour.timeString)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: weatherIconForCode(hour.weatherCode))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text(weatherService.formattedTemperature(hour.temperature))
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching weather data...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private func weatherIconForCode(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...65: return "cloud.rain.fill"
        case 71...77, 85, 86: return "snowflake"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
