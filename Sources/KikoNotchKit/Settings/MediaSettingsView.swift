import SwiftUI

/// Media controls and audio settings tab
public struct MediaSettingsView: View {
    @ObservedObject public var mediaController = MediaController.shared
    @ObservedObject public var audioManager = AudioDeviceManager.shared
    @ObservedObject public var settings = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                Toggle("Enable Media Player Integration", isOn: Binding(
                    get: { settings.isFeatureEnabled(.media) },
                    set: { _ in settings.toggleFeature(.media) }
                ))
                
                let meta = mediaController.currentMedia
                LabeledContent("Active Player", value: meta.playerApp)
                LabeledContent("Status", value: meta.isPlaying ? "Playing: \(meta.displayTitle)" : "Paused / Stopped")
            } header: {
                Text("Media Integration")
                    .font(.headline)
            }
            
            Section {
                // Audio Output Device Selection
                Picker("Default Audio Output", selection: Binding(
                    get: { audioManager.defaultOutputDevice?.id ?? 0 },
                    set: { newID in
                        audioManager.setDefaultOutputDevice(deviceID: newID)
                    }
                )) {
                    ForEach(audioManager.outputDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                
                Button("Refresh Audio Devices") {
                    audioManager.refreshDevices()
                }
            } header: {
                Text("Audio Output")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}
