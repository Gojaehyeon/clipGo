import SwiftUI

struct ClipboardHistoryPopover: View {
    @ObservedObject var clipboardManager: ClipboardManager
    var onSelect: (ClipboardItem) -> Void
    @State private var selectedTab: Tab = .all
    
    enum Tab { case all, favorite }
    
    var filteredHistory: [ClipboardItem] {
        switch selectedTab {
        case .all: return clipboardManager.history
        case .favorite: return clipboardManager.history.filter { $0.isFavorite }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("All").tag(Tab.all)
                Text("Bookmark").tag(Tab.favorite)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 8)
            ForEach(filteredHistory) { item in
                HStack(alignment: .center, spacing: 8) {
                    // 즐겨찾기 버튼 (왼쪽)
                    Button(action: {
                        if let idx = clipboardManager.history.firstIndex(of: item) {
                            clipboardManager.history[idx].isFavorite.toggle()
                        }
                    }) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .foregroundColor(item.isFavorite ? .yellow : .secondary)
                            .imageScale(.medium)
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
                                Text("[이미지]")
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
    }
} 