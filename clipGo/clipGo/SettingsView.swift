import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("클립보드 팝업 단축키", name: .showClipboard)
        }
        .padding()
        .frame(width: 320)
    }
} 