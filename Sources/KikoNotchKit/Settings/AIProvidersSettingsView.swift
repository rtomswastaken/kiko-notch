import SwiftUI

/// Settings view for AI Providers, Keychain Token management, and WakaTime Integration.
/// Implements AI-ANTIGRAVITY-004, AI-CODEX-001, AI-CLAUDE-001, and SEC-001.
public struct AIProvidersSettingsView: View {
    @ObservedObject public var scheduler: RefreshScheduler
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var wakaTime = WakaTimeService.shared
    @ObservedObject public var registry = ProviderRegistry.shared

    // WakaTime state
    @State private var wakaKeyInput: String = ""
    @State private var wakaStatusMessage: String?
    @State private var isTestingWaka: Bool = false

    // Codex state
    @State private var codexKeyInput: String = ""
    @State private var hasSavedCodexKey: Bool = false
    @State private var isTestingCodex: Bool = false
    @State private var codexStatusMessage: String?

    // Claude state
    @State private var claudeKeyInput: String = ""
    @State private var hasSavedClaudeKey: Bool = false
    @State private var isTestingClaude: Bool = false
    @State private var claudeStatusMessage: String?

    public init(scheduler: RefreshScheduler? = nil) {
        self.scheduler = scheduler ?? RefreshScheduler.shared
    }

    public var body: some View {
        Form {
            // MARK: - WakaTime Coding Analytics Integration
            Section(header: Text("WakaTime Coding Analytics")) {
                Text("Authoritative source of truth for coding duration, 7-day stats, and 365-day activity heatmap.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    Text("Connection Status:")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(wakaTime.isConfigured ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(wakaTime.stats.status.displayText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(wakaTime.isConfigured ? .primary : .secondary)
                    }
                }

                if let last = wakaTime.lastSyncDate {
                    HStack {
                        Text("Last Synchronized:")
                        Spacer()
                        Text(last.formatted(date: .abbreviated, time: .standard))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if wakaTime.isConfigured {
                    HStack {
                        Text("Stored API Key:")
                        Spacer()
                        Text(wakaTime.maskedApiKey)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("Test Connection") {
                            testWakaTimeConnection()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTestingWaka)

                        Button("Refresh Stats") {
                            Task { await wakaTime.refresh(force: true) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Disconnect", role: .destructive) {
                            wakaTime.disconnect()
                            wakaStatusMessage = "WakaTime disconnected and credentials cleared."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    SecureField("WakaTime Secret API Key (waka_...)", text: $wakaKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Save Key to Keychain") {
                            guard !wakaKeyInput.isEmpty else { return }
                            wakaTime.saveApiKey(wakaKeyInput)
                            wakaKeyInput = ""
                            wakaStatusMessage = "WakaTime API Key saved to macOS Keychain."
                            Task {
                                await wakaTime.refresh(force: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(wakaKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Test Connection") {
                            testWakaTimeConnection(key: wakaKeyInput)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(wakaKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingWaka)
                    }
                }

                if let msg = wakaStatusMessage {
                    Text(msg)
                        .font(.system(size: 10.5))
                        .foregroundColor(msg.contains("failed") || msg.contains("Error") ? .red : .green)
                }
            }

            // MARK: - Refresh & Sync Interval
            Section(header: Text("Refresh & Synchronization")) {
                Picker("AI Sync Interval", selection: $scheduler.interval) {
                    ForEach(AIRefreshInterval.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }

                if let last = scheduler.lastSyncDate {
                    HStack {
                        Text("Last AI Poll:")
                        Spacer()
                        Text(last.formatted(date: .omitted, time: .standard))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - 1. Google Antigravity
            Section(header: Text("Google Antigravity")) {
                Toggle("Enable Antigravity Provider", isOn: Binding(
                    get: { settings.isAIProviderEnabled(.antigravity) },
                    set: { enabled in
                        if enabled {
                            settings.setAIProviderEnabled(.antigravity, enabled: true)
                        } else {
                            registry.removeProvider(.antigravity)
                        }
                    }
                ))

                Text("Zero external telemetry. Inspects local session metadata directly from ~/.gemini/antigravity.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if settings.isAIProviderEnabled(.antigravity) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Token Quota Limits (used for remaining token calculations):")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Picker("5-Hour Quota Limit:", selection: $settings.aiQuota5hLimit) {
                            Text("2 Million").tag(2_000_000.0)
                            Text("5 Million (Standard)").tag(5_000_000.0)
                            Text("10 Million (High)").tag(10_000_000.0)
                            Text("20 Million").tag(20_000_000.0)
                        }

                        Picker("Weekly Quota Limit:", selection: $settings.aiQuotaWeeklyLimit) {
                            Text("20 Million").tag(20_000_000.0)
                            Text("50 Million (Standard)").tag(50_000_000.0)
                            Text("100 Million (High)").tag(100_000_000.0)
                            Text("200 Million").tag(200_000_000.0)
                        }

                        Picker("Monthly Quota Limit:", selection: $settings.aiQuotaMonthlyLimit) {
                            Text("50 Million").tag(50_000_000.0)
                            Text("100 Million (Standard)").tag(100_000_000.0)
                            Text("250 Million (High)").tag(250_000_000.0)
                            Text("500 Million").tag(500_000_000.0)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            // MARK: - 2. OpenAI Codex
            Section(header: Text("OpenAI Codex")) {
                Toggle("Enable OpenAI Codex", isOn: Binding(
                    get: { settings.isAIProviderEnabled(.codex) },
                    set: { enabled in
                        if enabled {
                            settings.setAIProviderEnabled(.codex, enabled: true)
                        } else {
                            registry.removeProvider(.codex)
                            hasSavedCodexKey = false
                        }
                    }
                ))

                if settings.isAIProviderEnabled(.codex) {
                    SecureField("OpenAI API Key (sk-...)", text: $codexKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Save Key to Keychain") {
                            guard !codexKeyInput.isEmpty else { return }
                            KeychainHelper.shared.save(key: CodexProvider.keychainKey, value: codexKeyInput)
                            hasSavedCodexKey = true
                            codexKeyInput = ""
                            codexStatusMessage = "Codex API Key saved securely to macOS Keychain."
                            Task { await registry.refreshAll() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Test Connection") {
                            testCodexConnection()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTestingCodex)

                        if hasSavedCodexKey {
                            Button("Remove Key", role: .destructive) {
                                registry.removeProvider(.codex)
                                hasSavedCodexKey = false
                                codexStatusMessage = "Codex API Key removed from Keychain."
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if let msg = codexStatusMessage {
                        Text(msg)
                            .font(.system(size: 10.5))
                            .foregroundColor(msg.contains("failed") || msg.contains("Error") ? .red : .green)
                    }
                }
            }

            // MARK: - 3. Anthropic Claude
            Section(header: Text("Anthropic Claude")) {
                Toggle("Enable Anthropic Claude", isOn: Binding(
                    get: { settings.isAIProviderEnabled(.claude) },
                    set: { enabled in
                        if enabled {
                            settings.setAIProviderEnabled(.claude, enabled: true)
                        } else {
                            registry.removeProvider(.claude)
                            hasSavedClaudeKey = false
                        }
                    }
                ))

                if settings.isAIProviderEnabled(.claude) {
                    SecureField("Anthropic API Key (sk-ant-...)", text: $claudeKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Save Key to Keychain") {
                            guard !claudeKeyInput.isEmpty else { return }
                            KeychainHelper.shared.save(key: ClaudeProvider.keychainKey, value: claudeKeyInput)
                            hasSavedClaudeKey = true
                            claudeKeyInput = ""
                            claudeStatusMessage = "Claude API Key saved securely to macOS Keychain."
                            Task { await registry.refreshAll() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Test Connection") {
                            testClaudeConnection()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTestingClaude)

                        if hasSavedClaudeKey {
                            Button("Remove Key", role: .destructive) {
                                registry.removeProvider(.claude)
                                hasSavedClaudeKey = false
                                claudeStatusMessage = "Claude API Key removed from Keychain."
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if let msg = claudeStatusMessage {
                        Text(msg)
                            .font(.system(size: 10.5))
                            .foregroundColor(msg.contains("failed") || msg.contains("Error") ? .red : .green)
                    }

                    Text("Also supports local Claude Code CLI inspection when ~/.claude directory exists.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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

    // MARK: - Connection Tests

    private func testWakaTimeConnection(key: String? = nil) {
        isTestingWaka = true
        wakaStatusMessage = "Testing WakaTime connection..."
        Task {
            let result = await wakaTime.testConnection(key: key)
            isTestingWaka = false
            wakaStatusMessage = result.message
        }
    }

    private func testCodexConnection() {
        guard let adapter = registry.adapter(for: .codex) else { return }
        isTestingCodex = true
        codexStatusMessage = "Testing OpenAI connection..."
        Task {
            let ok = await adapter.checkConnection()
            isTestingCodex = false
            codexStatusMessage = ok ? "OpenAI Codex connection verified successfully." : "OpenAI connection failed. Check your API key."
        }
    }

    private func testClaudeConnection() {
        guard let adapter = registry.adapter(for: .claude) else { return }
        isTestingClaude = true
        claudeStatusMessage = "Testing Claude connection..."
        Task {
            let ok = await adapter.checkConnection()
            isTestingClaude = false
            claudeStatusMessage = ok ? "Anthropic Claude connection verified successfully." : "Claude connection failed. Check your API key or ~/.claude."
        }
    }
}
