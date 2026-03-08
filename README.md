# TranslateBar

A lightweight macOS menu bar app for instant English <-> Chinese translation. Select any text, hit a shortcut, and get the translation in a floating popup — no switching apps needed.

## Features

- **Keyboard shortcut** — Select text anywhere, press `Cmd+Shift+T` to translate
- **Right-click service** — Select text > right-click > Services > "Translate with TranslateBar"
- **Smart language detection** — Automatically detects English vs Chinese and translates in the right direction
- **Floating popup** — Translation appears near your cursor and dismisses on click
- **Secure key storage** — Your API key is stored in macOS Keychain, never in plain text

---

## Requirements

- macOS 13 (Ventura) or later
- [Swift](https://www.swift.org/install/) (comes with Xcode or Xcode Command Line Tools)
- A Google Cloud Translation API key (free tier: 500,000 characters/month)

---

## Getting a Google Translate API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select an existing one)
3. In the left sidebar go to **APIs & Services > Library**
4. Search for **"Cloud Translation API"** and click **Enable**
5. Go to **APIs & Services > Credentials**
6. Click **+ Create Credentials > API key**
7. Copy the generated API key — you'll paste it into TranslateBar's settings

> **Tip:** Click "Edit API key" to restrict it to the Cloud Translation API only, which is good security practice.

---

## Installation

### Option 1 — Build and install the app bundle (recommended)

```bash
git clone https://github.com/YOUR_USERNAME/TranslateBar.git
cd TranslateBar
bash build-app.sh
```

This builds a release binary, bundles it as `TranslateBar.app`, copies it to `/Applications`, and launches it automatically.

### Option 2 — Run directly with Swift

```bash
git clone https://github.com/YOUR_USERNAME/TranslateBar.git
cd TranslateBar
swift build
.build/debug/TranslateBar
```

---

## First-Time Setup

1. After launch, a translate icon appears in your **menu bar**
2. Click the icon > **Settings**
3. Paste your Google Cloud Translation API key and click **Save**
4. When prompted, grant **Accessibility permission** in System Settings (required for the keyboard shortcut)
5. Go to **System Settings > Keyboard > Keyboard Shortcuts > Services** and make sure **"Translate with TranslateBar"** is enabled

---

## Usage

| Method | Steps |
|--------|-------|
| **Keyboard shortcut** | Select text in any app, press `Cmd+Shift+T` |
| **Right-click menu** | Select text, right-click > Services > "Translate with TranslateBar" |

The translation pops up near your cursor. Click anywhere to dismiss it.

---

## Architecture

| Layer | Files |
|-------|-------|
| App entry | `App/main.swift`, `App/AppDelegate.swift` |
| Translation | `Services/TranslationService.swift`, `Services/LanguageDetector.swift` |
| Display | `UI/TranslationPanel.swift`, `UI/MenuBarController.swift`, `UI/SettingsView.swift` |
| Utilities | `Utilities/KeychainHelper.swift`, `Utilities/AccessibilityHelper.swift`, `Utilities/HotkeyManager.swift` |

---

## Security

- The API key is **never stored in source code or config files**
- It is saved exclusively in the **macOS Keychain** under your user account
- Nothing is transmitted except the selected text to Google's Translation API
