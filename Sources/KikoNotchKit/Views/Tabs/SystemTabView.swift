import SwiftUI
import AppKit
import Combine

/// Dedicated System Status & Hardware Control Tab View
public struct SystemTabView: View {
    @ObservedObject public var batteryMonitor = BatteryMonitor.shared
    @ObservedObject public var bluetoothMonitor = BluetoothMonitor.shared
    @ObservedObject public var brightnessMonitor = BrightnessHUDMonitor.shared
    @ObservedObject public var kbdMonitor = KeyboardBacklightMonitor.shared
    @ObservedObject public var audioHUD = AudioHUDMonitor.shared
    @ObservedObject public var downloadMonitor = DownloadMonitor.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("System Controls")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Battery & Power Card
                VStack(spacing: 8) {
                    HStack {
                        Label("Battery Status", systemImage: batteryIcon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Text("\(batteryMonitor.currentState.percentage)% · \(batteryMonitor.currentState.powerSource)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    
                    ProgressView(value: Double(batteryMonitor.currentState.percentage), total: 100.0)
                        .tint(batteryMonitor.currentState.isCharging ? .green : (batteryMonitor.currentState.percentage < 20 ? .red : .accentColor))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                
                // Hardware Sliders: Brightness & Audio
                VStack(spacing: 10) {
                    // Brightness Slider
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 16)
                        
                        Slider(value: Binding(
                            get: { Double(brightnessMonitor.currentBrightness) },
                            set: { brightnessMonitor.setSimulatedBrightness(Float($0)) }
                        ), in: 0.0...1.0)
                        
                        Text("\(Int(brightnessMonitor.currentBrightness * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 32, alignment: .trailing)
                    }
                    
                    // Keyboard Backlight Slider
                    HStack(spacing: 8) {
                        Image(systemName: "light.ribbon")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 16)
                        
                        Slider(value: Binding(
                            get: { Double(kbdMonitor.currentBacklight) },
                            set: { kbdMonitor.setSimulatedBacklight(Float($0)) }
                        ), in: 0.0...1.0)
                        
                        Text("\(Int(kbdMonitor.currentBacklight * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 32, alignment: .trailing)
                    }
                    
                    // Audio Volume Slider
                    HStack(spacing: 8) {
                        Image(systemName: audioHUD.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 16)
                        
                        Slider(value: Binding(
                            get: { Double(audioHUD.currentVolume) },
                            set: { audioHUD.setSimulatedVolume(Float($0), muted: audioHUD.isMuted) }
                        ), in: 0.0...1.0)
                        
                        Text("\(Int(audioHUD.currentVolume * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                
                // Bluetooth Peripherals Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Bluetooth Devices", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                    }
                    
                    if bluetoothMonitor.connectedDevices.isEmpty {
                        Text("No active Bluetooth peripherals connected")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(bluetoothMonitor.connectedDevices) { device in
                            HStack {
                                Image(systemName: peripheralIcon(for: device.name))
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                                Text(device.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if let battery = device.batteryLevel {
                                    Text("\(battery)%")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                
                // Active Browser Downloads (if any)
                if !downloadMonitor.activeDownloadsList.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Downloads Activity", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                        }
                        
                        ForEach(downloadMonitor.activeDownloadsList) { item in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(item.fileName)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.formattedSpeed)
                                        .font(.system(size: 9))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                ProgressView(value: item.progress)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
    
    private var batteryIcon: String {
        let pct = batteryMonitor.currentState.percentage
        if batteryMonitor.currentState.isCharging { return "battery.100.bolt" }
        if pct > 80 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 20 { return "battery.50" }
        return "battery.25"
    }
    
    private func peripheralIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") { return "airpodspro" }
        if lower.contains("mouse") { return "magicmouse.fill" }
        if lower.contains("keyboard") { return "keyboard.fill" }
        if lower.contains("trackpad") { return "hand.tap.fill" }
        return "headphones"
    }
}
