import SwiftUI

/// Compact coding duration and AI token statistics panel.
/// Displays Today, Last 7 Days, All-Time stats from WakaTime,
/// and Previous Calendar Month Token Usage across configured AI providers.
public struct CodingStatsView: View {
    public let stats: WakaTimeCodingStats
    public let tokenUsageText: String
    public let tokenMonthLabel: String
    public let tokenProviders: [String]
    
    public init(
        stats: WakaTimeCodingStats,
        tokenUsageText: String,
        tokenMonthLabel: String = "PREVIOUS MONTH",
        tokenProviders: [String] = []
    ) {
        self.stats = stats
        self.tokenUsageText = tokenUsageText
        self.tokenMonthLabel = tokenMonthLabel
        self.tokenProviders = tokenProviders
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Item 1: TODAY
                statItem(
                    label: "TODAY",
                    value: stats.todayText,
                    tooltip: "Coding time logged today via WakaTime"
                )
                
                // Item 2: 7 DAYS
                statItem(
                    label: "7 DAYS",
                    value: stats.last7DaysText,
                    tooltip: "Aggregated coding time for past 7 days"
                )
            }
            
            HStack(spacing: 12) {
                // Item 3: ALL-TIME
                statItem(
                    label: "ALL-TIME",
                    value: stats.allTimeText,
                    tooltip: "Total cumulative coding time from WakaTime account"
                )
                
                // Item 4: PREVIOUS MONTH TOKEN USAGE
                statItem(
                    label: tokenMonthLabel,
                    value: tokenUsageText,
                    tooltip: tokenTooltip
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(DesignTokens.subtleBorder, lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func statItem(label: String, value: String, tooltip: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundColor(DesignTokens.secondaryText)
                .tracking(0.3)
                .lineLimit(1)
            
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(tooltip)
    }
    
    private var tokenTooltip: String {
        if tokenProviders.isEmpty {
            return "Previous calendar month token usage: \(tokenUsageText)"
        }
        return "Previous calendar month token usage: \(tokenUsageText)\nAggregated from: \(tokenProviders.joined(separator: ", "))"
    }
}
