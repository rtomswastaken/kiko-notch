import SwiftUI

/// Settings view for clipboard history retention and privacy controls.
/// Implements CLIP-004 and PRIV-002.
public struct ClipboardSettingsView: View {
    @ObservedObject public var clipboardManager: ClipboardManager
    @AppStorage("kiko.clipboard.enabled") private var clipboardEnabled: Bool = true
    @AppStorage("kiko.clipboard.capacity") private var maxCapacity: Int = 50
    @AppStorage("kiko.clipboard.ignorePasswords") private var ignorePasswords: Bool = true
    @State private var showingClearAlert = false
    
    public init(clipboardManager: ClipboardManager? = nil) {
        self.clipboardManager = clipboardManager ?? ClipboardManager.shared
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Clipboard Tracking")) {
                Toggle("Enable Clipboard History", isOn: $clipboardEnabled)
                    .onChange(of: clipboardEnabled) { enabled in
                        if enabled {
                            clipboardManager.start()
                        } else {
                            clipboardManager.stop()
                        }
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Retention Limit")
                        Spacer()
                        Text("\(maxCapacity) clips")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(maxCapacity) },
                        set: {
                            maxCapacity = Int($0)
                            ClipboardStorage.shared.maxCapacity = Int($0)
                        }
                    ), in: 10...100, step: 5)
                }
            }
            
            Section(header: Text("Privacy & Security")) {
                Toggle("Ignore Passwords & Concealed Data", isOn: $ignorePasswords)
                    .help("Ignores clips flagged with org.nspasteboard.ConcealedType (1Password, Bitwarden, Keychain).")
                
                Text("All clipboard items are stored exclusively in memory and local encrypted storage. Clipboard data is never uploaded, tracked, or sent to external servers.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button(role: .destructive, action: {
                    showingClearAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Clipboard History Now")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Clear Clipboard History?", isPresented: $showingClearAlert) {
            Button("Clear All", role: .destructive) {
                clipboardManager.clearAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately delete all stored clipboard snippets from memory and local storage.")
        }
    }
}
