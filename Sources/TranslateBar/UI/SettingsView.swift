// Sources/TranslateBar/UI/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    private static let keychainService = "com.translatebar.app"
    private static let keychainAccount = "google-api-key"

    @State private var apiKey: String = ""
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

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                HStack {
                    Text("Keyboard shortcut")
                    Spacer()
                    Text("⌘⇧T")
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
                    saveApiKey()
                }
                .keyboardShortcut(.return)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 250)
        .onAppear {
            loadApiKey()
        }
    }

    private func loadApiKey() {
        apiKey = KeychainHelper.retrieve(
            service: Self.keychainService,
            account: Self.keychainAccount
        ) ?? ""
    }

    private func saveApiKey() {
        try? KeychainHelper.save(
            apiKey,
            service: Self.keychainService,
            account: Self.keychainAccount
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
