import SwiftUI

/// Settings view for weather preferences and locations.
/// Implements WX-004.
public struct WeatherSettingsView: View {
    @ObservedObject public var weatherService: WeatherService
    @ObservedObject public var locationManager: LocationManager
    @State private var cityNameInput: String = ""
    @State private var latInput: String = ""
    @State private var lonInput: String = ""
    
    public init(
        weatherService: WeatherService? = nil,
        locationManager: LocationManager? = nil
    ) {
        self.weatherService = weatherService ?? WeatherService.shared
        self.locationManager = locationManager ?? LocationManager.shared
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Temperature Unit")) {
                Picker("Unit", selection: $weatherService.unit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)").tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Location Source")) {
                Toggle("Use Manual City Location", isOn: $locationManager.useManualLocation)
                
                if locationManager.useManualLocation {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("City Name", text: $cityNameInput)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            TextField("Latitude (e.g. 37.77)", text: $latInput)
                                .textFieldStyle(.roundedBorder)
                            TextField("Longitude (e.g. -122.41)", text: $lonInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button("Apply Custom Coordinates") {
                            if let lat = Double(latInput), let lon = Double(lonInput) {
                                let name = cityNameInput.isEmpty ? "Custom Location" : cityNameInput
                                locationManager.setManualLocation(LocationCoordinate(latitude: lat, longitude: lon, cityName: name))
                                Task { await weatherService.refreshWeather() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Text("Current Detected:")
                        Spacer()
                        Text(locationManager.currentLocation.cityName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Sync & Offline Cache")) {
                Button(action: {
                    Task { await weatherService.refreshWeather() }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Weather Now")
                    }
                }
                
                if let weather = weatherService.currentWeather {
                    HStack {
                        Text("Last Updated:")
                        Spacer()
                        Text(weather.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            cityNameInput = locationManager.currentLocation.cityName
            latInput = String(locationManager.currentLocation.latitude)
            lonInput = String(locationManager.currentLocation.longitude)
        }
    }
}
