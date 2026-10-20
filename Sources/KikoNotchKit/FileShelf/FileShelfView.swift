import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Staging shelf view with drop target and horizontal scrolling cards
public struct FileShelfView: View {
    @ObservedObject public var manager = FileShelfManager.shared
    @State private var isTargeted = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with badge and clear all
            HStack {
                Label("File Shelf", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if !manager.items.isEmpty {
                    Text("\(manager.items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.12)))
                }
                
                Spacer()
                
                if !manager.items.isEmpty {
                    Button {
                        manager.clearAll()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear all files from shelf")
                }
            }
            .padding(.horizontal, 4)
            
            // Shelf Content Area: Drag Target Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? AccentThemeManager.shared.horizontalGradient : LinearGradient(colors: [Color.primary.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [6, 3] : [])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? AccentThemeManager.shared.subtleBackgroundGradient : LinearGradient(colors: [Color.primary.opacity(0.04)], startPoint: .leading, endPoint: .trailing))
                    )
                
                if manager.items.isEmpty {
                    // Empty drop invitation
                    HStack(spacing: 8) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("Drop files here to stage or transfer")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                } else {
                    // Staged files scroll list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(manager.items) { item in
                                FileShelfItemView(item: item)
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(height: manager.items.isEmpty ? 50 : 88)
            // NSDraggingDestination Drop Target Handler
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                var urls: [URL] = []
                let group = DispatchGroup()
                
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            urls.append(url)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if !urls.isEmpty {
                        self.manager.addFiles(urls: urls)
                    }
                }
                return true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("File staging shelf")
    }
}
