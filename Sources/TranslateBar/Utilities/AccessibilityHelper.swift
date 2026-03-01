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
    static func getSelectedText() -> String? {
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
            return getSelectedTextViaClipboard()
        }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        if textResult == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }

        return getSelectedTextViaClipboard()
    }

    /// Fallback: simulate Cmd+C and read from clipboard
    private static func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Brief delay for clipboard to update
        usleep(100_000) // 100ms

        let newContents = pasteboard.string(forType: .string)

        // Restore previous clipboard if we got something new
        if let previous = previousContents, newContents != previousContents {
            // We got new text, restore old clipboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }

        if let text = newContents, text != previousContents, !text.isEmpty {
            return text
        }
        return newContents ?? previousContents
    }
}
