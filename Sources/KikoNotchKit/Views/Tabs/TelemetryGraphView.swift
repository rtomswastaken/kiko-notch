import SwiftUI
import AppKit

/// A lightweight, monochrome 60-second hardware telemetry live graph.
/// Designed for minimal CPU overhead using SwiftUI Canvas rendering.
/// Accurately respects missing / unavailable samples without connecting invalid points or fabricating values.
public struct TelemetryGraphView: View {
    public let samples: [TimestampedSample]
    public let isAvailable: Bool
    public let unavailableReason: String?
    public let windowSeconds: TimeInterval
    public let maxValue: Double
    public let unit: String
    public let strokeColor: Color
    public let colors: [Color]?
    public let height: CGFloat
    
    @ObservedObject private var accentTheme = AccentThemeManager.shared

    public init(
        samples: [TimestampedSample],
        isAvailable: Bool = true,
        unavailableReason: String? = nil,
        windowSeconds: TimeInterval = 60.0,
        maxValue: Double = 100.0,
        unit: String = "%",
        strokeColor: Color = .white,
        colors: [Color]? = nil,
        height: CGFloat = 48.0
    ) {
        self.samples = samples
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.windowSeconds = max(1.0, windowSeconds)
        self.maxValue = max(1.0, maxValue)
        self.unit = unit
        self.strokeColor = strokeColor
        self.colors = colors
        self.height = height
    }
    
    public var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Background & Grid Lines
                Canvas { context, size in
                    let h = size.height
                    let w = size.width
                    
                    // Top guideline (100%)
                    var topPath = Path()
                    topPath.move(to: CGPoint(x: 0, y: 1))
                    topPath.addLine(to: CGPoint(x: w, y: 1))
                    context.stroke(topPath, with: .color(Color.white.opacity(0.06)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    
                    // Mid guideline (50%)
                    var midPath = Path()
                    midPath.move(to: CGPoint(x: 0, y: h / 2.0))
                    midPath.addLine(to: CGPoint(x: w, y: h / 2.0))
                    context.stroke(midPath, with: .color(Color.white.opacity(0.04)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    
                    // Bottom guideline (0%)
                    var botPath = Path()
                    botPath.move(to: CGPoint(x: 0, y: h - 1))
                    botPath.addLine(to: CGPoint(x: w, y: h - 1))
                    context.stroke(botPath, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)
                }
                
                if !isAvailable {
                    // Unavailable State Indicator
                    VStack(spacing: 2) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                        Text(unavailableReason ?? "Telemetry unavailable")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if samples.isEmpty || samples.allSatisfy({ $0.value == nil }) {
                    // Waiting for initial data
                    Text("Awaiting telemetry...")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                } else {
                    // Live Graph Canvas
                    Canvas { context, size in
                        let w = size.width
                        let h = size.height
                        let now = Date()
                        let startTime = now.addingTimeInterval(-windowSeconds)
                        
                        // Break samples into contiguous segments of valid (non-nil) readings
                        var segments: [[(x: CGFloat, y: CGFloat)]] = []
                        var currentSegment: [(x: CGFloat, y: CGFloat)] = []
                        
                        for sample in samples {
                            guard sample.timestamp >= startTime else { continue }
                            guard let val = sample.value else {
                                if !currentSegment.isEmpty {
                                    segments.append(currentSegment)
                                    currentSegment = []
                                }
                                continue
                            }
                            
                            let timeOffset = sample.timestamp.timeIntervalSince(startTime)
                            let progress = CGFloat(max(0.0, min(windowSeconds, timeOffset)) / windowSeconds)
                            let x = progress * w
                            let normalized = CGFloat(max(0.0, min(maxValue, val)) / maxValue)
                            let y = h - (normalized * (h - 4.0)) - 2.0
                            
                            currentSegment.append((x: x, y: y))
                        }
                        
                        if !currentSegment.isEmpty {
                            segments.append(currentSegment)
                        }
                        
                        let effectiveColors = colors ?? (accentTheme.isDefaultWhite ? [strokeColor, strokeColor] : accentTheme.colors)

                        // Draw line segments and gradient fill
                        for segment in segments {
                            guard !segment.isEmpty else { continue }
                            
                            var linePath = Path()
                            linePath.move(to: CGPoint(x: segment[0].x, y: segment[0].y))
                            for pt in segment.dropFirst() {
                                linePath.addLine(to: CGPoint(x: pt.x, y: pt.y))
                            }
                            
                            // Fill area under curve
                            var fillPath = linePath
                            if let last = segment.last, let first = segment.first {
                                fillPath.addLine(to: CGPoint(x: last.x, y: h))
                                fillPath.addLine(to: CGPoint(x: first.x, y: h))
                                fillPath.closeSubpath()
                                
                                let fillGrad = Gradient(colors: [
                                    effectiveColors.first?.opacity(0.20) ?? strokeColor.opacity(0.18),
                                    effectiveColors.last?.opacity(0.02) ?? strokeColor.opacity(0.01)
                                ])
                                context.fill(fillPath, with: .linearGradient(fillGrad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
                            }
                            
                            // Stroke line with dynamic horizontal accent gradient
                            let strokeGrad = Gradient(colors: effectiveColors)
                            context.stroke(
                                linePath,
                                with: .linearGradient(strokeGrad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0)),
                                lineWidth: 1.25
                            )
                        }
                    }
                }
            }
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5))
            
            // X-Axis Time Labels
            HStack {
                Text("-60s")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                Spacer()
                Text("Now")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 2)
        }
    }
}
