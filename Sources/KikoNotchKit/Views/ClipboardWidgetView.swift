import SwiftUI

/// Clipboard history browser in expanded island with copy-back action.
/// Implements CLIP-003.
public struct ClipboardWidgetView: View {
    @ObservedObject public var clipboardManager: ClipboardManager
    
    public init(clipboardManager: ClipboardManager? = nil) {
        self.clipboardManager = clipboardManager ?? ClipboardManager.shared
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Clipboard History", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .bold))
                
                Spacer()
                
                if !clipboardManager.items.isEmpty {
                    Button(action: {
                        clipboardManager.clearAllHistory()
                    }) {
                        Text("Clear")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if clipboardManager.items.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundColor(.secondary)
                    Text("Clipboard history is empty.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(clipboardManager.items.prefix(4)) { item in
                        clipboardRow(item)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private func clipboardRow(_ item: ClipboardItem) -> some View {
        Button(action: {
            clipboardManager.copyBackToPasteboard(item)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.left.down")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                
                Text(item.text)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(item.characterCount) chars")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .help("Click to copy back to pasteboard")
    }
}
