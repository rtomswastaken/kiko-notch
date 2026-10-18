import SwiftUI

/// Settings view for AI Providers and Keychain Token management.
/// Implements AI-ANTIGRAVITY-004, AI-CODEX-001, AI-CLAUDE-001, and SEC-001.
public struct AIProvidersSettingsView: View {
    @ObservedObject public var scheduler: RefreshScheduler
    @ObservedObject public var settings = SettingsManager.shared
    
    @State private var codexKeyInput: String = ""
    @State private var claudeKeyInput: String = ""
    @State private var hasSavedCodexKey: Bool = false
    @State private var hasSavedClaudeKey: Bool = false
    @State private var saveStatusMessage: String?
    
    public init(scheduler: RefreshScheduler? = nil) {
        self.scheduler = scheduler ?? RefreshScheduler.shared
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Refresh & Sync")) {
                Picker("Sync Interval", selection: $scheduler.interval) {
                    ForEach(AIRefreshInterval.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                
                if let last = scheduler.lastSyncDate {
                    HStack {
                        Text("Last Synced:")
                        Spacer()
                        Text(last.formatted(date: .omitted, time: .standard))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 1. Google Antigravity (Primary)
            Section(header: Text("Google Antigravity (Primary)")) {
                Toggle("Enable Antigravity Provider", isOn: Binding(
                    get: { settings.isAIProviderEnabled(.antigravity) },
                    set: { _ in settings.toggleAIProvider(.antigravity) }
                ))
                
                Text("Enabled out-of-the-box. Reads local environment and session metadata directly from ~/.gemini/antigravity. Zero telemetry or external tracking.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // 2. OpenAI Codex (Optional)
            Section(header: Text("OpenAI Codex (Optional)")) {
                Toggle("Enable OpenAI Codex", isOn: Binding(
                    get: { settings.isAIProviderEnabled(.codex) },
                    set: { _ in settings.toggleAIProvider(.codex) }
                ))
                
                if settings.isAIProviderEnabled(.codex) {
                    SecureField("OpenAI API Key (sk-...)", text: $codexKeyInput)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("Save Key to Keychain") {
                            guard !codexKeyInput.isEmpty else { return }
                            KeychainHelper.shared.save(key: CodexProvider.keychainKey, value: codexKeyInput)
                            hasSavedCodexKey = true
                            codexKeyInput = ""
                            saveStatusMessage = "Codex API Key saved securely to macOS Keychain."
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        if hasSavedCodexKey {
                            Button("Remove Key") {
                                KeychainHelper.shared.delete(key: CodexProvider.keychainKey)
                                hasSavedCodexKey = false
                                saveStatusMessage = "Codex API Key removed from Keychain."
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            // 3. Anthropic Claude (Optional)
            Section(header: Text("Anthropic Claude (Optional)")) {
                Toggle("Enable Anthropic Claude", isOn: Binding(
                    get: { settings.isAIProviderEnabled(.claude) },
                    set: { _ in settings.toggleAIProvider(.claude) }
                ))
                
                if settings.isAIProviderEnabled(.claude) {
                    SecureField("Anthropic API Key (sk-ant-...)", text: $claudeKeyInput)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("Save Key to Keychain") {
                            guard !claudeKeyInput.isEmpty else { return }
                            KeychainHelper.shared.save(key: ClaudeProvider.keychainKey, value: claudeKeyInput)
                            hasSavedClaudeKey = true
                            claudeKeyInput = ""
                            saveStatusMessage = "Claude API Key saved securely to macOS Keychain."
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        if hasSavedClaudeKey {
                            Button("Remove Key") {
                                KeychainHelper.shared.delete(key: ClaudeProvider.keychainKey)
                                hasSavedClaudeKey = false
                                saveStatusMessage = "Claude API Key removed from Keychain."
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    Text("Also supports local Claude Code CLI inspection if ~/.claude directory is present.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            if let msg = saveStatusMessage {
                Section {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            hasSavedCodexKey = (KeychainHelper.shared.read(key: CodexProvider.keychainKey) != nil)
            hasSavedClaudeKey = (KeychainHelper.shared.read(key: ClaudeProvider.keychainKey) != nil)
        }
    }
}
