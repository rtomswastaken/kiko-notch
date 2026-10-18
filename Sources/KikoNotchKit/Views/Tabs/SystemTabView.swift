import SwiftUI
import AppKit
import Combine

/// Dedicated System Status, Telemetry & Hardware Control Tab View
public struct SystemTabView: View {
    @ObservedObject public var metricsService = SystemMetricsService.shared
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
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("System & Telemetry")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    if metricsService.isMonitoring {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                }
                .padding(.horizontal, 4)
                
                // MARK: - Telemetry Metrics Dashboard
                
                // 1. CPU Utilization & Sparkline Card
                cpuMetricsCard
                
                // 2. RAM Usage & Memory Pressure Card
                memoryMetricsCard
                
                // 3. Storage Capacity Card
                storageMetricsCard
                
                // 4. Network Throughput Card
                networkThroughputCard
                
                // 5. Hardware & GPU Specifications Card
                hardwareSpecsCard
                
                // MARK: - Hardware Controls & Peripherals
                
                // 6. Battery & Power Card
                batteryCard
                
                // 7. Hardware Sliders: Brightness, Backlight, Audio
                hardwareSlidersCard
                
                // 8. Bluetooth Peripherals Card
                bluetoothCard
                
                // 9. Active Browser Downloads (if any)
                downloadsCard
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .onAppear {
            metricsService.startMonitoring(consumerID: "SystemTabView")
        }
        .onDisappear {
            metricsService.stopMonitoring(consumerID: "SystemTabView")
        }
    }
    
    // MARK: - CPU Card
    
    private var cpuMetricsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Label("CPU Utilization", systemImage: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                if let cpu = metricsService.currentSnapshot.cpu.value {
                    Text(String(format: "%.1f%% · %d Cores", cpu.totalUsagePercentage, cpu.coreCount))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                } else {
                    Text("Sampling...")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            // Historical Sparkline Graph
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.02))
                    .frame(height: 38)
                
                if metricsService.cpuHistory.count >= 2 {
                    SparklineView(data: metricsService.cpuHistory, maxValue: 100.0, lineColor: .blue)
                        .frame(height: 34)
                        .padding(.horizontal, 4)
                } else {
                    HStack {
                        Spacer()
                        Text("Gathering history...")
                            .font(.system(size: 9))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.6))
                        Spacer()
                    }
                    .frame(height: 38)
                }
            }
            
            // User vs System breakdown
            if let cpu = metricsService.currentSnapshot.cpu.value {
                HStack {
                    Text(String(format: "User: %.1f%%", cpu.userPercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text(String(format: "System: %.1f%%", cpu.systemPercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text(String(format: "Idle: %.1f%%", cpu.idlePercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Memory Card
    
    private var memoryMetricsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Memory (RAM)", systemImage: "memorychip")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                if let mem = metricsService.currentSnapshot.memory.value {
                    HStack(spacing: 4) {
                        Text("\(mem.formattedUsed) / \(mem.formattedTotal)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        // Pressure level badge
                        Text(mem.pressureLevel.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(pressureBadgeColor(mem.pressureLevel).opacity(0.2))
                            .foregroundColor(pressureBadgeColor(mem.pressureLevel))
                            .cornerRadius(4)
                    }
                } else {
                    Text("Sampling...")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            if let mem = metricsService.currentSnapshot.memory.value {
                ProgressView(value: mem.usagePercentage, total: 100.0)
                    .tint(pressureBadgeColor(mem.pressureLevel))
                
                HStack {
                    Text("Free: \(mem.formattedFree)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text("Swap: \(mem.formattedSwap)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Storage Card
    
    private var storageMetricsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Storage", systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                if let stor = metricsService.currentSnapshot.storage.value {
                    Text("\(stor.formattedUsed) used of \(stor.formattedTotal)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                } else {
                    Text("Sampling...")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            if let stor = metricsService.currentSnapshot.storage.value {
                ProgressView(value: stor.usedPercentage, total: 100.0)
                    .tint(.purple)
                
                HStack {
                    Text("Free: \(stor.formattedFree)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text(String(format: "%.1f%% Used", stor.usedPercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Network Card
    
    private var networkThroughputCard: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Network Throughput", systemImage: "network")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
            }
            
            if let net = metricsService.currentSnapshot.network.value {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                        Text(net.formattedDownloadSpeed)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                        Text(net.formattedUploadSpeed)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                }
                .padding(.top, 2)
            } else {
                Text("Sampling network interfaces...")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Hardware & GPU Specs Card
    
    private var hardwareSpecsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Hardware & Graphics", systemImage: "macbook.and.iphone")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
            }
            
            if let sys = metricsService.currentSnapshot.systemInfo.value {
                HStack {
                    Text(sys.modelName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    Text("Uptime: \(sys.formattedUptime)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                HStack {
                    Text(sys.osVersion)
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text("Thermal: \(sys.thermalStateDescription)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(thermalBadgeColor(sys.thermalState))
                }
            }
            
            Divider().opacity(0.2)
            
            if let gpu = metricsService.currentSnapshot.gpu.value {
                HStack {
                    Text(gpu.modelName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    Text(gpu.formattedMemory)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            // GPU utilization honest status
            HStack {
                Text("GPU Utilization")
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                if case .unavailable(let reason) = metricsService.currentSnapshot.gpuUtilization.status {
                    Text(reason)
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                        .lineLimit(1)
                } else if let util = metricsService.currentSnapshot.gpuUtilization.value {
                    Text(String(format: "%.1f%%", util))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Battery Card
    
    private var batteryCard: some View {
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
    }
    
    // MARK: - Hardware Sliders
    
    private var hardwareSlidersCard: some View {
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
    }
    
    // MARK: - Bluetooth Card
    
    private var bluetoothCard: some View {
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
    }
    
    // MARK: - Downloads Card
    
    @ViewBuilder
    private var downloadsCard: some View {
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
    
    // MARK: - Helpers
    
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
    
    private func pressureBadgeColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
    
    private func thermalBadgeColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}

// MARK: - Sparkline Vector View

public struct SparklineView: View {
    public let data: [Double]
    public let maxValue: Double
    public let lineColor: Color
    
    public init(data: [Double], maxValue: Double = 100.0, lineColor: Color = .blue) {
        self.data = data
        self.maxValue = max(maxValue, 1.0)
        self.lineColor = lineColor
    }
    
    public var body: some View {
        GeometryReader { geo in
            if data.count >= 2 {
                Path { path in
                    let step = geo.size.width / CGFloat(max(data.count - 1, 1))
                    for (index, value) in data.enumerated() {
                        let normalized = min(max(value / maxValue, 0.0), 1.0)
                        let y = geo.size.height * CGFloat(1.0 - normalized)
                        let x = CGFloat(index) * step
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else {
                EmptyView()
            }
        }
    }
}
