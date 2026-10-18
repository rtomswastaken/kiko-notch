import SwiftUI
import AppKit

/// Dedicated In-Island Settings Tab View
public struct SettingsTabView: View {
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @State private var selectedSection: SettingsSection = .general
    
    public enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case displays = "Displays"
        case features = "Features"
        case providers = "AI Providers"
        case media = "Media"
        case about = "About"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .general: return "gearshape.fill"
            case .appearance: return "paintbrush.fill"
            case .displays: return "display"
            case .features: return "switch.2"
            case .providers: return "sparkles"
            case .media: return "music.note"
            case .about: return "info.circle.fill"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Horizontal Section Selector & Full Settings Launch Button
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(SettingsSection.allCases) { section in
                            sectionButton(for: section)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                        Text("Window")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Open Full Settings Window")
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // Section Content Body
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    switch selectedSection {
                    case .general:
                        GeneralSettingsView()
                    case .appearance:
                        AppearanceSettingsView()
                    case .displays:
                        DisplaySettingsView()
                    case .features:
                        FeatureToggleSettingsView()
                    case .providers:
                        AIProvidersSettingsView()
                    case .media:
                        MediaSettingsView()
                    case .about:
                        AboutSettingsView()
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
    }
    
    @ViewBuilder
    private func sectionButton(for section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: section.iconName)
                    .font(.system(size: 10))
                Text(section.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : themeManager.secondaryTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.white.opacity(0.16))
                    } else {
                        Capsule().fill(Color.white.opacity(0.04))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}
