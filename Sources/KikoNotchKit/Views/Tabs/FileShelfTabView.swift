import SwiftUI
import AppKit

/// Dedicated file shelf interface inspired by Screenshot 2
public struct FileShelfTabView: View {
    @ObservedObject public var shelfManager = FileShelfManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @State private var isTargetedForDrop = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("File Shelf")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    if !shelfManager.items.isEmpty {
                        Text("\(shelfManager.items.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
                
                Spacer()
                
                if !shelfManager.items.isEmpty {
                    Button(action: {
                        shelfManager.clearAll()
                    }) {
                        Text("Clear All")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Remove all staged files")
                }
            }
            .padding(.horizontal, 4)
            
            // File Staging Area / Drop Target
            if shelfManager.items.isEmpty {
                // Empty Staging Dropzone
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 26))
                        .foregroundColor(isTargetedForDrop ? .white : themeManager.secondaryTextColor.opacity(0.6))
                    
                    Text("Drag & Drop Files Here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Stage documents, images, or archives for quick preview, sharing, and AirDrop")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(isTargetedForDrop ? 0.08 : 0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color.white.opacity(isTargetedForDrop ? 0.4 : 0.1),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                )
                .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                // Staged Items Grid / List
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88, maximum: 110), spacing: 8)], spacing: 8) {
                        ForEach(shelfManager.items) { item in
                            fileTile(for: item)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
    
    @ViewBuilder
    private func fileThumbnail(for item: FileShelfItem) -> some View {
        if let thumb = item.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "doc.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                )
        }
    }
    
    @ViewBuilder
    private func fileDeleteButton(for item: FileShelfItem) -> some View {
        Button(action: {
            shelfManager.removeItem(id: item.id)
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
    }

    @ViewBuilder
    private func fileTile(for item: FileShelfItem) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                fileThumbnail(for: item)
                fileDeleteButton(for: item)
            }
            
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(item.formattedSize)
                .font(.system(size: 8))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
        .contextMenu {
            Button("Open File") {
                shelfManager.openFile(item: item)
            }
            Button("Reveal in Finder") {
                shelfManager.revealInFinder(item: item)
            }
            Divider()
            Button("Remove from Shelf") {
                shelfManager.removeItem(id: item.id)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var dropped = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, _) in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            self.shelfManager.addFiles(urls: [url])
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            self.shelfManager.addFiles(urls: [url])
                        }
                    }
                }
                dropped = true
            }
        }
        return dropped
    }
}
