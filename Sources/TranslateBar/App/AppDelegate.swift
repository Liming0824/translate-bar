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
        hotkeyManager.onTranslatePressed = { [weak self] in
            self?.handleHotkeyTranslation()
        }

        hotkeyManager.registerPolish()
        hotkeyManager.onPolishPressed = { [weak self] in
            self?.handleHotkeyPolish()
        }
    }

    private func handleHotkeyTranslation() {
        Task { @MainActor in
            guard let text = await AccessibilityHelper.getSelectedText(),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !AccessibilityHelper.hasPermission {
                    AccessibilityHelper.requestPermission()
                    self.translationPanel.showError("Grant Accessibility permission in System Settings, then try again.")
                } else {
                    self.translationPanel.showError("No text selected")
                }
                return
            }
            self.performTranslation(text: text)
        }
    }

    private func handleHotkeyPolish() {
        Task { @MainActor in
            guard let text = await AccessibilityHelper.getSelectedText(),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !AccessibilityHelper.hasPermission {
                    AccessibilityHelper.requestPermission()
                    self.translationPanel.showError("Grant Accessibility permission in System Settings, then try again.")
                } else {
                    self.translationPanel.showError("No text selected")
                }
                return
            }

            let service = GrammarService()

            do {
                let polished = try await service.polish(text: text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(polished, forType: .string)
                self.translationPanel.show(original: text, translation: polished)
            } catch {
                self.translationPanel.showError(error.localizedDescription)
            }
        }
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
        let speechService = SpeechService(apiKey: apiKey)
        let pair = LanguageDetector.detect(text)

        Task { @MainActor in
            do {
                let result = try await service.translate(text: text)
                self.translationPanel.show(
                    original: text,
                    translation: result,
                    onSpeak: { original in
                        Task {
                            if speechService.isPlaying {
                                speechService.stop()
                            } else {
                                try? await speechService.speak(text: original, languageCode: pair.source) {}
                            }
                        }
                    }
                )
                self.translationPanel.onDismissPanel = {
                    speechService.stop()
                }
            } catch {
                translationPanel.showError(error.localizedDescription)
            }
        }
    }
}
