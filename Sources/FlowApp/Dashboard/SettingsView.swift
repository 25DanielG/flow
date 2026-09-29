import AppKit
import FlowAudio
import FlowClaude
import SwiftUI

struct SettingsView: View {
    let permissions: PermissionsManager

    @State private var keyInput = ""
    @State private var keyError: String?
    @State private var microphone = MicrophonePreference.current
    @State private var refresh = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(title: "Settings")
                apiKey
                microphoneSection
                permissionsSection
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // re-check after coming back from System Settings
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh += 1
        }
    }

    // MARK: API key

    private var apiKey: some View {
        let _ = refresh
        let usingEnvironment = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false
        let hasStored = AnthropicAPIKey.hasStoredKey
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Anthropic API key")
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SecureField(hasStored ? "Replace saved key" : "sk-ant-…", text: $keyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .onSubmit(saveKey)
                        Button("Save", action: saveKey)
                            .buttonStyle(SubtleButtonStyle(prominent: true))
                            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AnthropicAPIKey.isConfigured ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(statusText(usingEnvironment: usingEnvironment, hasStored: hasStored))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if hasStored {
                            Button("Remove") {
                                AnthropicAPIKey.removeStoredKey()
                                refresh += 1
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                    }
                    if let keyError {
                        Text(keyError).font(.system(size: 12)).foregroundStyle(.red)
                    }
                    Text("Only the text of what you say is sent to Claude, never audio. The key lives in your macOS Keychain.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func statusText(usingEnvironment: Bool, hasStored: Bool) -> String {
        if usingEnvironment { return "Using ANTHROPIC_API_KEY from the environment" }
        if hasStored { return "Key saved" }
        return "No key. Flow types the raw transcript."
    }

    private func saveKey() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try AnthropicAPIKey.save(key)
            keyInput = ""
            keyError = nil
            refresh += 1
        } catch {
            keyError = "Couldn't save to Keychain (\(error))."
        }
    }

    // MARK: Microphone

    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Microphone")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: Binding(
                        get: { microphone },
                        set: { microphone = $0; MicrophonePreference.set($0) }
                    )) {
                        Text("Automatic").tag(MicrophonePreference.automatic)
                        Text("System default (\(AudioInputDevices.defaultInput()?.name ?? "none"))")
                            .tag(MicrophonePreference.systemDefault)
                        Divider()
                        ForEach(AudioInputDevices.all()) { Text($0.name).tag($0.uid) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()

                    Text("Automatic uses this Mac's built-in mic while a Bluetooth headset is your input, so AirPods stay in high-quality playback instead of switching to call mode.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: Permissions

    private var permissionsSection: some View {
        let _ = refresh
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Permissions")
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(PermissionKind.allCases.enumerated()), id: \.element) { index, kind in
                        if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        let granted = permissions.status(for: kind) == .granted
                        HStack(spacing: 12) {
                            Circle()
                                .fill(granted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.rawValue).font(.system(size: 13))
                                Text(kind.explanation)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if !granted {
                                Button("Grant") {
                                    permissions.request(kind) { _ in refresh += 1 }
                                    permissions.openSettings(for: kind)
                                }
                                .buttonStyle(SubtleButtonStyle())
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}
