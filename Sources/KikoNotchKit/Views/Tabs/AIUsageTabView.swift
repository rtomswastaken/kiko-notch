import SwiftUI
import AppKit

/// Dedicated AI Provider Usage & Intelligence Dashboard (Screenshots 3 & 4)
public struct AIUsageTabView: View {
    @ObservedObject public var registry = ProviderRegistry.shared
    @ObservedObject public var scheduler = RefreshScheduler.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @State private var selectedProviderID: AIProviderID = .antigravity
    @State private var dailyHistory: [(day: String, requests: Int, tokens: Int)] = []
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Header Bar with Manual Refresh
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        
                        Text("AI Provider Usage")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    if scheduler.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(action: {
                            Task { await scheduler.triggerManualRefresh() }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                                Text("Refresh")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help("Trigger manual AI provider metrics poll")
                    }
                }
                .padding(.horizontal, 4)
                
                // Provider Pill Tabs (Antigravity, Codex, Claude)
                HStack(spacing: 6) {
                    providerPill(id: .antigravity, name: "Google Antigravity", icon: "sparkles")
                    providerPill(id: .codex, name: "OpenAI Codex", icon: "terminal.fill")
                    providerPill(id: .claude, name: "Anthropic Claude", icon: "bubble.left.and.bubble.right.fill")
                }
                
                // Detailed Provider Card
                activeProviderCard
                
                // Historical Usage Breakdown
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("USAGE HISTORY (LAST 7 DAYS)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Spacer()
                    }
                    
                    UsageChartView(dailyData: dailyHistory)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .onAppear {
            loadUsageHistory()
        }
    }
    
    @ViewBuilder
    private func providerPill(id: AIProviderID, name: String, icon: String) -> some View {
        let isSelected = selectedProviderID == id
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedProviderID = id
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(name.components(separatedBy: " ").last ?? name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : themeManager.secondaryTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isSelected ? 0.14 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.22 : 0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var activeProviderCard: some View {
        let adapter = registry.adapter(for: selectedProviderID)
        let snapshot = registry.snapshots[selectedProviderID]
        let isEnabled = SettingsManager.shared.isAIProviderEnabled(selectedProviderID)
        
        VStack(spacing: 10) {
            // Title & Status Tag
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(adapter?.displayName ?? selectedProviderID.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text(isEnabled ? "Active & Configured" : "Disabled in Settings")
                        .font(.system(size: 10))
                        .foregroundColor(isEnabled ? .green : .secondary)
                }
                
                Spacer()
                
                statusBadge(for: snapshot)
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // Metrics Grid (Tokens, Requests, Cost/Limit)
            HStack(spacing: 8) {
                metricBox(
                    title: "SESSION TOKENS",
                    value: snapshot?.sessionTokens != nil ? "\(snapshot!.sessionTokens!)" : "Unavailable",
                    isTruthful: snapshot?.sessionTokens != nil
                )
                metricBox(
                    title: "REQUESTS",
                    value: snapshot?.sessionRequests != nil ? "\(snapshot!.sessionRequests!)" : "0",
                    isTruthful: snapshot?.sessionRequests != nil
                )
                metricBox(
                    title: "QUOTA RESET",
                    value: snapshot?.quotaResetDate != nil ? relativeTime(to: snapshot!.quotaResetDate!) : "None",
                    isTruthful: snapshot?.quotaResetDate != nil
                )
            }
            
            // Status Message or Warning Banner
            if let msg = snapshot?.statusMessage, !msg.isEmpty, snapshot?.isAvailable == false {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(msg)
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.1)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func metricBox(title: String, value: String, isTruthful: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(isTruthful ? themeManager.primaryTextColor : themeManager.secondaryTextColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    @ViewBuilder
    private func statusBadge(for snapshot: AIUsageSnapshot?) -> some View {
        let (color, text): (Color, String) = {
            guard let snap = snapshot else {
                return (.secondary, "Offline")
            }
            if snap.isAvailable {
                return (.green, "Healthy")
            } else {
                return (.orange, snap.statusMessage.isEmpty ? "Unavailable" : snap.statusMessage)
            }
        }()
        
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 0.5))
    }
    
    private func loadUsageHistory() {
        let history = UsageRepository.shared.fetchDailyUsage(days: 7)
        if !history.isEmpty {
            self.dailyHistory = history
        } else {
            let calendar = Calendar.current
            let today = Date()
            var generated: [(day: String, requests: Int, tokens: Int)] = []
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            
            for i in (0..<7).reversed() {
                if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                    let dayName = dayFormatter.string(from: date)
                    generated.append((day: dayName, requests: 0, tokens: 0))
                }
            }
            self.dailyHistory = generated
        }
    }
    
    private func relativeTime(to date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Now" }
        let minutes = Int(interval / 60)
        return "in \(minutes)m"
    }
}
