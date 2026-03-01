# TranslateBar

A lightweight macOS menu bar app for system-wide English <-> Chinese translation.

## Features

- **Right-click to translate** — Select text in any app, right-click > Services > "Translate with TranslateBar"
- **Keyboard shortcut** — Select text, press Cmd+Shift+T
- **Smart detection** — Automatically detects English vs Chinese
- **Floating popup** — Translation appears near your cursor
- **Secure** — API key stored in macOS Keychain

## Setup

1. Build and run the app (`swift build` then run `.build/debug/TranslateBar`)
2. Click the TranslateBar icon in the menu bar > Settings
3. Enter your [Google Cloud Translation API key](https://console.cloud.google.com/apis/credentials)
4. Grant Accessibility permission when prompted (needed for keyboard shortcut)

## Enable Services Menu

After first launch, go to **System Settings > Keyboard > Keyboard Shortcuts > Services** and ensure "Translate with TranslateBar" is enabled.

## Requirements

- macOS 13 (Ventura) or later
- Google Cloud Translation API key (free tier: 500k chars/month)

## Architecture

| Layer | Files |
|-------|-------|
| App entry | `App/main.swift`, `App/AppDelegate.swift` |
| Translation | `Services/TranslationService.swift`, `Services/LanguageDetector.swift` |
| Display | `UI/TranslationPanel.swift`, `UI/MenuBarController.swift`, `UI/SettingsView.swift` |
| Utilities | `Utilities/KeychainHelper.swift`, `Utilities/AccessibilityHelper.swift`, `Utilities/HotkeyManager.swift` |
