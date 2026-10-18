import SwiftUI

/// Daily and weekly AI usage historical chart.
/// Implements AI-DASH-002 with honest empty states.
public struct UsageChartView: View {
    public let dailyData: [(day: String, requests: Int, tokens: Int)]
    
    public init(dailyData: [(day: String, requests: Int, tokens: Int)]) {
        self.dailyData = dailyData
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Activity (Past 7 Days)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let totalReqs = dailyData.reduce(0) { $0 + $1.requests }
                Text("\(totalReqs) requests")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
            
            if dailyData.isEmpty || dailyData.allSatisfy({ $0.requests == 0 && $0.tokens == 0 }) {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        Text("No historical usage data recorded yet")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                let maxVal = max(1, dailyData.map { $0.requests }.max() ?? 1)
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(dailyData, id: \.day) { entry in
                        VStack(spacing: 4) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 22, height: 50)
                                
                                let barHeight = CGFloat(entry.requests) / CGFloat(maxVal) * 50.0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                    .frame(width: 22, height: max(4, barHeight))
                            }
                            
                            Text(entry.day)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }
}
