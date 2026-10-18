import SwiftUI
import AppKit

/// Unified Multi-Provider AI Dashboard View.
/// Implements AI-DASH-001, AI-DASH-002, AI-DASH-003, and AI-DASH-004.
public struct AIDashboardView: View {
    @ObservedObject public var registry: ProviderRegistry
    @ObservedObject public var scheduler: RefreshScheduler
    @State private var showingExportConfirmation = false
    @State private var showingClearConfirmation = false
    @State private var dailyHistory: [(day: String, requests: Int, tokens: Int)] = []
    
    public init(registry: ProviderRegistry? = nil, scheduler: RefreshScheduler? = nil) {
        self.registry = registry ?? ProviderRegistry.shared
        self.scheduler = scheduler ?? RefreshScheduler.shared
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header & Refresh
            HStack {
                Label("AI Intelligence Center", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                if scheduler.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: {
                        Task { await scheduler.triggerManualRefresh() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh AI Provider Status")
                }
            }
            
            // Enabled Providers Cards
            VStack(spacing: 8) {
                // Antigravity (Always present when enabled)
                if SettingsManager.shared.isAIProviderEnabled(.antigravity) {
                    providerCard(id: .antigravity, name: "Google Antigravity (Primary)", icon: "sparkle")
                }
                
                // OpenAI Codex (Optional)
                if SettingsManager.shared.isAIProviderEnabled(.codex) {
                    providerCard(id: .codex, name: "OpenAI Codex", icon: "chevron.left.forwardslash.chevron.right")
                }
                
                // Anthropic Claude (Optional)
                if SettingsManager.shared.isAIProviderEnabled(.claude) {
                    providerCard(id: .claude, name: "Anthropic Claude", icon: "brain")
                }
            }
            
            // Historical Chart (AI-DASH-002)
            UsageChartView(dailyData: dailyHistory)
            
            // Footer: Export & Purge Actions (AI-DASH-004)
            HStack {
                Button(action: exportHistoryJSON) {
                    Label("Export JSON", systemImage: "arrow.down.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: exportHistoryCSV) {
                    Label("Export CSV", systemImage: "tablecells")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(role: .destructive, action: {
                    showingClearConfirmation = true
                }) {
                    Text("Clear History")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .onAppear {
            loadChartData()
        }
        .confirmationDialog(
            "Clear all AI usage history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Records", role: .destructive) {
                UsageRepository.shared.clearAllHistory()
                loadChartData()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func providerCard(id: AIProviderID, name: String, icon: String) -> some View {
        let snapshot = registry.snapshots[id]
        let isAvailable = snapshot?.isAvailable ?? false
        let status = snapshot?.statusMessage ?? "Connecting..."
        let alert = registry.activeThresholdAlerts[id]
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isAvailable ? .blue : .secondary)
                
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Circle()
                    .fill(isAvailable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            
            HStack {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                if let reqs = snapshot?.sessionRequests {
                    Text("\(reqs) reqs")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            
            if let alert = alert {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(alert)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.yellow)
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    private func loadChartData() {
        self.dailyHistory = UsageRepository.shared.fetchDailyUsage(days: 7)
    }
    
    private func exportHistoryJSON() {
        guard let json = UsageRepository.shared.exportJSON() else { return }
        saveStringToUserFile(content: json, defaultName: "kiko_ai_usage.json")
    }
    
    private func exportHistoryCSV() {
        let csv = UsageRepository.shared.exportCSV()
        saveStringToUserFile(content: csv, defaultName: "kiko_ai_usage.csv")
    }
    
    private func saveStringToUserFile(content: String, defaultName: String) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultName
        savePanel.canCreateDirectories = true
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

/// Compact AI indicator dot / badge for collapsed island (AI-DASH-003).
public struct CompactAIIndicatorView: View {
    public let isOnline: Bool
    
    public init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isOnline ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("AI Status: \(isOnline ? "Active" : "Idle")")
    }
}
