import SwiftUI
import AppKit

/// Compact horizontal icon-based navigation bar for the expanded Kiko Notch Island
public struct IslandNavigationBar: View {
    @ObservedObject public var navigation = IslandNavigationModel.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @Binding public var isPinned: Bool
    public var onCollapse: () -> Void
    
    public init(
        isPinned: Binding<Bool>,
        onCollapse: @escaping () -> Void
    ) {
        self._isPinned = isPinned
        self.onCollapse = onCollapse
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Brand Mark
            HStack(spacing: 6) {
                BrandAssets.MonochromeLogoView(size: 15, color: themeManager.primaryTextColor)
                
                Text(BrandAssets.appName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.primaryTextColor)
            }
            .padding(.trailing, 2)
            
            Spacer(minLength: 4)
            
            // Tab Strip Container
            HStack(spacing: 3) {
                ForEach(IslandTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            
            Spacer(minLength: 4)
            
            // Trailing Controls (Pin & Collapse)
            HStack(spacing: 4) {
                Button(action: {
                    isPinned.toggle()
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundColor(isPinned ? .accentColor : themeManager.secondaryTextColor)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(isPinned ? 0.12 : 0.04)))
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin Island" : "Pin Island Open")
                .accessibilityLabel(isPinned ? "Unpin Island" : "Pin Island Open")
                
                Button(action: onCollapse) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help("Collapse Island")
                .accessibilityLabel("Collapse Island")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private func tabButton(for tab: IslandTab) -> some View {
        let isActive = navigation.activeTab == tab
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                navigation.selectTab(tab)
            }
        }) {
            ZStack {
                if isActive {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.5)
                        )
                }
                
                Image(systemName: tab.iconName)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : themeManager.secondaryTextColor.opacity(0.75))
                    .frame(width: 22, height: 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
        .accessibilityLabel(tab.rawValue)
    }
}
