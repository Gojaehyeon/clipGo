import SwiftUI

struct ClipboardHistoryPopover: View {
    @ObservedObject var clipboardManager: ClipboardManager
    var onSelect: (ClipboardItem) -> Void
    var onChangeHotkey: (() -> Void)? = nil
    @State private var selectedTab: Tab = .all
    @State private var keyMonitor: Any? = nil
    
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text(isKorean ? "전체" : "All").tag(Tab.all)
                Text(isKorean ? "즐겨찾기" : "Bookmark").tag(Tab.favorite)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 8)
            if filteredHistory.isEmpty {
                Text(isKorean ? "클립보드 기록 없음" : "No clipboard history")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            // Change Hotkey 버튼 위에 전체 삭제 버튼 추가
            Button(action: {
                clipboardManager.history.removeAll()
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text(isKorean ? "전체 삭제" : "Clear All")
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .font(.system(size: 13, weight: .regular))
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            // Change Hotkey 버튼
            if let onChangeHotkey = onChangeHotkey {
                Button(action: { onChangeHotkey() }) {
                    HStack {
                        Spacer()
                        Image(systemName: "keyboard")
                        Text(isKorean ? "단축키 변경" : "Change Hotkey")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 13, weight: .regular))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            ForEach(Array(filteredHistory.enumerated()), id: \ .element.id) { (index, item) in
                HStack(alignment: .center, spacing: 8) {
                    // 단축키 안내
                    if index == 0 {
                        Text("⏎")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 22)
                    } else if index <= 9 {
                        Text("\(index)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 22)
                    } else {
                        Spacer().frame(width: 22)
                    }
                    // 즐겨찾기 버튼 (왼쪽)
                    Button(action: {
                        if let idx = clipboardManager.history.firstIndex(of: item) {
                            clipboardManager.history[idx].isFavorite.toggle()
                        }
                    }) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .foregroundColor(item.isFavorite ? .yellow : .secondary)
                            .imageScale(.medium)
                            .help(isKorean ? "즐겨찾기" : "Bookmark")
                    }
                    .buttonStyle(PlainButtonStyle())
                    // 본문(텍스트/이미지)
                    Button(action: { onSelect(item) }) {
                        switch item.type {
                        case .text(let string):
                            let displayText = string.count > 50 ? String(string.prefix(50)) + "..." : string
                            Text(displayText)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .padding(8)
                                .frame(maxWidth: 220, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        case .image(let image):
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                Image(decorative: cgImage, scale: 1.0)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                                    .padding(8)
                            } else {
                                Text(isKorean ? "[이미지]" : "[Image]")
                                    .padding(8)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer(minLength: 0)
                    // 삭제 버튼 (오른쪽)
                    Button(action: {
                        if let idx = clipboardManager.history.firstIndex(of: item) {
                            clipboardManager.history.remove(at: idx)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .imageScale(.medium)
                            .padding(.trailing, 4)
                            .help(isKorean ? "삭제" : "Delete")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Divider()
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .frame(width: 320)
        .padding(8)
        .onAppear {
            // 키보드 단축키 모니터 등록
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let key = event.charactersIgnoringModifiers ?? ""
                if key == "\r" || key == "\n" { // Return/Enter
                    if let first = filteredHistory.first {
                        onSelect(first)
                        return nil
                    }
                } else if let num = Int(key), num > 0, num <= 9, filteredHistory.count > num {
                    onSelect(filteredHistory[num])
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
    }
} 