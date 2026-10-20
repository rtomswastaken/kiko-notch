import SwiftUI
import AppKit
import Combine

public enum SystemTabSection: String, CaseIterable, Identifiable {
    case activity = "Activity"
    case controls = "Controls"

    public var id: String { rawValue }

    // Backwards compatibility alias
    public static var metrics: SystemTabSection { .activity }
}

public enum SystemActivityCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case cpu = "CPU"
    case gpu = "GPU"
    case cooling = "Cooling"
    case memory = "Memory"
    case storage = "Storage"
    case power = "Power"
    case network = "Network"

    public var id: String { rawValue }
}

/// Dedicated System Status & Hardware Telemetry Activity Dashboard (Page 2)
public struct SystemTabView: View {
    @ObservedObject public var metricsService = SystemMetricsService.shared
    @ObservedObject public var batteryMonitor = BatteryMonitor.shared
    @ObservedObject public var bluetoothMonitor = BluetoothMonitor.shared
    @ObservedObject public var brightnessMonitor = BrightnessHUDMonitor.shared
    @ObservedObject public var kbdMonitor = KeyboardBacklightMonitor.shared
    @ObservedObject public var audioHUD = AudioHUDMonitor.shared
    @ObservedObject public var downloadMonitor = DownloadMonitor.shared
    @ObservedObject public var themeManager = ThemeManager.shared

    private var brightnessPercentageText: String {
        let pct = Int((Double(brightnessMonitor.currentBrightness) * 100.0).rounded())
        return "\(pct)%"
    }

    private var backlightPercentageText: String {
        let pct = Int((Double(kbdMonitor.currentBacklight) * 100.0).rounded())
        return "\(pct)%"
    }

    private var volumePercentageText: String {
        let pct = Int((Double(audioHUD.currentVolume) * 100.0).rounded())
        return "\(pct)%"
    }

    @State private var activeSection: SystemTabSection = {
        if let s = ProcessInfo.processInfo.environment["KIKO_SYSTEM_SECTION"]?.lowercased(), s == "controls" {
            return .controls
        }
        return .activity
    }()
    @State private var selectedCategory: SystemActivityCategory = {
        if let cat = ProcessInfo.processInfo.environment["KIKO_SYSTEM_CATEGORY"]?.lowercased() {
            return SystemActivityCategory.allCases.first(where: { $0.rawValue.lowercased() == cat }) ?? .all
        }
        return .all
    }()

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Header Bar & Live Indicator
                headerBar

                if activeSection == .activity {
                    categoryFilterBar
                    systemActivityDashboardContent
                } else {
                    systemControlsContent
                }
            }
            .padding(.bottom, 6)
        }
        .onAppear {
            metricsService.registerConsumer(id: "SystemTabView")
        }
        .onDisappear {
            metricsService.unregisterConsumer(id: "SystemTabView")
        }
        .notchPageViewport()
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center) {
            // Title & Status
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activeSection == .activity ? "SYSTEM ACTIVITY" : "SYSTEM CONTROLS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)

                    if activeSection == .activity {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(metricsService.isMonitoring ? Color.green : Color.gray)
                                .frame(width: 5, height: 5)
                            Text(metricsService.isMonitoring ? "MONITORING" : "PAUSED")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(metricsService.isMonitoring ? Color.green.opacity(0.9) : themeManager.secondaryTextColor)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.04)))
                    }
                }

                Text(activeSection == .activity ? "Live hardware telemetry · \(metricsService.lastUpdatedString)" : "Hardware HUD & device control")
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            Spacer()

            // Section Switcher & Controls
            HStack(spacing: 6) {
                if activeSection == .activity {
                    // Sampling Interval Menu
                    Menu {
                        ForEach(SamplingInterval.allCases) { interval in
                            Button(interval.displayName) {
                                metricsService.samplingInterval = interval
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(intervalBadgeText(metricsService.samplingInterval))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 48)

                    // Manual Refresh
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

                // Segment Switcher (Activity vs Controls)
                HStack(spacing: 2) {
                    ForEach(SystemTabSection.allCases) { section in
                        Button(action: { activeSection = section }) {
                            Text(section.rawValue)
                                .font(.system(size: 10, weight: activeSection == section ? .semibold : .medium))
                                .foregroundColor(activeSection == section ? .white : themeManager.secondaryTextColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(activeSection == section ? (AccentThemeManager.shared.isDefaultWhite ? Color.white.opacity(0.22) : AccentThemeManager.shared.primaryAccent.opacity(0.35)) : Color.clear)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(activeSection == section ? AccentThemeManager.shared.borderGradient : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Capsule().fill(Color.white.opacity(0.05)))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SystemActivityCategory.allCases) { cat in
                    Button(action: { selectedCategory = cat }) {
                        Text(cat.rawValue)
                            .font(.system(size: 9, weight: selectedCategory == cat ? .semibold : .regular))
                            .foregroundColor(selectedCategory == cat ? .white : themeManager.secondaryTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == cat ? Color.white.opacity(0.15) : Color.white.opacity(0.03))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - System Activity Dashboard Content

    @ViewBuilder
    private var systemActivityDashboardContent: some View {
        let snap = metricsService.snapshot

        if selectedCategory == .all {
            SystemOverviewBentoGrid(
                metricsService: metricsService,
                batteryMonitor: batteryMonitor,
                themeManager: themeManager,
                selectedCategory: $selectedCategory
            )
        } else {
            VStack(spacing: 8) {
                // Return to Overview Header Bar
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedCategory = .all
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8, weight: .bold))
                            Text("Overview")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)

                    Text("•")
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.4))
                        .font(.system(size: 8))

                    Text("\(selectedCategory.rawValue) Telemetry & Details")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)

                    Spacer()
                }
                .padding(.horizontal, 4)

                switch selectedCategory {
                case .all:
                    EmptyView()
                case .cpu:
                    cpuHardwareCard(cpu: snap.cpu)
                case .gpu:
                    gpuHardwareCard(gpu: snap.gpu)
                case .cooling:
                    coolingAndSensorsCard(fans: snap.fans, temps: snap.temperatures)
                case .memory:
                    memoryHardwareCard(mem: snap.memory)
                case .storage:
                    storageAndDiskCard(storage: snap.storage)
                case .power:
                    powerAndBatteryCard(power: snap.power, sysInfo: snap.systemInfo)
                case .network:
                    networkActivityCard(net: snap.network)
                }
            }
        }
    }

    // MARK: - 1. CPU Card

    private func cpuHardwareCard(cpu: CPUMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Label("CPU", systemImage: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)

                if let temp = cpu.temperature.value {
                    Text(String(format: "%.1f°C", temp))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.white.opacity(0.05)))
                }

                if let pwr = cpu.powerWatts {
                    Text(String(format: "%.1fW", pwr))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                }

                Spacer()

                if cpu.status.isAvailable {
                    Text(String(format: "%.1f%%", cpu.totalUsagePercentage))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.primaryTextColor)
                } else {
                    Text("Unavailable")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }

            // 60-Second Live Utilization Graph
            TelemetryGraphView(
                samples: metricsService.cpu60sHistory,
                isAvailable: cpu.status.isAvailable,
                unavailableReason: cpu.status.diagnosticReason,
                windowSeconds: 60.0,
                maxValue: 100.0,
                strokeColor: .white,
                height: 44
            )

            // Core & Cluster Breakdown
            HStack {
                if let pClust = cpu.performanceClusterPercentage, let eClust = cpu.efficiencyClusterPercentage {
                    Text(String(format: "P-Cluster: %.0f%% · E-Cluster: %.0f%%", pClust, eClust))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                } else {
                    Text("\(cpu.physicalCores) Cores")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                }
                Spacer()
                Text(String(format: "U:%.0f%% S:%.0f%% I:%.0f%%", cpu.userPercentage, cpu.systemPercentage, cpu.idlePercentage))
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - 2. GPU Card

    private func gpuHardwareCard(gpu: GPUMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Label("GPU", systemImage: "display")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)

                if let temp = gpu.temperature.value {
                    Text(String(format: "%.1f°C", temp))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.white.opacity(0.05)))
                }

                Spacer()

                if gpu.utilization.status.isAvailable, let val = gpu.utilization.value {
                    Text(String(format: "%.1f%%", val))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.primaryTextColor)
                } else {
                    Text("Unavailable")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }

            // 60-Second Live Graph
            TelemetryGraphView(
                samples: metricsService.gpu60sHistory,
                isAvailable: gpu.utilization.status.isAvailable,
                unavailableReason: gpu.utilization.status.diagnosticReason ?? "GPU utilization unavailable",
                windowSeconds: 60.0,
                maxValue: 100.0,
                strokeColor: .cyan,
                height: 44
            )

            // Device Name & Memory
            HStack {
                Text(gpu.name)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if let allocated = gpu.allocatedBytes, let maxWorking = gpu.recommendedMaxWorkingSetBytes, maxWorking > 0 {
                    Text("\(formatBytes(allocated)) / \(formatBytes(maxWorking)) (Working Set)")
                        .font(.system(size: 8, design: .monospaced))
                } else if gpu.isAppleSilicon {
                    Text("Apple Silicon Unified Memory")
                        .font(.system(size: 8, design: .monospaced))
                }
            }
            .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - 3. Cooling & Sensors Card

    private func coolingAndSensorsCard(fans: FanMetrics, temps: TemperatureMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("COOLING & SENSORS", systemImage: "fanblades")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                if !fans.isFanless && !fans.fans.isEmpty {
                    Text("\(fans.fans.count) Fans Active")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }

            // Fans Display
            if fans.isFanless {
                HStack(spacing: 6) {
                    Image(systemName: "wind")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Fanless Hardware · Passively cooled Apple Silicon")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                }
                .padding(.vertical, 2)
            } else if !fans.fans.isEmpty {
                VStack(spacing: 5) {
                    ForEach(fans.fans) { fan in
                        VStack(spacing: 2) {
                            HStack {
                                Text(fan.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if let rpm = fan.rpm {
                                    Text("\(rpm) RPM")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(themeManager.primaryTextColor)
                                } else {
                                    Text("Unavailable")
                                        .font(.system(size: 9))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                            }

                            if let rpm = fan.rpm, let maxR = fan.maxRPM, maxR > 0 {
                                CustomProgressBar(
                                    value: Double(rpm) / Double(maxR),
                                    color: Color.white.opacity(0.85)
                                )
                                HStack {
                                    if let minR = fan.minRPM {
                                        Text("Min: \(minR) RPM")
                                            .font(.system(size: 7, design: .monospaced))
                                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                                    }
                                    Spacer()
                                    Text("Max: \(maxR) RPM")
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "fanblades.slash")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("Fan telemetry not reported on this configuration")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                }
            }

            // Temperature Sensor Grid
            if temps.status.isAvailable {
                Divider().background(Color.white.opacity(0.06))

                VStack(alignment: .leading, spacing: 4) {
                    Text("THERMAL SENSORS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)

                    HStack(spacing: 8) {
                        if let cpuT = temps.cpuTemperature.value {
                            tempPill(title: "CPU", value: cpuT)
                        }
                        if let gpuT = temps.gpuTemperature.value {
                            tempPill(title: "GPU", value: gpuT)
                        }
                        if let battT = temps.batteryTemperature.value {
                            tempPill(title: "Battery", value: battT)
                        }
                        if let ambT = temps.ambientTemperature.value {
                            tempPill(title: "Ambient", value: ambT)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func tempPill(title: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(themeManager.secondaryTextColor)
            Text(String(format: "%.1f°C", value))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(themeManager.primaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }

    // MARK: - 4. Memory Card

    private func memoryHardwareCard(mem: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("MEMORY (RAM)", systemImage: "memorychip")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                if mem.status.isAvailable {
                    Text("\(formatBytes(mem.usedBytes)) / \(formatBytes(mem.totalBytes)) (\(String(format: "%.1f%%", mem.usagePercentage)))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }

            // Progress Bar
            CustomProgressBar(
                value: mem.totalBytes > 0 ? Double(mem.usedBytes) / Double(mem.totalBytes) : 0,
                color: memoryPressureColor(mem.pressureLevel)
            )

            // Breakdown Details
            HStack {
                Text("App: \(formatBytes(mem.appMemoryBytes)) · Wired: \(formatBytes(mem.wiredBytes)) · Comp: \(formatBytes(mem.compressedBytes))")
                    .font(.system(size: 8))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text("Swap: \(formatBytes(mem.swapUsedBytes)) · \(mem.pressureLevel.rawValue) Pressure")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - 5. Storage & Disk Activity Card

    private func storageAndDiskCard(storage: StorageMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("STORAGE & DISK ACTIVITY", systemImage: "internaldrive")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Text("R: \(formatRate(storage.readBytesPerSecond)) · W: \(formatRate(storage.writeBytesPerSecond))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            if let primary = storage.primaryVolume {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "laptopcomputer")
                                .font(.system(size: 10))
                            Text("\(primary.name) (Startup Disk)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(themeManager.primaryTextColor)
                        }

                        Spacer()

                        Text("\(formatBytes(primary.usedBytes)) / \(formatBytes(primary.totalBytes)) (\(String(format: "%.1f%%", primary.usagePercentage)))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }

                    CustomProgressBar(
                        value: primary.totalBytes > 0 ? Double(primary.usedBytes) / Double(primary.totalBytes) : 0,
                        color: primary.usagePercentage > 90 ? Color.red : Color.white.opacity(0.9)
                    )

                    HStack {
                        Text("\(formatBytes(primary.freeBytes)) Free")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Text("Mount: \(primary.mountPoint)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                    }
                }
            }

            // Mounted Volumes Breakdown
            if storage.allVolumes.count > 1 {
                Divider().background(Color.white.opacity(0.06))

                VStack(alignment: .leading, spacing: 4) {
                    Text("MOUNTED VOLUMES")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)

                    ForEach(storage.allVolumes.filter { !$0.isPrimary }) { vol in
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: vol.isRemovable ? "externaldrive" : "externaldrive.connected.to.line.below")
                                    .font(.system(size: 9))
                                    .foregroundColor(themeManager.secondaryTextColor)
                                Text(vol.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(formatBytes(vol.usedBytes)) / \(formatBytes(vol.totalBytes)) (\(formatBytes(vol.freeBytes)) free)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - 6. Power & Battery Health Card

    private func powerAndBatteryCard(power: PowerMetrics, sysInfo: SystemInfoMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("POWER & BATTERY HEALTH", systemImage: "bolt.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                if let w = power.systemPowerWatts {
                    Text(String(format: "%.2f W Draw", w))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }

            HStack(spacing: 8) {
                // Battery State
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery Level")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("\(batteryMonitor.currentState.percentage)% · \(batteryMonitor.currentState.powerSource)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Health & Cycles
                VStack(alignment: .leading, spacing: 2) {
                    Text("Condition & Cycles")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    let cycles = power.batteryCycleCount.map { "\($0) cycles" } ?? "Unknown"
                    let cond = power.batteryCondition ?? "Normal"
                    Text("\(cond) · \(cycles)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Thermal State
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thermal State")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(sysInfo.thermalState.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(sysInfo.thermalState == .nominal ? .green : .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Color.white.opacity(0.06))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hardware")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(sysInfo.chipName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("OS Version")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(sysInfo.osVersionString.isEmpty ? "macOS" : sysInfo.osVersionString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Uptime")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(sysInfo.formattedUptime)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - 7. Network Activity Card

    private func networkActivityCard(net: NetworkMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("NETWORK ACTIVITY", systemImage: "network")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Text("Interface: \(net.activeInterfaceName)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(formatRate(net.downloadBytesPerSecond))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                    Text("Total: \(formatBytes(net.totalBytesReceived))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(formatRate(net.uploadBytesPerSecond))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                    Text("Total: \(formatBytes(net.totalBytesSent))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TelemetryGraphView(
                samples: metricsService.networkDownload60sHistory,
                isAvailable: net.status.isAvailable,
                unavailableReason: nil,
                windowSeconds: 60.0,
                maxValue: max(100_000, net.downloadBytesPerSecond * 1.5),
                unit: "B/s",
                strokeColor: .green,
                height: 36
            )
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - System Controls Content (Preserved Hardware Sliders)

    private var systemControlsContent: some View {
        VStack(spacing: 10) {
            controlsBatteryCard
            controlsSlidersCard
            controlsBluetoothCard
            controlsDownloadsCard
        }
    }

    private var controlsBatteryCard: some View {
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

    private var controlsSlidersCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 16)

                Slider(value: Binding(
                    get: { Double(brightnessMonitor.currentBrightness) },
                    set: { brightnessMonitor.setSimulatedBrightness(Float($0)) }
                ), in: 0.0...1.0)

                Text(brightnessPercentageText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 32, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Image(systemName: "light.ribbon")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 16)

                Slider(value: Binding(
                    get: { Double(kbdMonitor.currentBacklight) },
                    set: { kbdMonitor.setSimulatedBacklight(Float($0)) }
                ), in: 0.0...1.0)

                Text(backlightPercentageText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 32, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Image(systemName: audioHUD.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 16)

                Slider(value: Binding(
                    get: { Double(audioHUD.currentVolume) },
                    set: { audioHUD.setSimulatedVolume(Float($0)) }
                ), in: 0.0...1.0)

                Text(volumePercentageText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private var controlsBluetoothCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Connected Peripherals", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Text("\(bluetoothMonitor.connectedPeripherals.count) Active")
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            if bluetoothMonitor.connectedPeripherals.isEmpty {
                Text("No wireless peripherals connected")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                    .padding(.vertical, 4)
            } else {
                ForEach(bluetoothMonitor.connectedPeripherals) { dev in
                    HStack {
                        Image(systemName: peripheralIcon(for: dev.name))
                            .font(.system(size: 10))
                            .frame(width: 16)
                        Text(dev.name)
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        if let b = dev.batteryLevel {
                            Text("\(b)%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private var controlsDownloadsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Active Downloads", systemImage: "arrow.down.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Text("\(downloadMonitor.downloads.count) Active")
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            if downloadMonitor.downloads.isEmpty {
                Text("No background file downloads in progress")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                    .padding(.vertical, 4)
            } else {
                ForEach(downloadMonitor.downloads) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.filename)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", item.progress * 100))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }

                        ProgressView(value: item.progress)
                            .tint(.accentColor)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Helpers

    private func intervalBadgeText(_ interval: SamplingInterval) -> String {
        switch interval {
        case .quarterSecond: return "0.25s"
        case .oneSecond: return "1s"
        case .twoSeconds: return "2s"
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s"
        }
    }

    private func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return Color.white.opacity(0.85)
        case .warning: return Color.orange
        case .critical: return Color.red
        case .unknown: return Color.gray
        }
    }

    private func formatRate(_ bps: Double) -> String {
        if bps >= 1_048_576 {
            return String(format: "%.1f MB/s", bps / 1_048_576.0)
        } else if bps >= 1024 {
            return String(format: "%.0f KB/s", bps / 1024.0)
        } else {
            return String(format: "%.0f B/s", bps)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        let gb = b / (1024 * 1024 * 1024)
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = b / (1024 * 1024)
        if mb >= 1.0 {
            return String(format: "%.0f MB", mb)
        }
        return String(format: "%.0f KB", b / 1024)
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

    private func peripheralIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("keyboard") { return "keyboard" }
        if lower.contains("mouse") || lower.contains("trackpad") { return "computermouse" }
        if lower.contains("airpod") || lower.contains("headphone") || lower.contains("buds") { return "headphones" }
        return "antenna.radiowaves.left.and.right"
    }
}

// MARK: - Reusable Custom Progress Bar

private struct CustomProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))), height: 5)
            }
        }
        .frame(height: 5)
    }
}
