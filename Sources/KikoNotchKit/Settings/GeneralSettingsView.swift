import SwiftUI
import ServiceManagement
import AppKit

/// General application preferences tab consolidating startup, dock presence,
/// display targeting, interaction delays, file shelf handoff, and macOS permissions.
public struct GeneralSettingsView: View {
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var lifecycle = AppLifecycle.shared
    @ObservedObject public var displayManager = DisplayManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var calendarService = CalendarService.shared

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Startup & Dock Presence
            Section {
                Toggle("Launch Kiko Notch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { enabled in
                        settings.launchAtLogin = enabled
                        applyLaunchAtLogin(enabled)
                    }
                ))
                .accessibilityLabel("Launch Kiko Notch at Login")

                Toggle("Show Icon in Dock", isOn: $lifecycle.showInDock)
                    .accessibilityLabel("Show Kiko Notch icon in Dock")

                Toggle("Exclude Island from Screen Capture", isOn: $settings.hideFromScreenCapture)
                    .accessibilityLabel("Exclude Island from Screen Capture")
                    .help("When enabled, screenshots and screen recordings will not capture the floating island.")
            } header: {
                Text("Startup & Dock")
                    .font(.headline)
            }

            // MARK: - Island Interaction Behavior
            Section {
                Toggle("Open Island on Pointer Hover", isOn: $settings.openOnHover)
                    .help("Automatically expands the island when hovering over the notch area.")

                if settings.openOnHover {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hover Expand Delay")
                            Spacer()
                            Text("\(settings.hoverDelayMs) ms")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.hoverDelayMs) },
                                set: { settings.hoverDelayMs = Int($0) }
                            ),
                            in: 50...600,
                            step: 50
                        )
                    }
                    .accessibilityLabel("Hover expand delay \(settings.hoverDelayMs) milliseconds")
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Mouse Exit Collapse Delay")
                        Spacer()
                        Text("\(settings.collapseDelayMs) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.collapseDelayMs) },
                            set: { settings.collapseDelayMs = Int($0) }
                        ),
                        in: 100...1000,
                        step: 50
                    )
                }
                .accessibilityLabel("Mouse exit collapse delay \(settings.collapseDelayMs) milliseconds")
            } header: {
                Text("Interaction Delays")
                    .font(.headline)
            }

            // MARK: - Display & Placement
            Section {
                Picker("Target Display", selection: Binding(
                    get: { settings.preferredScreenIndex },
                    set: { index in
                        displayManager.selectScreen(at: index)
                    }
                )) {
                    ForEach(0..<displayManager.screens.count, id: \.self) { idx in
                        let screen = displayManager.screens[idx]
                        Text("\(displayManager.displayName(for: screen))\(idx == 0 ? " (Main)" : "")")
                            .tag(idx)
                    }
                }

                let screen = displayManager.activeScreen
                LabeledContent("Display Resolution", value: "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) pt")
                LabeledContent("Hardware Notch", value: displayManager.hasPhysicalNotch ? "Detected" : "None (Simulated Island)")

                if !displayManager.hasPhysicalNotch {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Top Bezel Offset")
                            Spacer()
                            Text("\(Int(themeManager.geometry.nonNotchOffsetY)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $themeManager.geometry.nonNotchOffsetY,
                            in: IslandGeometry.minNonNotchOffsetY...IslandGeometry.maxNonNotchOffsetY,
                            step: 1
                        )
                    }
                    .help("Adjust the vertical offset of the floating island on displays without a physical notch.")
                }
            } header: {
                Text("Display & Placement")
                    .font(.headline)
            }

            // MARK: - File Shelf Handoff
            Section {
                Picker("Drop Action", selection: $settings.sendDestinationType) {
                    Text("AirDrop (Default)").tag(SendDestinationType.airDrop)
                    if FileSenderService.shared.findBlipApplication() != nil {
                        Text("Blip").tag(SendDestinationType.blip)
                    } else {
                        Text("Blip (Not Installed)").tag(SendDestinationType.blip)
                    }
                    Text("Custom Application…").tag(SendDestinationType.customApp)
                }
                .accessibilityLabel("File Shelf Send Destination")

                if settings.sendDestinationType == .customApp {
                    HStack(spacing: 8) {
                        if let customURL = settings.customSendAppURL,
                           FileManager.default.fileExists(atPath: customURL.path) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: customURL.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                            let appName = (try? customURL.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                                ?? customURL.deletingPathExtension().lastPathComponent
                            Text(appName)
                                .font(.system(size: 12, weight: .medium))
                        } else {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("No application selected")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Choose…") {
                            selectCustomApplication()
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("File Shelf Handoff")
                    .font(.headline)
            } footer: {
                Text(destinationFooterText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - System Permissions & Integrations
            Section {
                HStack {
                    Label("Calendar Access", systemImage: "calendar")
                    Spacer()
                    calendarStatusBadge
                }

                if calendarService.authStatus != .authorized {
                    HStack {
                        Text("Required for next event countdown on Home tab.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if calendarService.authStatus == .notDetermined {
                            Button("Grant Access") {
                                Task { await calendarService.requestAccess() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button("Open Settings…") {
                                openCalendarPrivacySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text("System Permissions")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    @ViewBuilder
    private var calendarStatusBadge: some View {
        switch calendarService.authStatus {
        case .authorized:
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Authorized").font(.system(size: 11, weight: .medium)).foregroundColor(.green)
            }
        case .denied:
            HStack(spacing: 4) {
                Circle().fill(Color.red).frame(width: 6, height: 6)
                Text("Denied").font(.system(size: 11, weight: .medium)).foregroundColor(.red)
            }
        case .restricted:
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Restricted").font(.system(size: 11, weight: .medium)).foregroundColor(.orange)
            }
        case .notDetermined:
            HStack(spacing: 4) {
                Circle().fill(Color.secondary).frame(width: 6, height: 6)
                Text("Not Requested").font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
    }

    private func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func selectCustomApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Select"
        panel.title = "Select Application for File Handoff"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            settings.customSendAppURL = selectedURL
        }
    }

    private var destinationFooterText: String {
        switch settings.sendDestinationType {
        case .airDrop:
            return "Files dropped on the Sending Container will be shared via macOS AirDrop."
        case .blip:
            return "Files dropped on the Sending Container will be handed off to the Blip desktop app."
        case .customApp:
            return "Files dropped on the Sending Container will be opened directly in the selected application."
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[Kiko Notch] Error updating SMAppService: \(error.localizedDescription)")
            }
        }
    }
}
