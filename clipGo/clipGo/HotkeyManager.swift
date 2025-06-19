import Foundation
import KeyboardShortcuts
import HotKey
import AppKit

extension KeyboardShortcuts.Name {
    static let showClipboard = Self("showClipboard")
}

final class HotKeyManager {
    static let shared = HotKeyManager()
    static let hotKeyChangedNotification = Notification.Name("HotKeyManagerHotKeyChanged")

    private var hotKey: HotKey?

    func registerDefaultHotKey(target: AnyObject, action: Selector) {
        hotKey = HotKey(key: .v, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak target] in
            _ = target?.perform(action)
        }
    }
    
    func updateHotKey(key: Key, modifiers: NSEvent.ModifierFlags, target: AnyObject, action: Selector) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak target] in
            _ = target?.perform(action)
        }
        NotificationCenter.default.post(name: HotKeyManager.hotKeyChangedNotification, object: nil)
    }
    
    func currentHotKeyDescription() -> String {
        guard let hotKey = hotKey else { return "⌘ + ⇧ + V" }
        let keyCombo = hotKey.keyCombo
        var parts: [String] = []
        
        if keyCombo.modifiers.contains(.command) { parts.append("⌘") }
        if keyCombo.modifiers.contains(.option) { parts.append("⌥") }
        if keyCombo.modifiers.contains(.shift) { parts.append("⇧") }
        if keyCombo.modifiers.contains(.control) { parts.append("⌃") }
        
        if let key = keyCombo.key {
            parts.append(key.description)
        } else {
            parts.append("?")
        }
        return parts.joined(separator: " + ")
    }
} 