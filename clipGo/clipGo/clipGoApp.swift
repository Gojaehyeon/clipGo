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

    var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] Application did finish launching")
        // 메뉴바 아이콘 및 메뉴 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "ClipGo")
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
            let emptyItem = NSMenuItem(title: isKorean ? "클립보드 기록 없음" : "No clipboard history", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in history.enumerated() {
                var keyEquivalent = ""
                var suffix = ""
                if index < 9 {
                    keyEquivalent = "\(index+1)"
                    suffix = " \(index+1)"
                }
                let mainText: String
                switch item.type {
                case .text(let string):
                    mainText = string.count > 50 ? String(string.prefix(50)) + "..." : string
                case .image(_):
                    mainText = "[이미지]"
                }
                // NSAttributedString: 본문 + 흐릿한 숫자(suffix)
                let attrTitle = NSMutableAttributedString(string: mainText, attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 13)
                ])
                if !suffix.isEmpty {
                    attrTitle.append(NSAttributedString(string: suffix, attributes: [
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
                    ]))
                }
                let menuItem = NSMenuItem(title: "", action: #selector(selectClipboardItem(_:)), keyEquivalent: keyEquivalent)
                menuItem.attributedTitle = attrTitle
                menuItem.target = self
                menuItem.tag = index
                if !keyEquivalent.isEmpty {
                    menuItem.keyEquivalentModifierMask = []
                }
                if case .image(let image) = item.type {
                    let imageSize = NSSize(width: 24, height: 24)
                    let thumbnail = NSImage(size: imageSize)
                    thumbnail.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: imageSize), from: .zero, operation: .copy, fraction: 1.0)
                    thumbnail.unlockFocus()
                    menuItem.image = thumbnail
                }
                menu.addItem(menuItem)
            }
        }
        menu.addItem(NSMenuItem.separator())
        let hotkeyTitle = (isKorean ? "단축키 변경" : "Change Hotkey") + " (" + HotKeyManager.shared.currentHotKeyDescription() + ")"
        let hotkeyItem = NSMenuItem(title: hotkeyTitle, action: #selector(showHotKeyPopoverMenu), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)
        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(title: isKorean ? "ClipGo 정보" : "About ClipGo", action: #selector(showAboutClipGo), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        let quitItem = NSMenuItem(title: isKorean ? "종료" : "Quit", action: #selector(quitApp), keyEquivalent: "q")
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

    @objc func showHotKeyPopoverMenu() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 140)
        popover.behavior = .transient
        popover.contentViewController = HotKeyPopoverViewController()
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        } else if let keyWindow = NSApp.keyWindow, let contentView = keyWindow.contentView {
            popover.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .maxY)
        } else if let mainWindow = NSApp.mainWindow, let contentView = mainWindow.contentView {
            popover.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .maxY)
        } else if let window = NSApp.windows.first, let contentView = window.contentView {
            popover.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .maxY)
        }
    }

    @objc func showAboutClipGo() {
        let hosting = NSHostingController(rootView: AboutClipGoView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "About ClipGo"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 340, height: 360))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

struct AboutClipGoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperclip")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .foregroundColor(.accentColor)
                .padding(.top, 24)
            Text("ClipGo")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 8)
            Text("Version 1.0")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("All rights reserved, 2025 gojaehyun")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Made by Gojaehyun, who loves Jesus")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 24)
        }
        .frame(width: 340, height: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
