import SwiftUI
import AppKit

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
                                    HStack(alignment: .center, spacing: 8) {
                                        Button(action: { onSelect(item) }) {
                                            switch item.type {
                                            case .text(let string):
                                                let displayText = string.count > 50 ? String(string.prefix(50)) + "..." : string
                                                Text(displayText)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .font(.system(size: 12))
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 4)
                                                    .frame(maxWidth: 180, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            case .image(let image):
                                                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                                    Image(decorative: cgImage, scale: 1.0)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 30, height: 30)
                                                        .cornerRadius(4)
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 4)
                                                } else {
                                                    Text(isKorean ? "[이미지]" : "[Image]")
                                                        .font(.system(size: 12))
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 4)
                                                }
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .onTapGesture {
                                            onSelect(item)
                                        }
                                        .onHover { hovering in
                                            if hovering {
                                                selectedIndex = index
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        // 숫자 인덱스 (1~9만)
                                        if index < 9 {
                                            Text("\(index+1)")
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .frame(width: 18, alignment: .trailing)
                                        } else {
                                            Spacer().frame(width: 18)
                                        }
                                        // 삭제 버튼 (오른쪽)
                                        /*
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
                                        */
                                    }
                                    .id(index)
                                    .background(selectedIndex == index ? Color.accentColor.opacity(0.18) : Color.clear)
                                    .cornerRadius(6)
                                    .padding(.horizontal, 8)
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
        .padding(8)
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
                } else if let num = Int(key), num >= 1, num <= 9, filteredHistory.count >= num {
                    onSelect(filteredHistory[num-1])
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