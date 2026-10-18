import SwiftUI

/// Battery widget in expanded island.
/// Implements BATT-001, BATT-002, and BATT-003.
public struct BatteryWidgetView: View {
    @ObservedObject public var monitor: BatteryMonitor
    public let customState: BatteryState?
    
    public init(state: BatteryState? = nil, monitor: BatteryMonitor? = nil) {
        self.customState = state
        self.monitor = monitor ?? BatteryMonitor.shared
    }
    
    private var state: BatteryState {
        customState ?? monitor.currentState
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            if !state.hasBattery {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Power Source")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Connected to AC (No Battery)")
                        .font(.system(size: 13, weight: .medium))
                }
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 4)
                        .frame(width: 38, height: 38)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(state.percentage) / 100.0)
                        .stroke(
                            state.isLowBattery ? Color.red : (state.isCharging ? Color.green : Color.accentColor),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 38, height: 38)
                    
                    if state.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    } else {
                        Text("\(state.percentage)%")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(state.isCharging ? "Charging" : (state.isLowBattery ? "Low Battery" : "Battery"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(state.isLowBattery ? .red : .primary)
                        
                        Text("\(state.percentage)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if let mins = state.timeRemainingMinutes {
                        Text(state.isCharging ? "\(mins / 60)h \(mins % 60)m until full" : "\(mins / 60)h \(mins % 60)m remaining")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text(state.isCharging ? "Calculating full charge time..." : "Calculating remaining time...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }
}
