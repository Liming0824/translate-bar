// Sources/TranslateBar/Utilities/HotkeyManager.swift
import AppKit
import HotKey
import Carbon

final class HotkeyManager {
    private var hotKey: HotKey?
    var onHotkeyPressed: (() -> Void)?

    /// Default: Cmd+Shift+T
    func register(key: Key = .t, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onHotkeyPressed?()
        }
    }

    func unregister() {
        hotKey = nil
    }
}
