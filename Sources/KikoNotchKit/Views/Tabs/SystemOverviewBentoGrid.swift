import SwiftUI
import AppKit

/// Compact Two-Column Bento Grid for the System Statistics Overview.
/// Answers: "How is my Mac doing right now?" with high-density, minimal summary cards.
/// Clicking any card navigates directly to that category's detailed hardware telemetry view.
@MainActor
public struct SystemOverviewBentoGrid: View {
    @ObservedObject public var metricsService: SystemMetricsService
    @ObservedObject public var batteryMonitor: BatteryMonitor
    @ObservedObject public var themeManager: ThemeManager
    @Binding public var selectedCategory: SystemActivityCategory

    @MainActor
    public init(
        metricsService: SystemMetricsService,
        batteryMonitor: BatteryMonitor,
        themeManager: ThemeManager,
        selectedCategory: Binding<SystemActivityCategory>
    ) {
        self.metricsService = metricsService
        self.batteryMonitor = batteryMonitor
        self.themeManager = themeManager
        self._selectedCategory = selectedCategory
    }

    @MainActor
    public init(
        selectedCategory: Binding<SystemActivityCategory>
    ) {
        self.metricsService = .shared
        self.batteryMonitor = .shared
        self.themeManager = .shared
        self._selectedCategory = selectedCategory
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    public var body: some View {
        let snap = metricsService.snapshot

        LazyVGrid(columns: columns, spacing: 8) {
            // Row 1: CPU | Memory
            bentoCard(
                category: .cpu,
                icon: "cpu",
                title: "CPU",
                primaryMetric: cpuPrimaryMetric(snap.cpu),
                supportingDetail: cpuSupportingDetail(snap.cpu),
                indicator: AnyView(cpuMiniIndicator(snap.cpu))
            )

            bentoCard(
                category: .memory,
                icon: "memorychip",
                title: "MEMORY",
                primaryMetric: memoryPrimaryMetric(snap.memory),
                supportingDetail: memorySupportingDetail(snap.memory),
                indicator: AnyView(memoryMiniIndicator(snap.memory))
            )

            // Row 2: GPU | Thermals
            bentoCard(
                category: .gpu,
                icon: "display",
                title: "GPU",
                primaryMetric: gpuPrimaryMetric(snap.gpu),
                supportingDetail: gpuSupportingDetail(snap.gpu),
                indicator: AnyView(gpuMiniIndicator(snap.gpu))
            )

            bentoCard(
                category: .cooling,
                icon: "thermometer.medium",
                title: "THERMALS",
                primaryMetric: thermalsPrimaryMetric(snap.temperatures, sysInfo: snap.systemInfo),
                supportingDetail: thermalsSupportingDetail(snap.fans, temps: snap.temperatures),
                indicator: AnyView(thermalsMiniIndicator(snap.systemInfo))
            )

            // Row 3: Storage | Battery & Power
            bentoCard(
                category: .storage,
                icon: "internaldrive",
                title: "STORAGE",
                primaryMetric: storagePrimaryMetric(snap.storage),
                supportingDetail: storageSupportingDetail(snap.storage),
                indicator: AnyView(storageMiniIndicator(snap.storage))
            )

            bentoCard(
                category: .power,
                icon: batteryIcon,
                title: "POWER & BATTERY",
                primaryMetric: batteryPrimaryMetric(snap.power),
                supportingDetail: batterySupportingDetail(snap.power),
                indicator: AnyView(batteryMiniIndicator(snap.power))
            )

            // Row 4: Network | System Info
            bentoCard(
                category: .network,
                icon: "network",
                title: "NETWORK",
                primaryMetric: networkPrimaryMetric(snap.network),
                supportingDetail: networkSupportingDetail(snap.network),
                indicator: AnyView(networkMiniIndicator(snap.network))
            )

            bentoCard(
                category: .power,
                icon: "laptopcomputer",
                title: "SYSTEM",
                primaryMetric: systemPrimaryMetric(snap.systemInfo),
                supportingDetail: systemSupportingDetail(snap.systemInfo),
                indicator: AnyView(systemMiniIndicator(snap.systemInfo))
            )
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Reusable Bento Card Container

    @ViewBuilder
    private func bentoCard(
        category: SystemActivityCategory,
        icon: String,
        title: String,
        primaryMetric: String,
        supportingDetail: String,
        indicator: AnyView
    ) -> some View {
        BentoCardButton(
            icon: icon,
            title: title,
            primaryMetric: primaryMetric,
            supportingDetail: supportingDetail,
            indicator: indicator,
            primaryColor: themeManager.primaryTextColor,
            secondaryColor: themeManager.secondaryTextColor,
            action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedCategory = category
                }
            }
        )
    }

    // MARK: - CPU Card Metrics

    private func cpuPrimaryMetric(_ cpu: CPUMetrics) -> String {
        guard cpu.status.isAvailable else { return "Unavailable" }
        return String(format: "%.1f%%", cpu.totalUsagePercentage)
    }

    private func cpuSupportingDetail(_ cpu: CPUMetrics) -> String {
        guard cpu.status.isAvailable else {
            return cpu.status.diagnosticReason ?? "Telemetry unexposed"
        }
        if let p = cpu.performanceClusterPercentage, let e = cpu.efficiencyClusterPercentage {
            return String(format: "P: %.0f%% · E: %.0f%%", p, e)
        }
        return String(format: "User %.0f%% · Sys %.0f%%", cpu.userPercentage, cpu.systemPercentage)
    }

    private func cpuMiniIndicator(_ cpu: CPUMetrics) -> some View {
        HStack(spacing: 4) {
            if let temp = cpu.temperature.value {
                Text(String(format: "%.0f°C", temp))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }

            TelemetryGraphView(
                samples: metricsService.cpu60sHistory,
                isAvailable: cpu.status.isAvailable,
                unavailableReason: nil,
                windowSeconds: 60.0,
                maxValue: 100.0,
                strokeColor: .white,
                height: 18
            )
            .frame(width: 80, height: 18)
        }
    }

    // MARK: - Memory Card Metrics

    private func memoryPrimaryMetric(_ mem: MemoryMetrics) -> String {
        guard mem.status.isAvailable else { return "Unavailable" }
        return formatBytes(mem.usedBytes)
    }

    private func memorySupportingDetail(_ mem: MemoryMetrics) -> String {
        guard mem.status.isAvailable else {
            return mem.status.diagnosticReason ?? "RAM telemetry unavailable"
        }
        return "of \(formatBytes(mem.totalBytes)) · \(mem.pressureLevel.rawValue)"
    }

    private func memoryMiniIndicator(_ mem: MemoryMetrics) -> some View {
        VStack(spacing: 2) {
            let pct = mem.totalBytes > 0 ? Double(mem.usedBytes) / Double(mem.totalBytes) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 75, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(memoryPressureColor(mem.pressureLevel))
                    .frame(width: max(0, min(75, 75 * CGFloat(pct))), height: 4)
            }
            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }

    // MARK: - GPU Card Metrics

    private func gpuPrimaryMetric(_ gpu: GPUMetrics) -> String {
        guard gpu.utilization.status.isAvailable, let val = gpu.utilization.value else {
            return "Unavailable"
        }
        return String(format: "%.1f%%", val)
    }

    private func gpuSupportingDetail(_ gpu: GPUMetrics) -> String {
        if let temp = gpu.temperature.value {
            return "\(gpu.name) · \(String(format: "%.0f°C", temp))"
        }
        if gpu.isAppleSilicon {
            return "\(gpu.name) · Unified"
        }
        return gpu.name
    }

    private func gpuMiniIndicator(_ gpu: GPUMetrics) -> some View {
        if gpu.utilization.status.isAvailable {
            return AnyView(
                TelemetryGraphView(
                    samples: metricsService.gpu60sHistory,
                    isAvailable: true,
                    unavailableReason: nil,
                    windowSeconds: 60.0,
                    maxValue: 100.0,
                    strokeColor: .cyan,
                    height: 18
                )
                .frame(width: 80, height: 18)
            )
        } else {
            return AnyView(
                Text("Unexposed")
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.04)))
            )
        }
    }

    // MARK: - Thermals Card Metrics

    private func thermalsPrimaryMetric(_ temps: TemperatureMetrics, sysInfo: SystemInfoMetrics) -> String {
        if let cpuT = temps.cpuTemperature.value {
            return String(format: "%.0f°C", cpuT)
        }
        return sysInfo.thermalState.rawValue
    }

    private func thermalsSupportingDetail(_ fans: FanMetrics, temps: TemperatureMetrics) -> String {
        if fans.isFanless {
            return "Passively Cooled · Fanless"
        }
        if let first = fans.fans.first, let rpm = first.rpm {
            return "\(rpm) RPM · \(fans.fans.count) Fan\(fans.fans.count > 1 ? "s" : "")"
        }
        if temps.status.isAvailable {
            return "Thermal sensors active"
        }
        return "Passive dissipation"
    }

    private func thermalsMiniIndicator(_ sysInfo: SystemInfoMetrics) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(thermalColor(sysInfo.thermalState))
                .frame(width: 5, height: 5)
            Text(sysInfo.thermalState.rawValue)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(thermalColor(sysInfo.thermalState))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }

    // MARK: - Storage Card Metrics

    private func storagePrimaryMetric(_ storage: StorageMetrics) -> String {
        if let primary = storage.primaryVolume {
            return "\(formatBytes(primary.freeBytes)) Free"
        }
        return "Unavailable"
    }

    private func storageSupportingDetail(_ storage: StorageMetrics) -> String {
        if let primary = storage.primaryVolume {
            return "\(String(format: "%.0f%%", primary.usagePercentage)) of \(formatBytes(primary.totalBytes)) · \(primary.name)"
        }
        return "No volume detected"
    }

    private func storageMiniIndicator(_ storage: StorageMetrics) -> some View {
        let pct: Double = {
            if let p = storage.primaryVolume, p.totalBytes > 0 {
                return Double(p.usedBytes) / Double(p.totalBytes)
            }
            return 0
        }()

        return VStack(spacing: 2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 75, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(pct > 0.9 ? Color.red : Color.white.opacity(0.85))
                    .frame(width: max(0, min(75, 75 * CGFloat(pct))), height: 4)
            }
            Text(String(format: "%.0f%% used", pct * 100))
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }

    // MARK: - Battery & Power Card Metrics

    private func batteryPrimaryMetric(_ power: PowerMetrics) -> String {
        if batteryMonitor.currentState.hasBattery {
            return "\(batteryMonitor.currentState.percentage)%"
        }
        if let w = power.systemPowerWatts {
            return String(format: "%.1fW", w)
        }
        return "AC Power"
    }

    private func batterySupportingDetail(_ power: PowerMetrics) -> String {
        if batteryMonitor.currentState.hasBattery {
            let cond = power.batteryCondition ?? "Normal"
            let src = batteryMonitor.currentState.powerSource
            return "\(src) · \(cond)"
        }
        if let w = power.systemPowerWatts {
            return String(format: "Desktop Draw · %.1fW", w)
        }
        return "Desktop Mac · AC Direct"
    }

    private func batteryMiniIndicator(_ power: PowerMetrics) -> some View {
        if batteryMonitor.currentState.hasBattery {
            let pct = Double(batteryMonitor.currentState.percentage) / 100.0
            return AnyView(
                VStack(spacing: 2) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 65, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(batteryMonitor.currentState.isCharging ? Color.green : (pct < 0.2 ? Color.red : Color.white.opacity(0.85)))
                            .frame(width: max(0, min(65, 65 * CGFloat(pct))), height: 4)
                    }
                    Text(batteryMonitor.currentState.isCharging ? "Charging" : (batteryMonitor.currentState.powerSource))
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                }
            )
        } else {
            return AnyView(
                Text("AC Power")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.12)))
            )
        }
    }

    // MARK: - Network Card Metrics

    private func networkPrimaryMetric(_ net: NetworkMetrics) -> String {
        guard net.status.isAvailable else { return "Offline" }
        return "↓ " + formatRate(net.downloadBytesPerSecond)
    }

    private func networkSupportingDetail(_ net: NetworkMetrics) -> String {
        guard net.status.isAvailable else { return "Interface inactive" }
        return "↑ " + formatRate(net.uploadBytesPerSecond) + " · " + net.activeInterfaceName
    }

    private func networkMiniIndicator(_ net: NetworkMetrics) -> some View {
        TelemetryGraphView(
            samples: metricsService.networkDownload60sHistory,
            isAvailable: net.status.isAvailable,
            unavailableReason: nil,
            windowSeconds: 60.0,
            maxValue: max(100_000, net.downloadBytesPerSecond * 1.5),
            unit: "B/s",
            strokeColor: .green,
            height: 18
        )
        .frame(width: 80, height: 18)
    }

    // MARK: - System Card Metrics

    private func systemPrimaryMetric(_ sysInfo: SystemInfoMetrics) -> String {
        formatUptime(sysInfo.uptimeSeconds)
    }

    private func systemSupportingDetail(_ sysInfo: SystemInfoMetrics) -> String {
        "\(sysInfo.modelIdentifier) · \(sysInfo.osVersionString)"
    }

    private func systemMiniIndicator(_ sysInfo: SystemInfoMetrics) -> some View {
        Text("Optimal")
            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
            .foregroundColor(.green)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.green.opacity(0.12)))
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let totalMins = Int(seconds / 60)
        let days = totalMins / 1440
        let hours = (totalMins % 1440) / 60
        let mins = totalMins % 60
        if days > 0 {
            return "Up \(days)d \(hours)h"
        }
        if hours > 0 {
            return "Up \(hours)h \(mins)m"
        }
        return "Up \(mins)m"
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

    private func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return Color.white.opacity(0.85)
        case .warning: return Color.orange
        case .critical: return Color.red
        case .unknown: return Color.gray
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
        if batteryMonitor.currentState.isCharging {
            return "battery.100.bolt"
        }
        if pct > 80 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 20 { return "battery.50" }
        return "battery.25"
    }
}

// MARK: - Interactive Bento Card Button with Hover State

private struct BentoCardButton: View {
    let icon: String
    let title: String
    let primaryMetric: String
    let supportingDetail: String
    let indicator: AnyView
    let primaryColor: Color
    let secondaryColor: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                // Top Row: Label + Icon + subtle chevron
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(secondaryColor)

                    Text(title)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(secondaryColor)
                        .tracking(0.4)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(secondaryColor.opacity(isHovered ? 0.9 : 0.4))
                }

                // Middle Row: Prominent Primary Metric + Compact Indicator
                HStack(alignment: .center, spacing: 6) {
                    Text(primaryMetric)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    indicator
                }
                .frame(height: 22)

                // Bottom Row: 1-line Supporting Detail
                Text(supportingDetail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(secondaryColor.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isHovered ? 0.065 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.07),
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Click to view detailed \(title) telemetry")
    }
}
