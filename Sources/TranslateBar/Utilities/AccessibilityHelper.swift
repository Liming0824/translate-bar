// Sources/TranslateBar/Utilities/AccessibilityHelper.swift
import AppKit
import ApplicationServices

enum AccessibilityHelper {
    /// Check if app has Accessibility permission
    private static let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

    static var hasPermission: Bool {
        AXIsProcessTrustedWithOptions(
            [promptKey: false] as CFDictionary
        )
    }

    /// Prompt user to grant Accessibility permission
    static func requestPermission() {
        AXIsProcessTrustedWithOptions(
            [promptKey: true] as CFDictionary
        )
    }

    /// Read selected text from the frontmost application
    static func getSelectedText() async -> String? {
        guard hasPermission else { return nil }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard focusResult == .success, let element = focusedElement else {
            return await getSelectedTextViaClipboard()
        }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        // Use trimming check — some apps (e.g. Google Docs canvas) return invisible
        // Unicode characters from kAXSelectedTextAttribute instead of actual text
        if textResult == .success, let text = selectedText as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        return await getSelectedTextViaClipboard()
    }

    /// Fallback: simulate Cmd+C and poll clipboard until it updates (up to 600ms).
    /// Uses cghidEventTap (system-level) so the event routes to the focused renderer
    /// process in multi-process apps like Chrome.
    private static func getSelectedTextViaClipboard() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        let previousContents = pasteboard.string(forType: .string)

        // Brief delay so the target app fully processes our hotkey before receiving Cmd+C
        try? await Task.sleep(nanoseconds: 80_000_000) // 80ms

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Poll for clipboard change every 50ms, up to 600ms
        var elapsed = 0
        var newContents: String? = previousContents

        while elapsed < 600_000 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            elapsed += 50_000
            if pasteboard.changeCount != previousChangeCount {
                newContents = pasteboard.string(forType: .string)
                break
            }
        }

        if let previous = previousContents, newContents != previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
        }

        if let text = newContents, text != previousContents, !text.isEmpty {
            return text
        }
        return nil
    }
}
