import SwiftUI

/// Compact circular progress indicator for an AI subscription quota window or token gauge.
/// Adheres strictly to Kiko Notch visual design system: neutral track and configurable accent color.
/// Accurately renders active percentage, verified token usage, loading, stale, auth-required,
/// unavailable, unsupported, and error states without ever fabricating data.
public struct CircularQuotaRingView: View {
    public let metric: AIQuotaMetric
    public let size: CGFloat
    
    @State private var isHovering: Bool = false
    
    public init(metric: AIQuotaMetric, size: CGFloat = 48.0) {
        self.metric = metric
        self.size = size
    }
    
    public var body: some View {
        VStack(spacing: 3) {
            // Label above ring (e.g. "5-HOUR", "WEEKLY", "MONTHLY")
            Text(metric.windowLabel)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DesignTokens.secondaryText)
                .tracking(0.5)
            
            // Circular Ring with Center Content
            ZStack {
                // Background Track
                Circle()
                    .stroke(
                        DesignTokens.trackBackground,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                
                switch metric.status {
                case .active, .tokenUsage:
                    if let percent = metric.remainingPercent {
                        // Visual progress ring representing tokens / quota left with dynamic multi-color gradient
                        Circle()
                            .trim(from: 0.0, to: CGFloat(percent))
                            .stroke(
                                AccentThemeManager.shared.linearGradient,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: percent)

                        VStack(spacing: 0) {
                            if let remaining = metric.remainingTokens {
                                Text(compactTokenString(remaining))
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignTokens.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            } else {
                                Text("\(Int(round(percent * 100)))%")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignTokens.primaryText)
                            }
                            Text("LEFT")
                                .font(.system(size: 6.5, weight: .semibold))
                                .foregroundColor(DesignTokens.secondaryText.opacity(0.8))
                        }
                    } else {
                        // Dynamic accent ring fallback if ceiling is unknown
                        Circle()
                            .stroke(
                                AccentThemeManager.shared.borderGradient,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )

                        VStack(spacing: 0) {
                            Text(compactTokenString(metric.usedAmount ?? 0))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(DesignTokens.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text("TOKENS")
                                .font(.system(size: 6, weight: .semibold))
                                .foregroundColor(DesignTokens.secondaryText.opacity(0.8))
                        }
                    }

                case .loading:
                    Circle()
                        .stroke(
                            DesignTokens.trackBackground,
                            style: StrokeStyle(lineWidth: 2, dash: [3, 3])
                        )

                    VStack(spacing: 0) {
                        Text("···")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(DesignTokens.secondaryText)
                        Text("SYNC")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(DesignTokens.secondaryText.opacity(0.7))
                    }

                case .stale:
                    Circle()
                        .stroke(
                            Color.orange.opacity(0.6),
                            style: StrokeStyle(lineWidth: 2.5, dash: [4, 2])
                        )

                    VStack(spacing: 0) {
                        if let remaining = metric.remainingTokens {
                            Text(compactTokenString(remaining))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color.orange.opacity(0.9))
                        } else if let percent = metric.remainingPercent {
                            Text("\(Int(round(percent * 100)))%")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color.orange.opacity(0.9))
                        } else if let used = metric.usedAmount {
                            Text(compactTokenString(used))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color.orange.opacity(0.9))
                        } else {
                            Text("—")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.orange.opacity(0.8))
                        }
                        Text("STALE")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(Color.orange.opacity(0.8))
                    }
                    
                case .authRequired:
                    Circle()
                        .stroke(
                            Color.yellow.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                        )
                    
                    VStack(spacing: 0) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(Color.yellow.opacity(0.9))
                        Text("AUTH")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(Color.yellow.opacity(0.85))
                    }
                    
                case .unavailable:
                    Circle()
                        .stroke(
                            DesignTokens.trackBackground.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                        )
                    
                    VStack(spacing: 0) {
                        Text("—")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignTokens.secondaryText)
                        Text("OFFLINE")
                            .font(.system(size: 5.5, weight: .medium))
                            .foregroundColor(DesignTokens.secondaryText.opacity(0.6))
                    }
                    
                case .unsupported:
                    Circle()
                        .stroke(
                            DesignTokens.trackBackground.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                        )
                    
                    VStack(spacing: 0) {
                        Text("N/A")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignTokens.secondaryText)
                        Text("NO QUOTA")
                            .font(.system(size: 5.5, weight: .medium))
                            .foregroundColor(DesignTokens.secondaryText.opacity(0.6))
                    }
                    
                case .failed:
                    Circle()
                        .stroke(
                            Color.red.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, dash: [2, 3])
                        )
                    
                    VStack(spacing: 0) {
                        Text("ERR")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color.red.opacity(0.9))
                        Text("FAILED")
                            .font(.system(size: 5.5, weight: .bold))
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                }
            }
            .frame(width: size, height: size)
            
            // Subtitle / reset countdown below ring
            Text(sublabel)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(sublabelColor)
                .lineLimit(1)
                .frame(maxWidth: size + 16)
        }
        .help(tooltipText)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
    
    private var sublabel: String {
        switch metric.status {
        case .active, .tokenUsage:
            if let reset = metric.resetDate {
                let diff = reset.timeIntervalSinceNow
                if diff > 0 {
                    let hours = Int(diff) / 3600
                    let mins = (Int(diff) % 3600) / 60
                    return hours > 0 ? "Resets in \(hours)h" : "Resets in \(mins)m"
                }
            }
            if metric.remainingPercent != nil {
                return "Remaining"
            }
            return metric.remainingText ?? "Consumed"
            
        case .loading:
            return "Updating..."
            
        case .stale:
            return "Stale"
            
        case .authRequired:
            return "API Key"
            
        case .unavailable:
            return "Not Found"
            
        case .unsupported:
            return "No Quota API"
            
        case .failed:
            return "Error"
        }
    }
    
    private var sublabelColor: Color {
        switch metric.status {
        case .active, .tokenUsage:
            return DesignTokens.secondaryText
        case .loading:
            return DesignTokens.accentColor
        case .stale:
            return Color.orange.opacity(0.85)
        case .authRequired:
            return Color.yellow.opacity(0.85)
        case .failed:
            return Color.red.opacity(0.85)
        case .unavailable, .unsupported:
            return DesignTokens.secondaryText.opacity(0.7)
        }
    }
    
    private var tooltipText: String {
        var lines: [String] = ["\(metric.windowLabel) — Status: \(metric.status.rawValue.uppercased())"]
        
        if let remaining = metric.remainingTokens {
            lines.append("Tokens Left: \(Int(remaining).formatted())")
        }
        if let p = metric.remainingPercent {
            lines.append("Remaining Quota: \(Int(round(p * 100)))%")
        }
        if let used = metric.usedAmount {
            lines.append("Tokens Consumed: \(Int(used).formatted())")
        }
        if let total = metric.totalLimit {
            lines.append("Total Quota Limit: \(Int(total).formatted())")
        }
        if let reset = metric.resetDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lines.append("Quota Reset: \(formatter.string(from: reset))")
        }
        if !metric.statusMessage.isEmpty {
            lines.append("Details: \(metric.statusMessage)")
        }
        
        let df = DateFormatter()
        df.timeStyle = .medium
        lines.append("Last Reading: \(df.string(from: metric.lastUpdated))")
        
        return lines.joined(separator: "\n")
    }
    
    private func compactTokenString(_ count: Double) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", count / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", count / 1_000.0)
        } else {
            return "\(Int(count))"
        }
    }
}
