// Sources/TranslateBar/UI/TranslationPanel.swift
import AppKit
import SwiftUI

@MainActor
final class TranslationPanel {
    private var panel: NSPanel?
    private var eventMonitor: Any?
    var onDismissPanel: (() -> Void)?

    func show(original: String, translation: String, nearMouse: Bool = true, onSpeak: ((String) -> Void)? = nil) {
        dismiss()

        let contentView = TranslationPopupView(
            original: original,
            translation: translation,
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translation, forType: .string)
                self?.showCopiedFeedback()
            },
            onSpeak: onSpeak,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        // Set width first, large height so layout isn't height-constrained
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 2000)
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        let panelWidth = min(max(fittingSize.width, 200), 400)
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let panelHeight = min(fittingSize.height, screenHeight * 0.75)

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
        onDismissPanel?()
        onDismissPanel = nil
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
    var onSpeak: ((String) -> Void)?
    let onDismiss: () -> Void

    @State private var copied = false
    @State private var speaking = false
    private let scrollThreshold = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !original.isEmpty {
                HStack(alignment: .top) {
                    Text(original)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    Spacer()
                    if let speak = onSpeak {
                        Button(action: {
                            speaking.toggle()
                            speak(original)
                        }) {
                            Image(systemName: speaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 13))
                                .foregroundColor(speaking ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Pronounce original")
                    }
                }
            }

            ZStack(alignment: .topTrailing) {
                if translation.count > scrollThreshold {
                    ScrollView {
                        Text(translation)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 20)
                    }
                    .frame(maxHeight: 450)
                } else {
                    Text(translation)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 20)
                }

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
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
