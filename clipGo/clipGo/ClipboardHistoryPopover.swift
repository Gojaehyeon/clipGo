import SwiftUI

struct ClipboardHistoryPopover: View {
    @ObservedObject var clipboardManager: ClipboardManager
    var onSelect: (ClipboardItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(clipboardManager.history) { item in
                Button(action: { onSelect(item) }) {
                    HStack(alignment: .center, spacing: 8) {
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
                }
                .buttonStyle(PlainButtonStyle())
                Divider()
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .frame(width: 320)
        .padding(8)
    }
} 