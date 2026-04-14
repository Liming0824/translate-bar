// Sources/TranslateBar/UI/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    private static let keychainService = "com.translatebar.app"
    private static let keychainAccount = "google-api-key"
    private static let claudeKeychainAccount = "claude-api-key"

    @State private var apiKey: String = ""
    @State private var claudeApiKey: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var saved = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Google Translate API") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Get a key from [Google Cloud Console](https://console.cloud.google.com/apis/credentials)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Claude API (Reply Helper)") {
                SecureField("API Key", text: $claudeApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Get a key from [Anthropic Console](https://console.anthropic.com/settings/keys)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }

                HStack {
                    Text("Translate shortcut")
                    Spacer()
                    Text("⌘⇧T")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Reply helper shortcut")
                    Spacer()
                    Text("⌘⇧R")
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Spacer()
                if saved {
                    Text("Saved!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Button("Save") {
                    saveApiKeys()
                }
                .keyboardShortcut(.return)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
        .onAppear {
            loadApiKeys()
        }
    }

    private func loadApiKeys() {
        apiKey = KeychainHelper.retrieve(
            service: Self.keychainService,
            account: Self.keychainAccount
        ) ?? ""
        claudeApiKey = KeychainHelper.retrieve(
            service: Self.keychainService,
            account: Self.claudeKeychainAccount
        ) ?? ""
    }

    private func saveApiKeys() {
        try? KeychainHelper.save(
            apiKey,
            service: Self.keychainService,
            account: Self.keychainAccount
        )
        try? KeychainHelper.save(
            claudeApiKey,
            service: Self.keychainService,
            account: Self.claudeKeychainAccount
        )
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saved = false
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        try? SMAppService.mainApp.register()
    }
}
