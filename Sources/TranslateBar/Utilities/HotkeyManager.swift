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
