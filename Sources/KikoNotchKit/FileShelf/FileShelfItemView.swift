import SwiftUI
import AppKit

/// Card view for a single file staged on the File Shelf with drag-out support
public struct FileShelfItemView: View {
    @ObservedObject public var item: FileShelfItem
    @State private var isHovered = false
    
    public init(item: FileShelfItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail preview or fallback icon
                Group {
                    if let thumb = item.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "doc")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .cornerRadius(6)
                
                // Quick remove button on hover
                if isHovered {
                    Button {
                        FileShelfManager.shared.removeItem(id: item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                    .accessibilityLabel("Remove \(item.name)")
                }
            }
            .frame(width: 48, height: 48)
            
            // Filename
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 64)
            
            // Filesize
            Text(item.formattedSize)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            FileShelfManager.shared.openFile(item: item)
        }
        // Drag-out capability: drag into Finder, Mail, Slack, Terminal, etc.
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
        }
        .fileShelfContextMenu(for: item)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), size \(item.formattedSize)")
        .accessibilityHint("Double click to open, drag to copy or move to Finder or apps")
    }
}
