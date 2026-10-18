import SwiftUI

/// Transient HUD indicator in the Island for system events (Volume, Brightness, Audio, Battery, Bluetooth).
/// Implements SYS-001, SYS-002, SYS-003, SYS-004, and SYS-005.
public struct SystemHUDView: View {
    public let event: SystemHUDEvent
    
    public init(event: SystemHUDEvent) {
        self.event = event
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            switch event {
            case .volume(let level, let isMuted):
                volumeContent(level: level, isMuted: isMuted)
            case .brightness(let level):
                sliderContent(icon: "sun.max.fill", title: "Brightness", level: level)
            case .keyboardBacklight(let level):
                sliderContent(icon: "keyboard.fill", title: "Backlight", level: level)
            case .audioOutputChanged(let deviceName):
                routeContent(icon: "headphones", name: deviceName)
            case .batteryStatus(let percentage, let isCharging, let timeRemaining):
                batteryContent(percentage: percentage, isCharging: isCharging, timeRemaining: timeRemaining)
            case .bluetoothDevice(let name, let isConnected, let batteryLevel):
                bluetoothContent(name: name, isConnected: isConnected, batteryLevel: batteryLevel)
            case .downloadProgress(let filename, let progress, let isComplete):
                downloadContent(filename: filename, progress: progress, isComplete: isComplete)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .foregroundColor(.white)
        .frame(minWidth: 220)
    }
    
    @ViewBuilder
    private func volumeContent(level: Float, isMuted: Bool) -> some View {
        Image(systemName: isMuted ? "speaker.slash.fill" : (level > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isMuted ? .red : .white)
            .accessibilityLabel(isMuted ? "Muted" : "Volume")
        
        ProgressBar(value: Double(level), isDimmed: isMuted)
        
        Text("\(isMuted ? 0 : Int(level * 100))%")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: 36, alignment: .trailing)
    }
    
    @ViewBuilder
    private func sliderContent(icon: String, title: String, level: Float) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .accessibilityLabel(title)
        
        ProgressBar(value: Double(level))
        
        Text("\(Int(level * 100))%")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: 36, alignment: .trailing)
    }
    
    @ViewBuilder
    private func routeContent(icon: String, name: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
        
        VStack(alignment: .leading, spacing: 2) {
            Text("Audio Output")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private func batteryContent(percentage: Int, isCharging: Bool, timeRemaining: Int?) -> some View {
        Image(systemName: isCharging ? "battery.100.bolt" : (percentage <= 20 ? "battery.25" : "battery.100"))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(percentage <= 20 && !isCharging ? .red : (isCharging ? .green : .white))
        
        VStack(alignment: .leading, spacing: 2) {
            Text(isCharging ? "Charging" : (percentage <= 20 ? "Low Battery" : "Battery"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(percentage)%")
                .font(.system(size: 13, weight: .bold))
        }
        
        if let mins = timeRemaining {
            Spacer()
            Text("\(mins / 60)h \(mins % 60)m")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func bluetoothContent(name: String, isConnected: Bool, batteryLevel: Int?) -> some View {
        Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "slash.circle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isConnected ? .blue : .gray)
        
        VStack(alignment: .leading, spacing: 2) {
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        
        if let bat = batteryLevel {
            Spacer()
            Text("\(bat)%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func downloadContent(filename: String, progress: Double, isComplete: Bool) -> some View {
        Image(systemName: isComplete ? "checkmark.circle.fill" : "arrow.down.circle.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isComplete ? .green : .blue)
        
        VStack(alignment: .leading, spacing: 2) {
            Text(isComplete ? "Download Finished" : "Downloading")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(filename)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        
        if !isComplete {
            ProgressBar(value: progress)
                .frame(width: 60)
        }
    }
}

private struct ProgressBar: View {
    var value: Double
    var isDimmed: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                
                Capsule()
                    .fill(isDimmed ? Color.gray : Color.white)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))), height: 6)
            }
        }
        .frame(height: 6)
    }
}
