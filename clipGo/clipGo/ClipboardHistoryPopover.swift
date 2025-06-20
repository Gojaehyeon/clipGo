import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ThinScrollbar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.scrollerStyle = .overlay // 얇은 스크롤바
        return scrollView
    }
    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

struct ClipboardHistoryPopover: View {
    @ObservedObject var clipboardManager: ClipboardManager
    var onSelect: (ClipboardItem) -> Void
    var onChangeHotkey: (() -> Void)? = nil
    @State private var selectedTab: Tab = .all
    @State private var keyMonitor: Any? = nil
    @State private var selectedIndex: Int? = nil
    
    enum Tab { case all, favorite }
    var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }
    
    var filteredHistory: [ClipboardItem] {
        switch selectedTab {
        case .all: return clipboardManager.history
        case .favorite: return clipboardManager.history.filter { $0.isFavorite }
        }
    }

    // 1~9, qwerty...m까지 키보드 순서 단축키
    let keyMap: [String] = [
        "1","2","3","4","5","6","7","8","9",
        "q","w","e","r","t","y","u","i","o","p",
        "a","s","d","f","g","h","j","k","l",
        "z","x","c","v","b","n","m"
    ]

    var body: some View {
        ZStack {
            if filteredHistory.isEmpty {
                Text(isKorean ? "클립보드 기록 없음" : "No clipboard history")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredHistory.enumerated()), id: \ .offset) { (index, item) in
                                    FocusableRow(
                                        index: index,
                                        selectedIndex: $selectedIndex,
                                        onSelect: { onSelect(item) }
                                    ) {
                                        Button(action: { onSelect(item) }) {
                                            switch item.type {
                                            case .text(let string):
                                                let displayText = string.count > 50 ? String(string.prefix(50)) + "..." : string
                                                Text(displayText)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .font(.system(size: 12))
                                                    .padding(.vertical, 4)
                                                    .padding(.leading, 12)
                                                    .frame(maxWidth: 180, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            case .image(let image, _):
                                                HStack(spacing: 8) {
                                                    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                                        Image(decorative: cgImage, scale: 1.0)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 30, height: 30)
                                                            .cornerRadius(4)
                                                    } else {
                                                        Text(isKorean ? "[이미지]" : "[Image]")
                                                            .font(.system(size: 12))
                                                    }
                                                    if let name = item.name {
                                                        Text(name)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                            .truncationMode(.middle)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                                .padding(.leading, 12)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        Spacer(minLength: 0)
                                        if index < keyMap.count {
                                            Text(keyMap[index])
                                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .frame(width: 18, alignment: .trailing)
                                                .padding(.trailing, 12)
                                        } else {
                                            Spacer().frame(width: 18)
                                        }
                                    }
                                    .id(index)
                                    Divider()
                                }
                            }
                        }
                        .background(ThinScrollbar())
                        .onChange(of: selectedIndex) { idx in
                            if let idx = idx {
                                withAnimation { proxy.scrollTo(idx, anchor: .center) }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            VStack {
                Spacer()
                Button(action: {
                    clipboardManager.history.removeAll()
                }) {
                    Text(isKorean ? "전체 삭제" : "Clear All")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 0)
                .padding(.bottom, 16)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(25)
        .frame(width: 320)
        .onAppear {
            // 창이 열릴 때 첫 번째 아이템에 선택
            if !filteredHistory.isEmpty {
                selectedIndex = 0
            }
            // 키보드 네비게이션/엔터/숫자키/삭제 핸들러 등록
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let key = event.charactersIgnoringModifiers ?? ""
                if event.keyCode == 125 { // ↓
                    if let idx = selectedIndex, idx < filteredHistory.count - 1 {
                        selectedIndex = idx + 1
                    }
                    return nil
                } else if event.keyCode == 126 { // ↑
                    if let idx = selectedIndex, idx > 0 {
                        selectedIndex = idx - 1
                    }
                    return nil
                } else if event.keyCode == 36 || event.keyCode == 76 { // Return/Enter
                    if let idx = selectedIndex, filteredHistory.indices.contains(idx) {
                        onSelect(filteredHistory[idx])
                        return nil
                    }
                } else if event.keyCode == 51 { // Delete(⌫)
                    if let idx = selectedIndex, filteredHistory.indices.contains(idx) {
                        let item = filteredHistory[idx]
                        if let realIdx = clipboardManager.history.firstIndex(of: item) {
                            clipboardManager.history.remove(at: realIdx)
                            // 삭제 후 포커스 이동
                            if clipboardManager.history.isEmpty {
                                selectedIndex = nil
                            } else if idx >= clipboardManager.history.count {
                                selectedIndex = clipboardManager.history.count - 1
                            }
                        }
                        return nil
                    }
                } else if let idx = keyMap.firstIndex(of: key.lowercased()), filteredHistory.indices.contains(idx) {
                    onSelect(filteredHistory[idx])
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            // 키보드 모니터 해제
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                        guard let data = data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        DispatchQueue.main.async {
                            if let image = NSImage(contentsOf: url) {
                                let name = url.lastPathComponent
                                clipboardManager.addImageToClipboard(image, name: name)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadObject(ofClass: NSImage.self) { image, error in
                        guard let image = image as? NSImage else { return }
                        DispatchQueue.main.async {
                            let name = provider.suggestedName
                            clipboardManager.addImageToClipboard(image, name: name)
                        }
                    }
                }
            }
            return true
        }
    }
}

struct FocusableRow<Content: View>: View {
    let index: Int
    @Binding var selectedIndex: Int?
    let onSelect: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false
    var body: some View {
        ZStack {
            if isHovering || selectedIndex == index {
                Color.accentColor.opacity(isHovering ? 0.12 : 0.18)
                    .cornerRadius(6)
            } else {
                Color.clear // 불투명 배경 없이 투명만
            }
            HStack(spacing: 8) {
                content()
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
//        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering { selectedIndex = index }
        }
        .onTapGesture { onSelect() }
    }
}
 