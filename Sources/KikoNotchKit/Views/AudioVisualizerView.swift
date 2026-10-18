import SwiftUI

/// Animated audio equalizer visualizer bars tied to playback state with zero idle CPU
public struct AudioVisualizerView: View {
    public var isPlaying: Bool
    public var barCount: Int
    public var barWidth: CGFloat
    public var maxHeight: CGFloat
    public var color: Color
    
    @State private var barHeights: [CGFloat]
    @State private var timer: Timer?
    
    public init(
        isPlaying: Bool,
        barCount: Int = 4,
        barWidth: CGFloat = 2.5,
        maxHeight: CGFloat = 14.0,
        color: Color = .accentColor
    ) {
        self.isPlaying = isPlaying
        self.barCount = barCount
        self.barWidth = barWidth
        self.maxHeight = maxHeight
        self.color = color
        self._barHeights = State(initialValue: Array(repeating: 3.0, count: barCount))
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: barWidth, height: idx < barHeights.count ? barHeights[idx] : 3.0)
                    .animation(.easeInOut(duration: 0.18), value: barHeights)
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            manageAnimationTimer(isPlaying: isPlaying)
        }
        .onChange(of: isPlaying) { playing in
            manageAnimationTimer(isPlaying: playing)
        }
        .onDisappear {
            stopTimer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Audio playing visualizer active" : "Audio paused")
    }
    
    private func manageAnimationTimer(isPlaying: Bool) {
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
            // Reset to idle baseline
            barHeights = Array(repeating: 3.0, count: barCount)
        }
    }
    
    private func startTimer() {
        stopTimer()
        // Low frequency 8Hz update for smooth visualizer without eating CPU
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            var newHeights: [CGFloat] = []
            for i in 0..<barCount {
                // Spectral simulation curve: higher activity in middle/low frequencies
                let minH: CGFloat = 3.0
                let factor = sin(Double(i) * 0.8 + Date().timeIntervalSince1970 * 5.0)
                let randomBonus = CGFloat.random(in: 0.0...1.0)
                let height = minH + (maxHeight - minH) * max(0.1, min(1.0, CGFloat(abs(factor)) * 0.6 + randomBonus * 0.4))
                newHeights.append(height)
            }
            self.barHeights = newHeights
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
