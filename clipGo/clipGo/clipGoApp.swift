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
    var popoverPanel: NSPanel?
    var escKeyMonitor: Any?
    var prevApp: NSRunningApplication? = nil
    var finderHotKey: HotKey?

    var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    // 최근 붙여넣은 항목 상단 이동 여부 저장용
    var movePastedToTop: Bool {
        get { UserDefaults.standard.bool(forKey: "movePastedToTop") }
        set { UserDefaults.standard.set(newValue, forKey: "movePastedToTop") }
    }

    var deleteAfterPasting: Bool {
        get { UserDefaults.standard.bool(forKey: "deleteAfterPasting") }
        set { UserDefaults.standard.set(newValue, forKey: "deleteAfterPasting") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        print("[AppDelegate] Application did finish launching")
        // 메뉴바 아이콘 및 메뉴 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "ClipGo")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
        statusItem?.menu = buildMenu()
        HotKeyManager.shared.registerDefaultHotKey(target: self, action: #selector(showCustomPopover))
        // Finder 선택 항목 추가 단축키 등록
        let finderKeyCombo = KeyCombo(key: .c, modifiers: [.command, .shift])
        self.finderHotKey = HotKey(keyCombo: finderKeyCombo)
        self.finderHotKey?.keyDownHandler = { [weak self] in
            self?.addImagesFromFinderSelection()
        }
        
        clipboardManager.movePastedToTop = movePastedToTop
        // 단축키 변경 시 메뉴 갱신
        NotificationCenter.default.addObserver(self, selector: #selector(hotKeyChanged), name: HotKeyManager.hotKeyChangedNotification, object: nil)
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        // About ClipGo 메뉴만 상단에 추가
        let aboutItem = NSMenuItem(title: isKorean ? "ClipGo 정보" : "About ClipGo", action: #selector(showAboutClipGo), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        // 이미지 추가... 메뉴
        let addImageItem = NSMenuItem(title: isKorean ? "이미지 추가..." : "Add Image...", action: #selector(addImageFromFile), keyEquivalent: "")
        addImageItem.target = self
        menu.addItem(addImageItem)
        menu.addItem(NSMenuItem.separator())
        let clearAllItem = NSMenuItem(title: isKorean ? "전체 삭제" : "Clear All", action: #selector(clearAllHistory), keyEquivalent: "")
        clearAllItem.target = self
        menu.addItem(clearAllItem)
        let hotkeyTitle = (isKorean ? "단축키 변경" : "Change Hotkey") + " (" + HotKeyManager.shared.currentHotKeyDescription() + ")"
        let hotkeyItem = NSMenuItem(title: hotkeyTitle, action: #selector(showHotKeyPopoverMenu), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)
        // 최근 붙여넣은 항목 상단 이동 체크박스
        let moveToTopTitle = isKorean ? "최근 붙여넣은 항목 상단으로 보내기" : "Move pasted item to top"
        let moveToTopItem = NSMenuItem(title: moveToTopTitle, action: #selector(toggleMovePastedToTop), keyEquivalent: "")
        moveToTopItem.target = self
        moveToTopItem.state = movePastedToTop ? .on : .off
        moveToTopItem.setAccessibilityRole(.checkBox)
        menu.addItem(moveToTopItem)
        
        let deleteAfterPastingTitle = isKorean ? "붙여넣기 후 삭제" : "Delete after pasting"
        let deleteAfterPastingItem = NSMenuItem(title: deleteAfterPastingTitle, action: #selector(toggleDeleteAfterPasting), keyEquivalent: "")
        deleteAfterPastingItem.target = self
        deleteAfterPastingItem.state = deleteAfterPasting ? .on : .off
        deleteAfterPastingItem.setAccessibilityRole(.checkBox)
        menu.addItem(deleteAfterPastingItem)
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: isKorean ? "종료" : "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc func statusItemClicked(_ sender: Any?) {
        statusItem?.menu = buildMenu()
        statusItem?.button?.performClick(nil)
    }

    @objc func showCustomPopover() {
        // 창 띄우기 직전, 현재 포커스 앱 저장
        prevApp = NSWorkspace.shared.frontmostApplication
        if let panel = popoverPanel, panel.isVisible {
            panel.close()
            popoverPanel = nil
            if let monitor = escKeyMonitor {
                NSEvent.removeMonitor(monitor)
                escKeyMonitor = nil
            }
            return
        }
        let contentView = ClipboardHistoryPopover(
            clipboardManager: clipboardManager,
            onSelect: { [weak self] item in
                guard let self = self else { return }

                // 패널 닫기
                self.popoverPanel?.close()
                self.popoverPanel = nil
                if let monitor = self.escKeyMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.escKeyMonitor = nil
                }

                // 붙여넣기 실행
                if let prevApp = self.prevApp {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        prevApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            self.clipboardManager.copyToPasteboard(item, paste: true)
                        }
                    }
                    self.prevApp = nil
                } else {
                    self.clipboardManager.copyToPasteboard(item, paste: true)
                }

                // 붙여넣기 후 히스토리 처리
                if self.deleteAfterPasting {
                    self.clipboardManager.history.removeAll(where: { $0.id == item.id })
                } else if self.movePastedToTop {
                    if let idx = self.clipboardManager.history.firstIndex(of: item) {
                        self.clipboardManager.history.remove(at: idx)
                        self.clipboardManager.history.insert(item, at: 0)
                    }
                }
            },
            onChangeHotkey: { [weak self] in self?.showHotKeyPopoverMenu() }
        )
        let hosting = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hosting)
        hosting.view.registerForDraggedTypes([.fileURL, .png, .tiff])
        panel.styleMask = [.titled, .nonactivatingPanel, .fullSizeContentView]
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        // ESC, 바깥 클릭 시 닫힘
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            self?.popoverPanel?.close()
            self?.popoverPanel = nil
            if let monitor = self?.escKeyMonitor {
                NSEvent.removeMonitor(monitor)
                self?.escKeyMonitor = nil
            }
        }
        // 화면 중앙에 위치 (마우스 커서 기준)
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            let size = NSSize(width: 340, height: 420)
            let origin = NSPoint(x: screen.frame.midX - size.width/2, y: screen.frame.midY - size.height/2)
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        popoverPanel = panel
        // ESC 키로 닫기
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.popoverPanel?.close()
                self?.popoverPanel = nil
                if let monitor = self?.escKeyMonitor {
                    NSEvent.removeMonitor(monitor)
                    self?.escKeyMonitor = nil
                }
                return nil
            }
            return event
        }
    }

    @objc func selectClipboardItem(_ sender: NSMenuItem) {
        let item = clipboardManager.history[sender.tag]
        print("[AppDelegate] Clipboard item selected: \(item)")
        if movePastedToTop {
            // 붙여넣은 항목을 상단으로 이동
            clipboardManager.history.remove(at: sender.tag)
            clipboardManager.history.insert(item, at: 0)
        }
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

    @objc func clearAllHistory() {
        clipboardManager.history.removeAll()
        statusItem?.menu = buildMenu() // 메뉴 갱신
    }

    @objc func toggleMovePastedToTop() {
        movePastedToTop.toggle()
        clipboardManager.movePastedToTop = movePastedToTop
        statusItem?.menu = buildMenu() // 메뉴 갱신
    }

    @objc func toggleDeleteAfterPasting() {
        deleteAfterPasting.toggle()
        statusItem?.menu = buildMenu() // 메뉴 갱신
    }

    @objc func hotKeyChanged() {
        statusItem?.menu = buildMenu()
    }

    @objc func addImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "heic"]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { [weak self] result in
            guard result == .OK else { return }
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    self?.clipboardManager.addImageToClipboard(image, name: url.lastPathComponent)
                }
            }
        }
    }

    @objc func addImagesFromFinderSelection() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.bundleIdentifier == "com.apple.finder" else {
            print("Finder is not the frontmost application.")
            return
        }
        
        let scriptSource = """
        tell application "Finder"
            if not application "Finder" is running then
                return {}
            end if
            set theSelection to selection
            set thePaths to {}
            repeat with eachItem in theSelection
                try
                    set end of thePaths to (the POSIX path of (eachItem as alias))
                on error
                    -- 파일을 별칭으로 강제 변환할 수 없는 항목은 무시
                end try
            end repeat
            return thePaths
        end tell
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else { return }
        let descriptor = script.executeAndReturnError(&error)

        if let err = error {
            print("AppleScript Error: \(err)")
            return
        }

        // Coerce to a list descriptor to handle multiple selections
        if let listDescriptor = descriptor.coerce(toDescriptorType: typeAEList) {
            for i in 1...listDescriptor.numberOfItems {
                if let path = listDescriptor.atIndex(i)?.stringValue {
                    self.processImagePath(path)
                }
            }
        } else if let path = descriptor.stringValue {
            // Handle single selection
            self.processImagePath(path)
        }
    }

    private func processImagePath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "heic", "webp"]
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            if let image = NSImage(contentsOf: url) {
                let name = url.lastPathComponent
                DispatchQueue.main.async {
                    self.clipboardManager.addImageToClipboard(image, name: name)
                }
            }
        }
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
