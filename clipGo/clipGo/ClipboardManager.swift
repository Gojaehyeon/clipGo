import Foundation
import AppKit

enum ClipboardItemType: Equatable {
    case text(String)
    case image(NSImage)

    static func == (lhs: ClipboardItemType, rhs: ClipboardItemType) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)):
            return a == b
        case let (.image(a), .image(b)):
            // 이미지 데이터가 같으면 true (간단히 tiffRepresentation 비교)
            return a.tiffRepresentation == b.tiffRepresentation
        default:
            return false
        }
    }
}

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let type: ClipboardItemType
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private let maxHistory = 20

    init() {
        lastChangeCount = pasteboard.changeCount
        startMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            var newItem: ClipboardItem? = nil
            if let newString = pasteboard.string(forType: .string), !newString.isEmpty {
                newItem = ClipboardItem(type: .text(newString))
            } else if let imageData = pasteboard.data(forType: .tiff), let image = NSImage(data: imageData) {
                newItem = ClipboardItem(type: .image(image))
            }
            if let item = newItem, history.first?.type != item.type {
                history.insert(item, at: 0)
                history = Array(history.prefix(maxHistory))
            }
        }
    }

    func copyToPasteboard(_ item: ClipboardItem, paste: Bool = false) {
        pasteboard.clearContents()
        switch item.type {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            if let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
        if paste {
            simulatePaste()
        }
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdVDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // 'v'
        let cmdVUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        cmdVDown?.flags = .maskCommand
        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.flags = .maskCommand
        cmdVUp?.post(tap: .cghidEventTap)
    }
} 