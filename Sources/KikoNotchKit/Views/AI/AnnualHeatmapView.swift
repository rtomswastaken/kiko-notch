import SwiftUI

/// GitHub-style annual coding activity heatmap representing the past 365 days
/// powered by authoritative WakaTime daily data.
/// Uses the configured accent color to dynamically render intensity shades.
public struct AnnualHeatmapView: View {
    public let activities: [WakaTimeDayActivity]
    public let isConnected: Bool
    
    @State private var hoveredDay: WakaTimeDayActivity?
    @State private var selectedDay: WakaTimeDayActivity?
    
    private let columnsCount = 53
    private let rowsCount = 7
    private let cellSize: CGFloat = 7.5
    private let cellSpacing: CGFloat = 2.0
    private let weekdays = ["", "M", "", "W", "", "F", ""]
    
    public init(activities: [WakaTimeDayActivity], isConnected: Bool) {
        self.activities = activities
        self.isConnected = isConnected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header Row: Section Title + Legend or Hover Details
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("CODING ACTIVITY — LAST 365 DAYS")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(DesignTokens.secondaryText)
                        .tracking(0.5)
                    
                    if let active = hoveredDay ?? selectedDay {
                        Text("•  \(active.dateString): \(active.humanReadableText)")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(DesignTokens.primaryText)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                }
                
                Spacer()
                
                // Intensity Legend
                HStack(spacing: 3) {
                    Text("Less")
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(DesignTokens.secondaryText)
                    
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(DesignTokens.intensityColor(level: level))
                            .frame(width: 7, height: 7)
                    }
                    
                    Text("More")
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(DesignTokens.secondaryText)
                }
            }
            
            // Heatmap Grid Container
            HStack(alignment: .top, spacing: 4) {
                // Weekday Labels Column (M, W, F)
                VStack(spacing: cellSpacing) {
                    ForEach(0..<rowsCount, id: \.self) { row in
                        Text(weekdays[row])
                            .font(.system(size: 6.5, weight: .semibold))
                            .foregroundColor(DesignTokens.secondaryText.opacity(0.8))
                            .frame(width: 10, height: cellSize, alignment: .trailing)
                    }
                }
                
                // Days Grid (Columns of Weeks)
                if !isConnected && activities.isEmpty {
                    // Empty / Unconnected State placeholder
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<columnsCount, id: \.self) { _ in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<rowsCount, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.white.opacity(0.04))
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                    .overlay(
                        Text("Connect WakaTime in Settings to track annual coding activity")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(DesignTokens.secondaryText)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.85))
                            )
                    )
                } else {
                    // Actual Populated Activity Grid
                    let grid = buildWeeksGrid()
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<grid.count, id: \.self) { colIdx in
                            let week = grid[colIdx]
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<rowsCount, id: \.self) { rowIdx in
                                    if rowIdx < week.count, let day = week[rowIdx] {
                                        dayCell(for: day)
                                    } else {
                                        Color.clear
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
    private func dayCell(for day: WakaTimeDayActivity) -> some View {
        let isHovered = hoveredDay?.dateString == day.dateString
        let isSelected = selectedDay?.dateString == day.dateString
        let baseColor = DesignTokens.intensityColor(level: day.intensityLevel, isMissing: !day.isAvailable)
        
        RoundedRectangle(cornerRadius: 1.5)
            .fill(baseColor)
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 1.5)
                    .stroke(
                        isSelected ? DesignTokens.accentColor : (isHovered ? Color.white.opacity(0.9) : Color.clear),
                        lineWidth: isSelected ? 1.0 : 0.6
                    )
            )
            .contentShape(Rectangle())
            .help(tooltip(for: day))
            .onHover { inside in
                hoveredDay = inside ? day : nil
            }
            .onTapGesture {
                selectedDay = (selectedDay?.dateString == day.dateString) ? nil : day
            }
    }
    
    private func tooltip(for day: WakaTimeDayActivity) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: day.date)
        if !day.isAvailable {
            return "\(dateStr): No historical data"
        }
        return "\(dateStr): \(day.humanReadableText)"
    }
    
    /// Organizes 365 days into week columns matching weekday rows
    private func buildWeeksGrid() -> [[WakaTimeDayActivity?]] {
        guard !activities.isEmpty else { return [] }
        
        var weeks: [[WakaTimeDayActivity?]] = []
        let calendar = Calendar.current
        
        // Find weekday of first day (1 = Sunday ... 7 = Saturday)
        guard let firstDay = activities.first else { return [] }
        let weekday = calendar.component(.weekday, from: firstDay.date)
        let startingRow = (weekday + 5) % 7 // Monday = 0, ..., Sunday = 6
        
        var currentWeek: [WakaTimeDayActivity?] = Array(repeating: nil, count: startingRow)
        
        for day in activities {
            currentWeek.append(day)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        return weeks
    }
}
