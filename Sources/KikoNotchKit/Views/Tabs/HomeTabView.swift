import SwiftUI
import AppKit

/// Home tab dashboard presenting date, battery, system glance, active media, and quick widgets
public struct HomeTabView: View {
    @ObservedObject public var batteryMonitor = BatteryMonitor.shared
    @ObservedObject public var calendarService = CalendarService.shared
    @ObservedObject public var mediaController = MediaController.shared
    @ObservedObject public var weatherService = WeatherService.shared
    @ObservedObject public var notificationManager = NotificationManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var navigation = IslandNavigationModel.shared
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        return df
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Top Row: Date Greeting & Battery Badge
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: Date()).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                        
                        Text("Today's Overview")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Battery & Power Status
                    HStack(spacing: 6) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 12))
                            .foregroundColor(batteryMonitor.currentState.isCharging ? .green : (batteryMonitor.currentState.percentage < 20 ? .red : .primary))
                        
                        Text("\(batteryMonitor.currentState.percentage)%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                
                // Active Media Card (or Now Playing teaser)
                if mediaController.currentMedia.isPlaying || !mediaController.currentMedia.title.isEmpty {
                    Button(action: {
                        withAnimation { navigation.selectTab(.nowPlaying) }
                    }) {
                        HStack(spacing: 10) {
                            if let artwork = mediaController.currentMedia.artworkImage {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 38, height: 38)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mediaController.currentMedia.title.isEmpty ? "No Track" : mediaController.currentMedia.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .lineLimit(1)
                                
                                Text(mediaController.currentMedia.artist.isEmpty ? "Apple Music / Spotify" : mediaController.currentMedia.artist)
                                    .font(.system(size: 10))
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                mediaController.togglePlayPause()
                            }) {
                                Image(systemName: mediaController.currentMedia.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Calendar / Agenda Glance
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text("UPCOMING")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        if let firstEvent = calendarService.events.first {
                            Text(firstEvent.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.primaryTextColor)
                                .lineLimit(1)
                            
                            if let countdown = calendarService.nextEventCountdown {
                                Text(countdown)
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                            }
                        } else {
                            Text("No events scheduled")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    
                    // Weather Glance
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("WEATHER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        if let weather = weatherService.currentWeather {
                            Text("\(Int(round(weather.currentTempCelsius)))°C · \(weather.conditionDescription)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.primaryTextColor)
                                .lineLimit(1)
                            
                            Text(weather.cityName)
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.secondaryTextColor)
                                .lineLimit(1)
                        } else {
                            Text("Weather updating...")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                
                // Quick Action Tiles
                HStack(spacing: 8) {
                    quickActionTile(title: "File Shelf", icon: "tray.and.arrow.down.fill") {
                        navigation.selectTab(.fileShelf)
                    }
                    quickActionTile(title: "AI Usage", icon: "sparkles") {
                        navigation.selectTab(.aiUsage)
                    }
                    quickActionTile(title: "System", icon: "slider.horizontal.3") {
                        navigation.selectTab(.system)
                    }
                    quickActionTile(title: "Settings", icon: "gearshape.fill") {
                        navigation.selectTab(.settings)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
    
    @ViewBuilder
    private func quickActionTile(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation { action() }
        }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var batteryIcon: String {
        let pct = batteryMonitor.currentState.percentage
        if batteryMonitor.currentState.isCharging {
            return "battery.100.bolt"
        }
        if pct > 80 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 20 { return "battery.50" }
        return "battery.25"
    }
}
