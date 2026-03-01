// Sources/TranslateBar/App/AppDelegate.swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private let hotkeyManager = HotkeyManager()
    private let translationPanel = TranslationPanel()

    private static let keychainService = "com.translatebar.app"
    private static let keychainAccount = "google-api-key"

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()
        setupHotkey()
        NSApp.servicesProvider = self

        // Register service so macOS knows about it
        NSUpdateDynamicServices()
    }

    private func setupHotkey() {
        hotkeyManager.register()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.handleHotkeyTranslation()
        }
    }

    private func handleHotkeyTranslation() {
        guard let text = AccessibilityHelper.getSelectedText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if !AccessibilityHelper.hasPermission {
                AccessibilityHelper.requestPermission()
                translationPanel.showError("Grant Accessibility permission in System Settings, then try again.")
            } else {
                translationPanel.showError("No text selected")
            }
            return
        }
        performTranslation(text: text)
    }

    /// NSServices handler — called when user selects "Translate with TranslateBar" from Services menu
    @objc func translateSelection(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error.pointee = "No text provided" as NSString
            return
        }
        performTranslation(text: text)
    }

    private func performTranslation(text: String) {
        guard let apiKey = KeychainHelper.retrieve(
            service: Self.keychainService,
            account: Self.keychainAccount
        ), !apiKey.isEmpty else {
            translationPanel.showError("Set your API key in settings")
            return
        }

        let service = TranslationService(apiKey: apiKey)

        Task { @MainActor in
            do {
                let result = try await service.translate(text: text)
                translationPanel.show(original: text, translation: result)
            } catch {
                translationPanel.showError(error.localizedDescription)
            }
        }
    }
}
