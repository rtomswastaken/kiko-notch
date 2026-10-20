import SwiftUI
import AppKit

/// Unified AI Dashboard for Kiko Notch.
/// Combines AI subscription quota / token usage monitoring, WakaTime coding analytics,
/// and a GitHub-style annual coding activity heatmap into a compact,
/// non-scrolling monochrome dashboard.
public struct AIUsageTabView: View {
    @ObservedObject public var registry = ProviderRegistry.shared
    @ObservedObject public var wakaTime = WakaTimeService.shared
    @ObservedObject public var themeManager = ThemeManager.shared

    public init() {}

    private var activeDiagnostics: AIProviderDiagnostics? {
        guard let selected = registry.selectedProviderID else { return nil }
        return registry.diagnostics[selected]
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 1. HEADER: AI DASHBOARD on Left, Configured Provider Selector + Refresh + Add on Right
            headerBar

            // 2. MAIN CONTENT (Two Columns: Circular Quota/Usage Gauges on Left, Coding Stats on Right)
            HStack(alignment: .top, spacing: 10) {
                // LEFT COLUMN: Three Circular Quota/Token Gauges
                leftQuotaColumn
                    .frame(maxWidth: .infinity)

                // RIGHT COLUMN: Compact Coding Duration & Token Stats
                rightStatsColumn
                    .frame(width: 210)
            }
            .frame(height: 82)

            // 3. BOTTOM: Annual Coding Activity Heatmap spanning available content width
            AnnualHeatmapView(
                activities: wakaTime.annualActivity,
                isConnected: wakaTime.isConfigured
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            Task {
                await registry.refreshAll()
                await wakaTime.refresh()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center) {
            // Left: Clean Dashboard Title + Diagnostic Summary
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignTokens.accentColor)

                Text("AI DASHBOARD")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(DesignTokens.primaryText)
                    .tracking(0.6)

                if let diag = activeDiagnostics {
                    Text("· \(diag.statusSummary)")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignTokens.secondaryText.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right: Provider Selector Strip + Refresh Button + Add Provider Button
            HStack(spacing: 4) {
                let configured = registry.configuredProviders
                if configured.isEmpty {
                    Text("No Providers Configured")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignTokens.secondaryText)
                } else {
                    ForEach(configured, id: \.id) { provider in
                        providerPill(for: provider)
                    }
                }

                // Manual Refresh Button
                Button(action: {
                    Task {
                        await registry.refreshAll(force: true)
                        await wakaTime.refresh(force: true)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(registry.isRefreshing ? DesignTokens.accentColor : DesignTokens.primaryText)
                        .frame(width: 20, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(DesignTokens.subtleBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(registry.isRefreshing)
                .help("Refresh AI Quotas and Usage")
                .accessibilityLabel("Refresh AI Quotas")

                // Add Provider Button (opens Settings AI Providers tab)
                Button(action: openSettingsAI) {
                    Image(systemName: "plus")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(DesignTokens.primaryText)
                        .frame(width: 20, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(DesignTokens.subtleBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Configure or Add AI Providers in Settings")
                .accessibilityLabel("Add AI Provider in Settings")
            }
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private func providerPill(for provider: any AIProviderAdapter) -> some View {
        let isSelected = registry.selectedProviderID == provider.id
        Button(action: {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                registry.selectProvider(provider.id)
            }
        }) {
            Text(shortProviderName(for: provider.id))
                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? AccentThemeManager.shared.foregroundOnAccent : DesignTokens.secondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? AccentThemeManager.shared.horizontalGradient : LinearGradient(colors: [Color.white.opacity(0.06)], startPoint: .leading, endPoint: .trailing))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isSelected ? Color.clear : DesignTokens.subtleBorder,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Select \(provider.displayName)")
        .accessibilityLabel(provider.displayName)
    }

    private func shortProviderName(for id: AIProviderID) -> String {
        switch id {
        case .antigravity: return "Antigravity"
        case .codex: return "Codex"
        case .claude: return "Claude"
        }
    }

    // MARK: - Left Quota Column

    @ViewBuilder
    private var leftQuotaColumn: some View {
        if registry.configuredProviders.isEmpty {
            // Empty State
            VStack(spacing: 4) {
                Text("No AI Provider Connected")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.primaryText)

                Text("Click [+] to add OpenAI Codex, Claude Code, or Google Antigravity in Settings.")
                    .font(.system(size: 8.5))
                    .foregroundColor(DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)

                Button("Open Settings", action: openSettingsAI)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(DesignTokens.subtleBorder, lineWidth: 0.5)
            )
        } else {
            // Selected Provider's 3 Quota / Token Rings
            let quotas = currentQuotaMetrics
            HStack(spacing: 12) {
                ForEach(quotas) { metric in
                    CircularQuotaRingView(metric: metric, size: 48)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(DesignTokens.subtleBorder, lineWidth: 0.5)
            )
        }
    }

    private var currentQuotaMetrics: [AIQuotaMetric] {
        guard let selected = registry.selectedProviderID else {
            return [
                .unavailable(window: .fiveHour, reason: "No provider selected"),
                .unavailable(window: .weekly, reason: "No provider selected"),
                .unavailable(window: .monthly, reason: "No provider selected")
            ]
        }

        if let snap = registry.quotaSnapshots[selected] {
            if snap.quotas.count == 3 {
                return snap.quotas
            }
            var list = snap.quotas
            while list.count < 3 {
                let win: AIQuotaWindowType = list.count == 1 ? .weekly : .monthly
                list.append(.unsupported(window: win, reason: "Window not supported"))
            }
            return Array(list.prefix(3))
        }

        if registry.isRefreshing {
            return [
                .loading(window: .fiveHour),
                .loading(window: .weekly),
                .loading(window: .monthly)
            ]
        }

        return [
            .unavailable(window: .fiveHour, reason: "No quota data"),
            .unavailable(window: .weekly, reason: "No quota data"),
            .unavailable(window: .monthly, reason: "No quota data")
        ]
    }

    // MARK: - Right Stats Column

    private var rightStatsColumn: some View {
        let (tokens, included, monthLabel) = registry.previousCalendarMonthTokenUsage()
        let tokenText: String = {
            if let t = tokens {
                if t >= 1_000_000 {
                    return String(format: "%.1fM TOKENS", Double(t) / 1_000_000.0)
                } else if t >= 1_000 {
                    return String(format: "%.1fK TOKENS", Double(t) / 1_000.0)
                } else {
                    return "\(t) TOKENS"
                }
            }
            return "UNAVAILABLE"
        }()

        return CodingStatsView(
            stats: wakaTime.stats,
            tokenUsageText: tokenText,
            tokenMonthLabel: monthLabel,
            tokenProviders: included
        )
    }

    // MARK: - Navigation Helper

    private func openSettingsAI() {
        SettingsTabSelection.shared.selectedTab = .ai
        SettingsWindowController.shared.showSettings()
    }
}
