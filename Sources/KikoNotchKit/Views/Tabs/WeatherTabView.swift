import SwiftUI
import AppKit

/// Dedicated Weather Conditions & Forecast Tab View
public struct WeatherTabView: View {
    @ObservedObject public var weatherService = WeatherService.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Header Bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                        Text("Weather & Forecast")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task { await weatherService.refreshWeather() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text("Update")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                if let weather = weatherService.currentWeather {
                    // Main Hero Condition Card
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: weather.conditionIcon)
                            .font(.system(size: 34))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(weather.cityName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                if weather.isOffline {
                                    Text("Cached")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.orange.opacity(0.16)))
                                }
                            }
                            
                            Text(weather.conditionDescription)
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(weatherService.formattedTemperature(weather.currentTempCelsius))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text("H: \(weatherService.formattedTemperature(weather.maxTempCelsius))  L: \(weatherService.formattedTemperature(weather.minTempCelsius))")
                                .font(.system(size: 9))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                    
                    // Hourly Forecast Strip
                    if !weather.hourly.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HOURLY FORECAST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(weather.hourly) { hour in
                                        hourlyCard(hour: hour)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                    }
                    
                    // Daily Forecast List
                    if !weather.daily.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("UPCOMING DAYS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            ForEach(weather.daily) { day in
                                dailyRow(day: day)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                    }
                } else {
                    // Loading or Permission State
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Acquiring Weather Forecast...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
    
    @ViewBuilder
    private func hourlyCard(hour: HourlyForecastItem) -> some View {
        VStack(spacing: 4) {
            Text(hour.timeString)
                .font(.system(size: 9))
                .foregroundColor(themeManager.secondaryTextColor)
            Image(systemName: hour.iconName)
                .font(.system(size: 12))
                .foregroundColor(.yellow)
            Text(weatherService.formattedTemperature(hour.tempCelsius))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.primaryTextColor)
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private func dailyRow(day: DailyForecastItem) -> some View {
        HStack {
            Text(day.dayOfWeek)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeManager.primaryTextColor)
                .frame(width: 44, alignment: .leading)
            
            Image(systemName: day.iconName)
                .font(.system(size: 11))
                .foregroundColor(.yellow)
                .frame(width: 20)
            
            Spacer()
            
            Text("L: \(weatherService.formattedTemperature(day.minTempCelsius))")
                .font(.system(size: 10))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text("H: \(weatherService.formattedTemperature(day.maxTempCelsius))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeManager.primaryTextColor)
        }
        .padding(.vertical, 2)
    }
}
