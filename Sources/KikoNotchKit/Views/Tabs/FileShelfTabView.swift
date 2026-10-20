import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickLook

/// Minimalist File Shelf Page featuring exclusively:
/// 1. A square-shaped Sending Container (configured destination)
/// 2. A File Shelf containing staged files, folders, and pasted text notes
public struct FileShelfTabView: View {
    @ObservedObject public var shelfManager = FileShelfManager.shared
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var senderService = FileSenderService.shared
    @ObservedObject public var themeManager = ThemeManager.shared

    @State private var isTargetedForSend = false
    @State private var isTargetedForShelf = false
    @State private var hoveredItemID: UUID? = nil
    @State private var statusFeedback: String? = nil
    @State private var quickLookURL: URL? = nil

    public init() {}

    private var destination: SendDestinationInfo {
        settings.currentSendDestination
    }

    public var body: some View {
        HStack(spacing: 12) {
            // COMPONENT 1: Square Sending Container
            sendingContainer
                .frame(width: 200)

            // COMPONENT 2: File Shelf Area
            shelfContainer
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .quickLookPreview($quickLookURL)
        .background(
            // Invisible shortcut button for ⌘V paste inside the shelf tab
            Button(action: pasteFromClipboard) {
                EmptyView()
            }
            .keyboardShortcut("v", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Component 1: Sending Container

    private var sendingContainer: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 4)

            // App Icon / Destination Symbol
            destinationIconView

            // Destination Name
            Text(destination.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(1)

            // Subtitle / Feedback
            if let feedback = statusFeedback {
                Text(feedback)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AccentThemeManager.shared.primaryAccent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            } else if destination.isAvailable {
                Text("Drop files here to send")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            } else {
                Text(destination.statusDescription)
                    .font(.system(size: 10))
                    .foregroundColor(Color.orange.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargetedForSend ? AccentThemeManager.shared.subtleBackgroundGradient : LinearGradient(colors: [Color.white.opacity(0.03)], startPoint: .leading, endPoint: .trailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargetedForSend ? AccentThemeManager.shared.horizontalGradient : LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: isTargetedForSend ? 1.5 : 1, dash: isTargetedForSend ? [6, 4] : [])
                )
        )
        .scaleEffect(isTargetedForSend ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isTargetedForSend)
        .onDrop(of: [.fileURL, .utf8PlainText, .plainText], isTargeted: $isTargetedForSend) { providers in
            handleDrop(providers: providers, isSendContainer: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sending Container for \(destination.name). Drop files here to send.")
    }

    @ViewBuilder
    private var destinationIconView: some View {
        if destination.isAvailable {
            if destination.type == .airDrop {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)

                    Image(systemName: "airdrop")
                        .font(.system(size: 26))
                        .foregroundColor(themeManager.primaryTextColor)
                }
            } else {
                Image(nsImage: destination.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Component 2: File Shelf

    private var shelfContainer: some View {
        ZStack {
            if shelfManager.items.isEmpty {
                // Understated Minimal Empty State
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))

                    Text("File Shelf")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.secondaryTextColor)

                    Text("Drop files here or press ⌘V to paste")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))

                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9))
                            Text("Paste Text")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paste text from clipboard into File Shelf")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Staged Files Scrollable List with Header & Actions
                VStack(spacing: 4) {
                    // Minimal Shelf Header Bar
                    HStack {
                        Text("\(shelfManager.items.count) item\(shelfManager.items.count == 1 ? "" : "s")")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(themeManager.secondaryTextColor)

                        Spacer()

                        Button(action: pasteFromClipboard) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 8))
                                Text("Paste")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Paste text note")

                        Button(action: { shelfManager.clearAll() }) {
                            Text("Clear")
                                .font(.system(size: 9))
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear all staged items")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    // Scrollable Items
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(shelfManager.items) { item in
                                shelfRow(for: item)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }

                    // Selected Items Contextual Bar
                    if !shelfManager.selectedItemIDs.isEmpty {
                        HStack(spacing: 6) {
                            Text("\(shelfManager.selectedItemIDs.count) selected")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(themeManager.secondaryTextColor)

                            Spacer()

                            // Quick Look action for selected item
                            if let singleSelected = shelfManager.selectedItems.first, shelfManager.selectedItems.count == 1 {
                                Button(action: {
                                    quickLookURL = singleSelected.url
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 8))
                                        Text("Preview")
                                            .font(.system(size: 9))
                                    }
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Preview selected item")
                            }

                            Button(action: {
                                shelfManager.sendItems()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: destination.systemSymbolName ?? "paperplane.fill")
                                        .font(.system(size: 8))
                                    Text("Send")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Send selected items via \(destination.name)")

                            Button(action: {
                                shelfManager.removeSelectedItems()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove selected items from shelf")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.04))
                        )
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isTargetedForShelf ? 0.08 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargetedForShelf ? Color.white.opacity(0.35) : Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: isTargetedForShelf ? 1.5 : 1, dash: isTargetedForShelf ? [6, 4] : [])
                )
        )
        .onDrop(of: [.fileURL, .utf8PlainText, .plainText], isTargeted: $isTargetedForShelf) { providers in
            handleDrop(providers: providers, isSendContainer: false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shelfManager.items.isEmpty ? "File Shelf empty. Drop files here to stage." : "File Shelf with \(shelfManager.items.count) files.")
    }

    // MARK: - File Shelf Item Row

    @ViewBuilder
    private func shelfRow(for item: FileShelfItem) -> some View {
        let isSelected = shelfManager.selectedItemIDs.contains(item.id)
        let isHovered = hoveredItemID == item.id

        HStack(spacing: 8) {
            // Thumbnail / Icon
            Group {
                if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if item.isPastedText {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.primaryTextColor.opacity(0.85))
                } else if item.isFolder {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AccentThemeManager.shared.primaryAccent)
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Filename, Preview Snippet, & Size Metadata
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.isPastedText, let snippet = item.textSnippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.system(size: 8.5))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(item.formattedSize)
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }

            Spacer(minLength: 4)

            // Hover Action Buttons: Quick Look & Remove
            if isHovered || isSelected {
                HStack(spacing: 4) {
                    Button(action: {
                        quickLookURL = item.url
                    }) {
                        Image(systemName: "eye")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quick Look \(item.name)")

                    Button(action: {
                        shelfManager.removeItem(id: item.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(item.name) from shelf")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : nil
        }
        .onTapGesture(count: 2) {
            shelfManager.openFile(item: item)
        }
        .onTapGesture(count: 1) {
            shelfManager.toggleSelection(id: item.id)
        }
        .onDrag {
            let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
            if item.isPastedText, let content = item.textContent {
                provider.registerObject(content as NSString, visibility: .all)
            }
            return provider
        }
        .fileShelfContextMenu(for: item, onQuickLook: {
            quickLookURL = item.url
        })
    }

    // MARK: - Clipboard Paste Action

    private func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        if let newItem = shelfManager.addPastedText(string) {
            withAnimation {
                self.statusFeedback = "Pasted: \(newItem.name)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    if self.statusFeedback?.starts(with: "Pasted") == true {
                        self.statusFeedback = nil
                    }
                }
            }
        }
    }

    // MARK: - Drag and Drop Handlers

    private func handleDrop(providers: [NSItemProvider], isSendContainer: Bool) -> Bool {
        var urls: [URL] = []
        var textPayloads: [String] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") ||
                      provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                    defer { group.leave() }
                    if let text = item as? String {
                        textPayloads.append(text)
                    } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                        textPayloads.append(str)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            // Process text payloads into shelf notes
            if !textPayloads.isEmpty && !isSendContainer {
                for text in textPayloads {
                    self.shelfManager.addPastedText(text)
                }
            }

            guard !urls.isEmpty else { return }

            if isSendContainer {
                // Initiate sending workflow directly
                self.triggerSendWorkflow(urls: urls)
            } else {
                // Add to shelf
                self.shelfManager.addFiles(urls: urls)
            }
        }

        return true
    }

    private func triggerSendWorkflow(urls: [URL]) {
        let dest = destination
        senderService.send(urls: urls, destination: dest) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    withAnimation {
                        self.statusFeedback = "Sent \(count) item(s)"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation {
                            if self.statusFeedback?.starts(with: "Sent") == true {
                                self.statusFeedback = nil
                            }
                        }
                    }
                case .failure(let error):
                    withAnimation {
                        self.statusFeedback = error.localizedDescription
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation {
                            self.statusFeedback = nil
                        }
                    }
                }
            }
        }
    }
}
