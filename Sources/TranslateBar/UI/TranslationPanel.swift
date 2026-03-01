// Sources/TranslateBar/UI/TranslationPanel.swift
import AppKit
import SwiftUI

@MainActor
final class TranslationPanel {
    private var panel: NSPanel?
    private var eventMonitor: Any?

    func show(original: String, translation: String, nearMouse: Bool = true) {
        dismiss()

        let contentView = TranslationPopupView(
            original: original,
            translation: translation,
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translation, forType: .string)
                self?.showCopiedFeedback()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 1)

        let fittingSize = hostingView.fittingSize
        let panelWidth = min(max(fittingSize.width, 200), 400)
        let panelHeight = min(fittingSize.height, 300)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
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
        panel.isMovableByWindowBackground = false

        // Position near mouse cursor
        if nearMouse {
            let mouseLocation = NSEvent.mouseLocation
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            var origin = NSPoint(
                x: mouseLocation.x - panelWidth / 2,
                y: mouseLocation.y - panelHeight - 8
            )
            // Keep on screen
            origin.x = max(screenFrame.minX + 4, min(origin.x, screenFrame.maxX - panelWidth - 4))
            origin.y = max(screenFrame.minY + 4, origin.y)
            // If popup would go below screen, show above cursor
            if origin.y < screenFrame.minY + 4 {
                origin.y = mouseLocation.y + 20
            }
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }

        panel.orderFront(nil)
        self.panel = panel

        // Dismiss on click outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }

        // Dismiss on Esc
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    func showError(_ message: String) {
        show(original: "", translation: message)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func showCopiedFeedback() {
        // Brief visual flash could be added here
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.dismiss()
        }
    }
}

// MARK: - SwiftUI Popup View

struct TranslationPopupView: View {
    let original: String
    let translation: String
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !original.isEmpty {
                Text(original)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack(alignment: .top) {
                Text(translation)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)

                Spacer(minLength: 8)

                Button(action: {
                    onCopy()
                    copied = true
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy translation")
            }
        }
        .padding(12)
        .frame(minWidth: 200, maxWidth: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
