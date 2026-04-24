// Sources/TranslateBar/Utilities/HotkeyManager.swift
import AppKit
import HotKey
import Carbon

final class HotkeyManager {
    private var translateHotKey: HotKey?
    private var polishHotKey: HotKey?

    var onTranslatePressed: (() -> Void)?
    var onPolishPressed: (() -> Void)?

    /// Register translate hotkey: Cmd+Shift+T (default)
    func register(key: Key = .t, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        translateHotKey = HotKey(key: key, modifiers: modifiers)
        translateHotKey?.keyDownHandler = { [weak self] in
            self?.onTranslatePressed?()
        }
    }

    func registerPolish(key: Key = .g, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        polishHotKey = HotKey(key: key, modifiers: modifiers)
        polishHotKey?.keyDownHandler = { [weak self] in
            self?.onPolishPressed?()
        }
    }

    func unregister() {
        translateHotKey = nil
        polishHotKey = nil
    }
}
