//
//  HomeSystemMonitorWidget.swift
//  KikoNotchKit
//
//  Compact System Monitor widget for the Home page lower-left column,
//  monitoring CPU, GPU, and RAM with genuine metrics and horizontal progress bars.
//

import SwiftUI
import AppKit

public struct HomeSystemMonitorWidget: View {
    @ObservedObject public var metricsService = SystemMetricsService.shared
    @ObservedObject public var themeManager = ThemeManager.shared

    private let consumerID = "kiko.home.system_monitor"

    public init() {}

    private var snapshot: SystemMetricsSnapshot {
        metricsService.snapshot
    }

    private var cpuPercent: Double {
        max(0.0, min(100.0, snapshot.cpu.totalUsagePercentage))
    }

    private var gpuUtilization: MetricValue<Double> {
        snapshot.gpu.utilization
    }

    private var ramUsedGB: Double {
        Double(snapshot.memory.usedBytes) / 1_073_741_824.0
    }

    private var ramTotalGB: Double {
        Double(snapshot.memory.totalBytes) / 1_073_741_824.0
    }

    private var ramFraction: Double {
        guard snapshot.memory.totalBytes > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(snapshot.memory.usedBytes) / Double(snapshot.memory.totalBytes)))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Widget Title
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(themeManager.secondaryTextColor)

                Text("SYSTEM MONITOR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.85))
                    .tracking(0.6)

                Spacer()
            }

            VStack(spacing: 3) {
                // 1. CPU
                metricRow(
                    label: "CPU",
                    valueText: "\(Int(cpuPercent.rounded()))%",
                    fraction: cpuPercent / 100.0,
                    isAvailable: true
                )

                // 2. GPU
                if gpuUtilization.status.isAvailable, let gpuVal = gpuUtilization.value {
                    metricRow(
                        label: "GPU",
                        valueText: "\(Int(gpuVal.rounded()))%",
                        fraction: max(0.0, min(1.0, gpuVal / 100.0)),
                        isAvailable: true
                    )
                } else {
                    metricRow(
                        label: "GPU",
                        valueText: "Unavailable",
                        fraction: 0.0,
                        isAvailable: false
                    )
                }

                // 3. RAM
                metricRow(
                    label: "RAM",
                    valueText: String(format: "%.1f / %.0f GB", ramUsedGB, ramTotalGB),
                    fraction: ramFraction,
                    isAvailable: snapshot.memory.totalBytes > 0
                )
            }
        }
        .padding(.horizontal, IslandSpacing.cardPaddingHorizontal)
        .padding(.vertical, IslandSpacing.cardPaddingVertical)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IslandSpacing.cardCornerRadius)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IslandSpacing.cardCornerRadius)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .onAppear {
            metricsService.startMonitoring(consumerID: consumerID)
        }
        .onDisappear {
            metricsService.stopMonitoring(consumerID: consumerID)
        }
    }

    @ViewBuilder
    private func metricRow(label: String, valueText: String, fraction: Double, isAvailable: Bool) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.95))

                Spacer()

                Text(valueText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isAvailable ? Color.white : Color.white.opacity(0.6))
            }

            // Horizontal Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3)

                    // Fill
                    if isAvailable {
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: max(3.0, geo.size.width * CGFloat(max(0.0, min(1.0, fraction)))), height: 3)
                            .animation(.easeOut(duration: 0.25), value: fraction)
                    }
                }
            }
            .frame(height: 3)
        }
    }
}
