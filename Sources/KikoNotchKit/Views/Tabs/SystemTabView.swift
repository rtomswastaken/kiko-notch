import SwiftUI
import AppKit
import Combine

public enum SystemTabSection: String, CaseIterable, Identifiable {
    case metrics = "Metrics"
    case controls = "Controls"
    
    public var id: String { rawValue }
}

/// Dedicated System Status & Hardware Control Tab View
public struct SystemTabView: View {
    @ObservedObject public var metricsService = SystemMetricsService.shared
    @ObservedObject public var batteryMonitor = BatteryMonitor.shared
    @ObservedObject public var bluetoothMonitor = BluetoothMonitor.shared
    @ObservedObject public var brightnessMonitor = BrightnessHUDMonitor.shared
    @ObservedObject public var kbdMonitor = KeyboardBacklightMonitor.shared
    @ObservedObject public var audioHUD = AudioHUDMonitor.shared
    @ObservedObject public var downloadMonitor = DownloadMonitor.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    @State private var activeSection: SystemTabSection = .metrics
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Section Picker & Header
                headerBar
                
                if activeSection == .metrics {
                    systemMetricsContent
                } else {
                    systemControlsContent
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .onAppear {
            metricsService.registerConsumer(id: "SystemTabView")
        }
        .onDisappear {
            metricsService.unregisterConsumer(id: "SystemTabView")
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            // Segmented Section Switcher
            HStack(spacing: 4) {
                ForEach(SystemTabSection.allCases) { section in
                    Button(action: { activeSection = section }) {
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: activeSection == section ? .semibold : .medium))
                            .foregroundColor(activeSection == section ? .white : themeManager.secondaryTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(activeSection == section ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            if activeSection == .metrics {
                // Sampling Interval Menu & Refresh
                HStack(spacing: 6) {
                    Menu {
                        ForEach(SamplingInterval.allCases) { interval in
                            Button(interval.displayName) {
                                metricsService.samplingInterval = interval
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(metricsService.isMonitoring ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            Text("\(Int(metricsService.samplingInterval.rawValue))s")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 46)
                    
                    Button(action: {
                        metricsService.sampleNow()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh metrics immediately")
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - System Metrics Content
    
    private var systemMetricsContent: some View {
        let snap = metricsService.snapshot
        
        return VStack(spacing: 10) {
            // CPU Utilization Card
            cpuMetricsCard(cpu: snap.cpu)
            
            // Memory (RAM) Card
            memoryMetricsCard(memory: snap.memory)
            
            // GPU Card (Truthful API Limitations)
            gpuMetricsCard(gpu: snap.gpu)
            
            // Storage Capacity Card
            storageMetricsCard(storage: snap.storage)
            
            // System Telemetry & Network Card
            systemTelemetryCard(sys: snap.systemInfo, net: snap.network)
        }
    }
    
    // MARK: - CPU Card
    
    private func cpuMetricsCard(cpu: CPUMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CPU Utilization", systemImage: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                if cpu.status.isAvailable {
                    Text(String(format: "%.1f%%", cpu.totalUsagePercentage))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                } else {
                    Text(cpu.status == .loading ? "Loading..." : "Unavailable")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            if cpu.status.isAvailable {
                ProgressView(value: cpu.totalUsagePercentage, total: 100.0)
                    .tint(cpu.totalUsagePercentage > 85.0 ? .red : (cpu.totalUsagePercentage > 60.0 ? .orange : .accentColor))
                
                HStack {
                    Text(String(format: "User: %.1f%%", cpu.userPercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text(String(format: "Sys: %.1f%%", cpu.systemPercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text(String(format: "Idle: %.1f%%", cpu.idlePercentage))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                // Mini Core Load Visualizer
                if !cpu.coreLoads.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CORES (\(cpu.coreLoads.count))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: min(cpu.coreLoads.count, 8)), spacing: 3) {
                            ForEach(cpu.coreLoads) { core in
                                ProgressView(value: core.totalUsagePercentage, total: 100.0)
                                    .tint(core.totalUsagePercentage > 80.0 ? .red : .accentColor)
                                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                // Historical Sparkline
                if !metricsService.cpuHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("HISTORY (60 SAMPLES)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                            Spacer()
                        }
                        SparklineView(data: metricsService.cpuHistory, maxVal: 100.0, color: .accentColor)
                            .frame(height: 18)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Memory Card
    
    private func memoryMetricsCard(memory: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Memory (RAM)", systemImage: "memorychip")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                if memory.status.isAvailable {
                    Text(String(format: "%.1f%%", memory.usagePercentage))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
            
            if memory.status.isAvailable && memory.totalBytes > 0 {
                ProgressView(value: Double(memory.usedBytes), total: Double(memory.totalBytes))
                    .tint(memory.pressureLevel == .critical ? .red : (memory.pressureLevel == .warning ? .yellow : .accentColor))
                
                HStack {
                    Text("\(formatBytes(memory.usedBytes)) of \(formatBytes(memory.totalBytes)) Used")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle()
                            .fill(pressureColor(memory.pressureLevel))
                            .frame(width: 5, height: 5)
                        Text(memory.pressureLevel.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(pressureColor(memory.pressureLevel))
                    }
                }
                
                if memory.swapTotalBytes > 0 {
                    HStack {
                        Text("Swap: \(formatBytes(memory.swapUsedBytes)) / \(formatBytes(memory.swapTotalBytes))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                        Spacer()
                    }
                }
                
                if !metricsService.memoryHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        SparklineView(data: metricsService.memoryHistory, maxVal: 100.0, color: .purple)
                            .frame(height: 16)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - GPU Card
    
    private func gpuMetricsCard(gpu: GPUMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("GPU & Metal", systemImage: "sparkles.rectangle.stack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                Text(gpu.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineLimit(1)
            }
            
            HStack {
                if let maxWorkingSet = gpu.recommendedMaxWorkingSetBytes, maxWorkingSet > 0 {
                    Text("Working Set: \(formatBytes(maxWorkingSet))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                Spacer()
                if let allocated = gpu.allocatedBytes {
                    Text("Allocated: \(formatBytes(allocated))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            // Truthful GPU Utilization indicator
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 8))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                Text("Utilization: Unavailable (Requires private Apple Silicon entitlements)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Storage Card
    
    private func storageMetricsCard(storage: StorageMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Disk Storage", systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                if let primary = storage.primaryVolume {
                    Text(String(format: "%.1f%%", primary.usagePercentage))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
            
            if let primary = storage.primaryVolume {
                ProgressView(value: Double(primary.usedBytes), total: Double(primary.totalBytes))
                    .tint(primary.usagePercentage > 90.0 ? .red : .accentColor)
                
                HStack {
                    Text("\(primary.name): \(formatBytes(primary.usedBytes)) of \(formatBytes(primary.totalBytes))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text("\(formatBytes(primary.freeBytes)) free")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - System Telemetry Card
    
    private func systemTelemetryCard(sys: SystemInfoMetrics, net: NetworkMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("System & Network", systemImage: "network")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                
                Text(sys.chipName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineLimit(1)
            }
            
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text("Uptime: \(sys.formattedUptime)")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(themeManager.secondaryTextColor)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("↓ \(formatRate(net.downloadBytesPerSecond))")
                        .font(.system(size: 9, design: .monospaced))
                    Text("↑ \(formatRate(net.uploadBytesPerSecond))")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.accentColor)
            }
            
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(thermalColor(sys.thermalState))
                    Text("Thermal: \(sys.thermalState.rawValue)")
                        .font(.system(size: 9))
                        .foregroundColor(thermalColor(sys.thermalState))
                }
                
                Spacer()
                
                Text(sys.osVersionString)
                    .font(.system(size: 8))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - System Controls Content (Existing Controls)
    
    private var systemControlsContent: some View {
        VStack(spacing: 12) {
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
            
            // Hardware Sliders: Brightness, Backlight & Audio
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
            
            // Active Downloads
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
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    private func formatRate(_ bps: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file) + "/s"
    }
    
    private func pressureColor(_ pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }
    
    private func thermalColor(_ state: ThermalStateLevel) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        case .unknown: return .gray
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

/// Lightweight sparkline view for bounded metric history
public struct SparklineView: View {
    public let data: [Double]
    public let maxVal: Double
    public let color: Color
    
    public init(data: [Double], maxVal: Double, color: Color) {
        self.data = data
        self.maxVal = maxVal
        self.color = color
    }
    
    public var body: some View {
        GeometryReader { geo in
            Path { path in
                guard data.count > 1 else { return }
                let step = geo.size.width / CGFloat(max(1, data.count - 1))
                let height = geo.size.height
                
                for (i, val) in data.enumerated() {
                    let normalized = maxVal > 0 ? CGFloat(min(maxVal, max(0.0, val)) / maxVal) : 0
                    let y = height - (normalized * (height - 2.0)) - 1.0
                    let x = CGFloat(i) * step
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}
