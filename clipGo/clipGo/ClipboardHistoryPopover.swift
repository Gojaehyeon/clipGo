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
    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isKeyboardSelection: Bool = false
    @State private var isHoveringClearAll = false
    @State private var isHoveringSort = false
    @State private var isHoveringOverBottomBar = false
    
    enum Tab { case all, favorite }
    // 정렬 모드
    enum SortMode: String, CaseIterable {
        case newest, oldest, type
        var label: String {
            switch self {
            case .newest: return Locale.current.language.languageCode?.identifier == "ko" ? "최신순" : "Newest"
            case .oldest: return Locale.current.language.languageCode?.identifier == "ko" ? "오래된순" : "Oldest"
            case .type:   return Locale.current.language.languageCode?.identifier == "ko" ? "유형별" : "By Type"
            }
        }
    }
    @State private var sortMode: SortMode = {
        if let raw = UserDefaults.standard.string(forKey: "sortMode"),
           let mode = SortMode(rawValue: raw) {
            return mode
        }
        return .newest
    }()
    var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }
    
    var filteredHistory: [ClipboardItem] {
        let base: [ClipboardItem]
        switch selectedTab {
        case .all: base = clipboardManager.history
        case .favorite: base = clipboardManager.history.filter { $0.isFavorite }
        }
        // 정렬 적용
        switch sortMode {
        case .newest:
            return base
        case .oldest:
            return base.reversed()
        case .type:
            // 이미지 먼저, 그 다음 텍스트
            let images = base.filter {
                if case .image = $0.type { return true } else { return false }
            }
            let texts = base.filter {
                if case .text = $0.type { return true } else { return false }
            }
            return images + texts
        }
    }

    var searchedHistory: [ClipboardItem] {
        if searchText.isEmpty {
            return filteredHistory
        } else {
            return filteredHistory.filter { item in
                switch item.type {
                case .text(let string):
                    return string.localizedCaseInsensitiveContains(searchText)
                case .image:
                    if let name = item.name {
                        return name.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }
            }
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
            VStack(spacing: 0) {
                // Search Bar - 항상 표시
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(isKorean ? "검색 (⌘F)" : "Search (⌘F)", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .focused($isSearchFieldFocused)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()

                // Conditional Content - 검색 결과에 따라 변경
                if filteredHistory.isEmpty {
                    Text(isKorean ? "클립보드 기록 없음" : "No clipboard history")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchedHistory.isEmpty {
                    Text(isKorean ? "검색 결과 없음" : "No search results")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(searchedHistory.enumerated()), id: \.offset) { (index, item) in
                                    FocusableRow(
                                        index: index,
                                        selectedIndex: $selectedIndex,
                                        isKeyboardSelection: $isKeyboardSelection,
                                        onSelect: { onSelect(item) }
                                    ) {
                                        Button(action: { onSelect(item) }) {
                                            switch item.type {
                                            case .text(let string):
                                                HStack {
                                                    Text(string)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .font(.system(size: 13))
                                                        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
                                                        .layoutPriority(1)
                                                    if index < keyMap.count {
                                                        Text(keyMap[index])
                                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                                            .foregroundColor(.secondary)
                                                            .frame(width: 28, alignment: .trailing)
                                                    } else {
                                                        Spacer().frame(width: 28)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 12)
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
                                        // Removed trailing keyMap label outside the Button as per instructions.
                                    }
                                    .id(index)
                                    Divider()
                                }
                            }
                        }
                        .onChange(of: selectedIndex) { idx in
                            if isKeyboardSelection, let idx = idx {
                                withAnimation { proxy.scrollTo(idx, anchor: .center) }
                            }
                        }
                        .zIndex(0)
                    }
                }
            }

            // "전체 삭제" 및 정렬 버튼 - 하단에 항상 위치, 백그라운드 클릭 차단
            if !filteredHistory.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ZStack {
                            Button(action: {
                                clipboardManager.history.removeAll()
                                searchText = ""
                            }) {
                                Text(isKorean ? "전체 삭제" : "Clear All")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(alignment: .center)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(isHoveringClearAll ? Color.accentColor.opacity(0.12) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .onHover { hovering in
                                isHoveringClearAll = hovering
                                isHoveringOverBottomBar = hovering
                            }
                            .buttonStyle(.plain)
                        }

                        ZStack {
                            Button(action: {
                                let all = SortMode.allCases
                                if let idx = all.firstIndex(of: sortMode) {
                                    let newMode = all[(idx + 1) % all.count]
                                    sortMode = newMode
                                    UserDefaults.standard.set(newMode.rawValue, forKey: "sortMode")
                                }
                            }) {
                                Text(sortMode.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(alignment: .center)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(isHoveringSort ? Color.accentColor.opacity(0.12) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .onHover { hovering in
                                isHoveringSort = hovering
                                isHoveringOverBottomBar = hovering
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 16)
                    .background(
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)
                    )
                    .zIndex(1)
                }
                .zIndex(1)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(25)
        .frame(width: 320, height: 450)
        .onChange(of: searchText) { _ in
            if !searchedHistory.isEmpty {
                selectedIndex = 0
            } else {
                selectedIndex = nil
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                isSearchFieldFocused = false
            }
            if !searchedHistory.isEmpty {
                selectedIndex = 0
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Command-F to focus search (keyCode 3 is 'f')
                if event.modifierFlags.contains(.command) && event.keyCode == 3 {
                    isSearchFieldFocused = true
                    return nil
                }
                
                // 키보드 위/아래/엔터는 항상 목록 제어
                if event.keyCode == 125 { // ↓
                    if let idx = selectedIndex, idx < searchedHistory.count - 1 {
                        isKeyboardSelection = true
                        selectedIndex = idx + 1
                    }
                    return nil
                } else if event.keyCode == 126 { // ↑
                    if let idx = selectedIndex, idx > 0 {
                        isKeyboardSelection = true
                        selectedIndex = idx - 1
                    }
                    return nil
                } else if event.keyCode == 36 || event.keyCode == 76 { // Return/Enter
                    if let idx = selectedIndex, searchedHistory.indices.contains(idx) {
                        isKeyboardSelection = true
                        onSelect(searchedHistory[idx])
                        return nil
                    }
                }

                if isSearchFieldFocused {
                    if event.keyCode == 53 { // ESC
                        isSearchFieldFocused = false
                        return nil
                    }
                    return event
                }

                let key = event.charactersIgnoringModifiers ?? ""
                if event.keyCode == 51 { // Delete(⌫)
                    if let idx = selectedIndex, searchedHistory.indices.contains(idx) {
                        let item = searchedHistory[idx]
                        if let realIdx = clipboardManager.history.firstIndex(of: item) {
                            clipboardManager.history.remove(at: realIdx)
                        }
                        return nil
                    }
                } else {
                    // Use keyCode mapping to support shortcut keys even when Korean input is active
                    let keyIndexMap: [UInt16: Int] = [
                        18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, // 1~9
                        12: 9, 13: 10, 14: 11, 15: 12, 17: 13, 16: 14, 32: 15, 34: 16, 31: 17, 35: 18, // q~p
                        0: 19, 1: 20, 2: 21, 3: 22, 5: 23, 4: 24, 38: 25, 40: 26, 37: 27, // a~l
                        6: 28, 7: 29, 8: 30, 9: 31, 11: 32, 45: 33, 46: 34 // z~m
                    ]
                    if let idx = keyIndexMap[event.keyCode], searchedHistory.indices.contains(idx) {
                        onSelect(searchedHistory[idx])
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
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
    @Binding var isKeyboardSelection: Bool
    let onSelect: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false
    @Environment(\.isHoveringOverBottomBar) private var isHoveringOverBottomBar
    var body: some View {
        ZStack {
            if isHovering || selectedIndex == index {
                Color.accentColor.opacity(isHovering ? 0.12 : 0.18)
                    .cornerRadius(6)
            }
            HStack(spacing: 8) {
                content()
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard !isHoveringOverBottomBar else { return }
            isHovering = hovering
            if hovering {
                isKeyboardSelection = false
                selectedIndex = index
            }
        }
        .onTapGesture { onSelect() }
    }
}
 


private struct IsHoveringOverBottomBarKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isHoveringOverBottomBar: Bool {
        get { self[IsHoveringOverBottomBarKey.self] }
        set { self[IsHoveringOverBottomBarKey.self] = newValue }
    }
}
