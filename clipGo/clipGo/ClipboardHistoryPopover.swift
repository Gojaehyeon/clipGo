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
                            Text(string)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
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