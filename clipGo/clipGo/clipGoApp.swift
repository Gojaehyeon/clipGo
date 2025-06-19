//
//  clipGoApp.swift
//  clipGo
//
//  Created by Gojaehyun on 6/19/25.
//

import SwiftUI
import HotKey

@main
struct ClipGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        print("[ClipGoApp] App initialized")
    }

    var body: some Scene {
        // SwiftUI 윈도우 그룹 없이 AppKit 메뉴바만 사용
        Settings {}
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] Application did finish launching")
        // 메뉴바 아이콘 및 메뉴 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipGo")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
        statusItem?.menu = buildMenu()
        HotKeyManager.shared.registerDefaultHotKey(target: self, action: #selector(showMenuBarMenu))
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let history = clipboardManager.history
        if history.isEmpty {
            let emptyItem = NSMenuItem(title: "클립보드 기록 없음", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in history.enumerated() {
                switch item.type {
                case .text(let string):
                    let displayTitle = string.count > 50 ? String(string.prefix(50)) + "..." : string
                    let menuItem = NSMenuItem(title: displayTitle, action: #selector(selectClipboardItem(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.tag = index
                    menu.addItem(menuItem)
                case .image(let image):
                    let menuItem = NSMenuItem(title: "[이미지]", action: #selector(selectClipboardItem(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.tag = index
                    let imageSize = NSSize(width: 24, height: 24)
                    let thumbnail = NSImage(size: imageSize)
                    thumbnail.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: imageSize), from: .zero, operation: .copy, fraction: 1.0)
                    thumbnail.unlockFocus()
                    menuItem.image = thumbnail
                    menu.addItem(menuItem)
                }
            }
        }
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "설정", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quitItem = NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc func statusItemClicked(_ sender: Any?) {
        statusItem?.menu = buildMenu()
        statusItem?.button?.performClick(nil)
    }

    @objc func showMenuBarMenu() {
        print("[AppDelegate] showMenuBarMenu called")
        statusItem?.menu = buildMenu()
        statusItem?.button?.performClick(nil)
    }

    @objc func selectClipboardItem(_ sender: NSMenuItem) {
        let item = clipboardManager.history[sender.tag]
        print("[AppDelegate] Clipboard item selected: \(item)")
        clipboardManager.copyToPasteboard(item, paste: true)
    }

    @objc func showSettings() {
        print("[AppDelegate] showSettings called")
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            settingsWindow = NSWindow(contentViewController: hosting)
            settingsWindow?.title = "설정"
            settingsWindow?.setContentSize(NSSize(width: 340, height: 120))
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
