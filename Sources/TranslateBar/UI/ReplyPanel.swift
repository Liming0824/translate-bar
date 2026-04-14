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
