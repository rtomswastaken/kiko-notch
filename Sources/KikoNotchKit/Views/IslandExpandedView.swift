import SwiftUI
import AppKit

/// Expanded interactive panel revealing active widgets, controls, and modules
public struct IslandExpandedView: View {
    @ObservedObject public var interactionManager = InteractionManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var mediaController = MediaController.shared
    
    private var customIsPinned: Binding<Bool>?
    private var onCollapse: (() -> Void)?
    private var onOpenSettings: (() -> Void)?
    
    public init(
        isPinned: Binding<Bool>? = nil,
        onCollapse: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.customIsPinned = isPinned
        self.onCollapse = onCollapse
        self.onOpenSettings = onOpenSettings
    }
    
    private var isPinned: Bool {
        customIsPinned?.wrappedValue ?? interactionManager.isPinned
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack(spacing: 8) {
                BrandAssets.MonochromeLogoView(size: 14, color: themeManager.primaryTextColor)
                
                Text(BrandAssets.appName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                // Pin Button
                Button {
                    if let binding = customIsPinned {
                        binding.wrappedValue.toggle()
                    } else {
                        interactionManager.isPinned.toggle()
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundColor(isPinned ? .accentColor : themeManager.secondaryTextColor)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin island" : "Pin island open")
                
                // Settings Button
                Button {
                    if let open = onOpenSettings {
                        open()
                    } else {
                        SettingsWindowController.shared.showSettings()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
                
                // Collapse Button
                Button {
                    if let collapse = onCollapse {
                        collapse()
                    } else {
                        interactionManager.transition(to: .collapsed)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse island")
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            // Dynamic Modular Body according to Layout Configuration
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(themeManager.layout.visibleModules, id: \.self) { slot in
                        renderModule(slot)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity)
        .onExitCommand {
            // Escape key dismisses island (ACC-002)
            if !isPinned {
                if let collapse = onCollapse {
                    collapse()
                } else {
                    interactionManager.transition(to: .collapsed)
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderModule(_ slot: LayoutConfiguration.ModuleSlot) -> some View {
        switch slot {
        case .media:
            if SettingsManager.shared.isFeatureEnabled(.media) {
                MediaWidgetView()
            }
        case .fileShelf:
            if SettingsManager.shared.isFeatureEnabled(.fileShelf) {
                FileShelfView()
            }
        case .quickActions:
            if SettingsManager.shared.isFeatureEnabled(.customActions) {
                CustomActionButtonsView(
                    isPinned: customIsPinned ?? $interactionManager.isPinned,
                    onOpenSettings: {
                        if let open = onOpenSettings {
                            open()
                        } else {
                            SettingsWindowController.shared.showSettings()
                        }
                    },
                    onToggleShelf: {
                        themeManager.layout.toggleVisibility(for: .fileShelf)
                    }
                )
            }
        case .aiStatus:
            if SettingsManager.shared.isFeatureEnabled(.aiDashboard) {
                AIDashboardView()
            }
        case .systemStatus:
            VStack(spacing: 10) {
                if SettingsManager.shared.isFeatureEnabled(.battery) {
                    BatteryWidgetView()
                }
                if SettingsManager.shared.isFeatureEnabled(.weather) {
                    WeatherWidgetView()
                }
                if SettingsManager.shared.isFeatureEnabled(.calendar) || SettingsManager.shared.isFeatureEnabled(.reminders) {
                    CalendarWidgetView()
                }
                if SettingsManager.shared.isFeatureEnabled(.clipboard) {
                    ClipboardWidgetView()
                }
                if SettingsManager.shared.isFeatureEnabled(.systemHUD) {
                    SystemStatusPreviewCard()
                }
            }
        }
    }
}

/// Clean integration card placeholder for AI status
private struct AIStatusPreviewCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Google Antigravity")
                    .font(.system(size: 11, weight: .semibold))
                Text("Active AI Companion")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Ready")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.12)))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

/// Clean integration card placeholder for System status
private struct SystemStatusPreviewCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Label("System HUDs", systemImage: "slider.horizontal.3")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Label("Active", systemImage: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
