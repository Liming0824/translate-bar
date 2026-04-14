# Slack Reply Helper Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `Cmd+Shift+R` hotkey to TranslateBar that opens a reply-composition panel — user selects a Slack message, types intent in Chinese/English, Claude generates a casual English response, auto-copied to clipboard.

**Architecture:** Extends existing TranslateBar with a second hotkey flow. New `ClaudeService` handles the API call. New `ReplyPanel` provides the input/output UI. HotkeyManager gets a second callback. Settings gets a second API key field.

**Tech Stack:** Swift 6.0 (language mode v5), SwiftUI, HotKey library, Claude Messages API (HTTP), macOS Keychain

---

### Task 1: ClaudeService — Tests

**Files:**
- Create: `Tests/TranslateBarTests/ClaudeServiceTests.swift`

**Step 1: Write tests for ClaudeService**

Create `Tests/TranslateBarTests/ClaudeServiceTests.swift`:

```swift
// Tests/TranslateBarTests/ClaudeServiceTests.swift
import Testing
import Foundation
@testable import TranslateBar

struct ClaudeServiceTests {
    @Test func buildRequestURL() {
        let service = ClaudeService(apiKey: "test-key")
        let request = service.buildRequest(
            selectedMessage: "hey how's it going",
            userIntent: "还不错"
        )

        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.httpMethod == "POST")
    }

    @Test func buildRequestHeaders() {
        let service = ClaudeService(apiKey: "test-key")
        let request = service.buildRequest(
            selectedMessage: "hey how's it going",
            userIntent: "还不错"
        )

        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test func buildRequestBody() throws {
        let service = ClaudeService(apiKey: "test-key")
        let request = service.buildRequest(
            selectedMessage: "hey how's it going",
            userIntent: "还不错"
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "claude-haiku-4-5-20251001")
        #expect(body["max_tokens"] as? Int == 150)

        // Check system prompt exists
        let system = body["system"] as? String
        #expect(system != nil)
        #expect(system!.contains("casual"))

        // Check user message contains both parts
        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        let content = messages?.first?["content"] as? String
        #expect(content?.contains("hey how's it going") == true)
        #expect(content?.contains("还不错") == true)
    }

    @Test func parseSuccessResponse() throws {
        let json = """
        {
            "content": [
                { "type": "text", "text": "Not bad at all!" }
            ]
        }
        """.data(using: .utf8)!

        let result = try ClaudeService.parseResponse(data: json)
        #expect(result == "Not bad at all!")
    }

    @Test func parseErrorResponse() {
        let json = """
        {
            "error": { "type": "invalid_request_error", "message": "bad request" }
        }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try ClaudeService.parseResponse(data: json)
        }
    }

    @Test func parseEmptyContent() {
        let json = """
        { "content": [] }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try ClaudeService.parseResponse(data: json)
        }
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/limingkang/TranslateBar && swift test --filter ClaudeServiceTests 2>&1 | tail -5`
Expected: Compilation error — `ClaudeService` not found.

**Step 3: Commit**

```bash
git add Tests/TranslateBarTests/ClaudeServiceTests.swift
git commit -m "test: add ClaudeService tests (red)"
```

---

### Task 2: ClaudeService — Implementation

**Files:**
- Create: `Sources/TranslateBar/Services/ClaudeService.swift`

**Step 1: Implement ClaudeService**

Create `Sources/TranslateBar/Services/ClaudeService.swift`:

```swift
// Sources/TranslateBar/Services/ClaudeService.swift
import Foundation

enum ClaudeError: Error, LocalizedError {
    case noApiKey
    case networkError(Error)
    case apiError(String)
    case emptyResult
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Set your Claude API key in settings"
        case .networkError(let err): return "Request failed: \(err.localizedDescription)"
        case .apiError(let msg): return "Claude API error: \(msg)"
        case .emptyResult: return "No response generated"
        case .invalidResponse: return "Invalid response from Claude"
        }
    }
}

final class ClaudeService {
    private let apiKey: String
    private let session: URLSession
    private static let apiURL = "https://api.anthropic.com/v1/messages"

    private static let systemPrompt = """
        You are helping someone reply in a casual Slack conversation. \
        Generate a natural, friendly English response. The user will provide: \
        1) The message they are replying to. \
        2) What they want to say (may be in Chinese or rough English). \
        Interpret their meaning and produce a native-sounding English reply. \
        Keep it brief, conversational, and warm. This is off-topic small talk, not work discussion. \
        Reply with ONLY the response text, no quotes or explanation.
        """

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func buildRequest(selectedMessage: String, userIntent: String) -> URLRequest {
        var request = URLRequest(url: URL(string: Self.apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let userContent = """
            Message I'm replying to: "\(selectedMessage)"

            What I want to say: "\(userIntent)"
            """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 150,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw ClaudeError.apiError(message)
        }

        guard let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw ClaudeError.emptyResult
        }

        return text
    }

    func generateReply(selectedMessage: String, userIntent: String) async throws -> String {
        let request = buildRequest(selectedMessage: selectedMessage, userIntent: userIntent)

        do {
            let (data, _) = try await session.data(for: request)
            return try Self.parseResponse(data: data)
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.networkError(error)
        }
    }
}
```

**Step 2: Run tests to verify they pass**

Run: `cd /Users/limingkang/TranslateBar && swift test --filter ClaudeServiceTests 2>&1 | tail -10`
Expected: All 6 tests PASS.

**Step 3: Commit**

```bash
git add Sources/TranslateBar/Services/ClaudeService.swift
git commit -m "feat: add ClaudeService for Claude Messages API"
```

---

### Task 3: HotkeyManager — Support Second Hotkey

**Files:**
- Modify: `Sources/TranslateBar/Utilities/HotkeyManager.swift`

**Step 1: Add second hotkey support**

Replace the contents of `HotkeyManager.swift` with:

```swift
// Sources/TranslateBar/Utilities/HotkeyManager.swift
import AppKit
import HotKey
import Carbon

final class HotkeyManager {
    private var translateHotKey: HotKey?
    private var replyHotKey: HotKey?

    var onTranslatePressed: (() -> Void)?
    var onReplyPressed: (() -> Void)?

    /// Register translate hotkey: Cmd+Shift+T (default)
    func register(key: Key = .t, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        translateHotKey = HotKey(key: key, modifiers: modifiers)
        translateHotKey?.keyDownHandler = { [weak self] in
            self?.onTranslatePressed?()
        }
    }

    /// Register reply hotkey: Cmd+Shift+R (default)
    func registerReply(key: Key = .r, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        replyHotKey = HotKey(key: key, modifiers: modifiers)
        replyHotKey?.keyDownHandler = { [weak self] in
            self?.onReplyPressed?()
        }
    }

    func unregister() {
        translateHotKey = nil
        replyHotKey = nil
    }
}
```

**Step 2: Update AppDelegate to use renamed callback**

In `AppDelegate.swift`, change `hotkeyManager.onHotkeyPressed` to `hotkeyManager.onTranslatePressed`:

```swift
// In setupHotkey(), change:
hotkeyManager.onHotkeyPressed = { [weak self] in
// To:
hotkeyManager.onTranslatePressed = { [weak self] in
```

**Step 3: Build to verify no regressions**

Run: `cd /Users/limingkang/TranslateBar && swift build 2>&1 | tail -5`
Expected: Build succeeded.

**Step 4: Run all tests**

Run: `cd /Users/limingkang/TranslateBar && swift test 2>&1 | tail -10`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Sources/TranslateBar/Utilities/HotkeyManager.swift Sources/TranslateBar/App/AppDelegate.swift
git commit -m "feat: support second hotkey (Cmd+Shift+R) in HotkeyManager"
```

---

### Task 4: ReplyPanel UI

**Files:**
- Create: `Sources/TranslateBar/UI/ReplyPanel.swift`

**Step 1: Create ReplyPanel**

Create `Sources/TranslateBar/UI/ReplyPanel.swift`:

```swift
// Sources/TranslateBar/UI/ReplyPanel.swift
import AppKit
import SwiftUI

@MainActor
final class ReplyPanel {
    private var panel: NSPanel?
    private var eventMonitor: Any?

    func show(selectedMessage: String, onGenerate: @escaping (String) async -> String?) {
        dismiss()

        let contentView = ReplyPanelView(
            selectedMessage: selectedMessage,
            onGenerate: onGenerate,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Reply Helper"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true

        // Position near mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var origin = NSPoint(
            x: mouseLocation.x - 200,
            y: mouseLocation.y - 320
        )
        origin.x = max(screenFrame.minX + 4, min(origin.x, screenFrame.maxX - 404))
        origin.y = max(screenFrame.minY + 4, origin.y)
        if origin.y < screenFrame.minY + 4 {
            origin.y = mouseLocation.y + 20
        }
        panel.setFrameOrigin(origin)

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel

        // Dismiss on Esc
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    func showError(_ message: String) {
        dismiss()

        let contentView = Text(message)
            .foregroundColor(.red)
            .padding()
            .frame(width: 300)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 60)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView

        let mouseLocation = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouseLocation.x - 150, y: mouseLocation.y - 70))
        panel.orderFront(nil)
        self.panel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.dismiss()
        }
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - SwiftUI Reply Panel View

struct ReplyPanelView: View {
    let selectedMessage: String
    let onGenerate: (String) async -> String?
    let onDismiss: () -> Void

    @State private var userIntent = ""
    @State private var generatedReply = ""
    @State private var isLoading = false
    @State private var copied = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected message
            VStack(alignment: .leading, spacing: 4) {
                Text("Replying to:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(selectedMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)

            // User intent input
            VStack(alignment: .leading, spacing: 4) {
                Text("What do you want to say?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Type in Chinese or English...", text: $userIntent)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit { generate() }
            }

            // Generate button
            HStack {
                Spacer()
                Button(action: generate) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Generate")
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(userIntent.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }

            // Generated response
            if !generatedReply.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Response:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if copied {
                            Text("Copied!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    Text(generatedReply)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            isInputFocused = true
        }
    }

    private func generate() {
        let intent = userIntent.trimmingCharacters(in: .whitespaces)
        guard !intent.isEmpty, !isLoading else { return }

        isLoading = true
        generatedReply = ""
        copied = false

        Task {
            if let reply = await onGenerate(intent) {
                generatedReply = reply
                // Auto-copy to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(reply, forType: .string)
                copied = true
            }
            isLoading = false
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `cd /Users/limingkang/TranslateBar && swift build 2>&1 | tail -5`
Expected: Build succeeded.

**Step 3: Commit**

```bash
git add Sources/TranslateBar/UI/ReplyPanel.swift
git commit -m "feat: add ReplyPanel UI with intent input and auto-copy"
```

---

### Task 5: Wire Up AppDelegate

**Files:**
- Modify: `Sources/TranslateBar/App/AppDelegate.swift`

**Step 1: Add replyPanel and Claude keychain constants, wire up reply hotkey**

Replace the full contents of `AppDelegate.swift` with:

```swift
// Sources/TranslateBar/App/AppDelegate.swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private let hotkeyManager = HotkeyManager()
    private let translationPanel = TranslationPanel()
    private let replyPanel = ReplyPanel()

    private static let keychainService = "com.translatebar.app"
    private static let keychainAccount = "google-api-key"
    private static let claudeKeychainAccount = "claude-api-key"

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

        hotkeyManager.registerReply()
        hotkeyManager.onReplyPressed = { [weak self] in
            self?.handleHotkeyReply()
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

    private func handleHotkeyReply() {
        Task { @MainActor in
            guard let text = await AccessibilityHelper.getSelectedText(),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !AccessibilityHelper.hasPermission {
                    AccessibilityHelper.requestPermission()
                    self.replyPanel.showError("Grant Accessibility permission in System Settings, then try again.")
                } else {
                    self.replyPanel.showError("No text selected — select a Slack message first")
                }
                return
            }

            guard let apiKey = KeychainHelper.retrieve(
                service: Self.keychainService,
                account: Self.claudeKeychainAccount
            ), !apiKey.isEmpty else {
                self.replyPanel.showError("Set your Claude API key in settings")
                return
            }

            let service = ClaudeService(apiKey: apiKey)

            self.replyPanel.show(selectedMessage: text) { userIntent in
                do {
                    return try await service.generateReply(
                        selectedMessage: text,
                        userIntent: userIntent
                    )
                } catch {
                    return "Error: \(error.localizedDescription)"
                }
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
```

**Step 2: Build to verify**

Run: `cd /Users/limingkang/TranslateBar && swift build 2>&1 | tail -5`
Expected: Build succeeded.

**Step 3: Run all tests**

Run: `cd /Users/limingkang/TranslateBar && swift test 2>&1 | tail -10`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add Sources/TranslateBar/App/AppDelegate.swift
git commit -m "feat: wire up reply hotkey flow in AppDelegate"
```

---

### Task 6: Settings — Add Claude API Key Field

**Files:**
- Modify: `Sources/TranslateBar/UI/SettingsView.swift`

**Step 1: Add Claude API key field to SettingsView**

Replace the full contents of `SettingsView.swift` with:

```swift
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
```

**Step 2: Update MenuBarController window height**

In `MenuBarController.swift`, update the settings window height from 250 to 350:

Change both occurrences:
```swift
// In openSettings(), change:
contentRect: NSRect(x: 0, y: 0, width: 400, height: 250)
// To:
contentRect: NSRect(x: 0, y: 0, width: 400, height: 350)
```

**Step 3: Build to verify**

Run: `cd /Users/limingkang/TranslateBar && swift build 2>&1 | tail -5`
Expected: Build succeeded.

**Step 4: Run all tests**

Run: `cd /Users/limingkang/TranslateBar && swift test 2>&1 | tail -10`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Sources/TranslateBar/UI/SettingsView.swift Sources/TranslateBar/UI/MenuBarController.swift
git commit -m "feat: add Claude API key field to settings"
```

---

### Task 7: Build, Install, and Manual Test

**Files:**
- None (manual verification)

**Step 1: Build the app bundle**

Run: `cd /Users/limingkang/TranslateBar && bash build-app.sh`
Expected: App builds and installs to `/Applications`.

**Step 2: Manual test — translate flow still works**

1. Open any app, select English text
2. Press `Cmd+Shift+T`
3. Verify translation popup appears as before

**Step 3: Manual test — reply helper flow**

1. Open Settings from menu bar, enter Claude API key, save
2. Open Slack, select a casual message
3. Press `Cmd+Shift+R`
4. Verify ReplyPanel appears with the selected message
5. Type intent in Chinese (e.g. "哈哈太搞笑了")
6. Press Enter / click Generate
7. Verify English response appears and is auto-copied to clipboard
8. Paste into Slack to verify

**Step 4: Commit any fixes if needed, then final commit**

```bash
git add -A
git commit -m "feat: Slack Reply Helper — complete feature"
```
