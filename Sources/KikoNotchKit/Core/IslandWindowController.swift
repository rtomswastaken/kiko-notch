import Foundation
import AppKit
import SwiftUI
import Combine

/// Native AppKit Window and Panel Controller for Kiko Notch Floating Island
/// Built on the Boring Notch window foundation (fixed top-anchored panel).
@MainActor
public final class IslandWindowController: NSObject, ObservableObject {
    public static let shared = IslandWindowController()

    public private(set) var window: IslandPanel?
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFrame = false
    private var trackpadScrollMonitor: Any?

    private override init() {
        super.init()
    }

    /// Initializes and presents the floating island window
    public func showIsland() {
        guard window == nil else {
            window?.orderFrontRegardless()
            return
        }

        DisplayManager.shared.updateScreenConfiguration()
        let targetScreen = DisplayManager.shared.targetScreen
        let screenFrame = targetScreen.frame
        let windowWidth = IslandGeometry.windowSize.width
        let windowHeight = IslandGeometry.windowSize.height

        let initialOrigin = NSPoint(
            x: screenFrame.origin.x + (screenFrame.width - windowWidth) / 2,
            y: screenFrame.origin.y + screenFrame.height - windowHeight
        )
        let initialFrame = NSRect(origin: initialOrigin, size: IslandGeometry.windowSize)

        // Configure Non-Activating Borderless Panel at mainMenu + 3 / statusBar
        let panel = IslandPanel(contentRect: initialFrame)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.updateScreenCaptureSharing()

        // Set Hosting View with IslandContainerView
        let hostingView = IslandHostingView(rootView: IslandContainerView())
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.window = panel
        InteractionManager.shared.isPointerInsideIsland = { [weak panel] in
            guard let panel else { return false }
            return panel.frame.contains(NSEvent.mouseLocation)
        }
        panel.setIsVisible(true)
        panel.orderFrontRegardless()

        NSLog("[Kiko Notch] Boring-Notch foundation window presented at \(panel.frame)")

        setupBindings()
    }

    private func setupBindings() {
        // Screen parameters or Display changes -> reposition panel
        DisplayManager.shared.$targetScreen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] screen in
                self?.repositionWindow(on: screen)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DisplayManager.shared.updateScreenConfiguration()
                self?.repositionWindow(on: DisplayManager.shared.targetScreen)
            }
            .store(in: &cancellables)

        // Screen capture preference updates
        SettingsManager.shared.$hideFromScreenCapture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.window?.updateScreenCaptureSharing()
            }
            .store(in: &cancellables)

        // Native trackpad swipe navigation local event monitor
        trackpadScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, let panel = self.window, event.window == panel else {
                return event
            }
            let isExpanded = InteractionManager.shared.currentState == .expanded || InteractionManager.shared.currentState == .pinned
            if isExpanded && event.hasPreciseScrollingDeltas {
                let didTrigger = TrackpadSwipeHandler.shared.handleScrollWheel(event: event)
                if didTrigger {
                    return nil // Consumed horizontal swipe gesture
                }
            }
            return event
        }
    }

    /// Positions the fixed-size panel cleanly at the top-center of the screen
    public func repositionWindow(on screen: NSScreen? = nil) {
        guard let panel = window else { return }
        let targetScreen = screen ?? DisplayManager.shared.targetScreen
        let screenFrame = targetScreen.frame
        let windowWidth = IslandGeometry.windowSize.width
        let windowHeight = IslandGeometry.windowSize.height

        let newOrigin = NSPoint(
            x: screenFrame.origin.x + (screenFrame.width - windowWidth) / 2,
            y: screenFrame.origin.y + screenFrame.height - windowHeight
        )
        panel.setFrameOrigin(newOrigin)
    }

    /// Compatibility method for tests; ensures correct placement without jarring window resizes
    public func updateWindowFrame(for state: IslandDisplayState) {
        repositionWindow()
    }
}

// MARK: - Custom Non-Activating Floating NSPanel

@MainActor
public class IslandPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.isMovable = false
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        updateScreenCaptureSharing()
    }

    public func updateScreenCaptureSharing() {
        if SettingsManager.shared.hideFromScreenCapture {
            self.sharingType = .none
        } else {
            self.sharingType = .readOnly
        }
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Custom NSHostingView with Drag Drop Staging

public final class IslandHostingView: NSHostingView<IslandContainerView> {
    @MainActor public required init(rootView: IslandContainerView) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }

    public override func rightMouseDown(with event: NSEvent) {
        InteractionManager.shared.handleRightClick(with: event, in: self)
    }

    public override func scrollWheel(with event: NSEvent) {
        let isExpanded = InteractionManager.shared.currentState == .expanded || InteractionManager.shared.currentState == .pinned

        // 1. In collapsed state: downward trackpad swipe expands the island
        if !isExpanded {
            if event.scrollingDeltaY < -3.0 && InteractionManager.shared.currentState == .collapsed {
                InteractionManager.shared.transition(to: .expanded)
            }
            return
        }

        // 2. In expanded state: check for horizontal trackpad swipe navigation
        let didTriggerSwipe = TrackpadSwipeHandler.shared.handleScrollWheel(event: event)
        if didTriggerSwipe {
            return
        }

        // 3. Forward vertical/content scroll events down to SwiftUI (SystemTabView ScrollView, etc.)
        super.scrollWheel(with: event)
    }

    // MARK: - Drag and Drop File Staging

    private var priorStateBeforeDrag: IslandDisplayState?
    private var priorTabBeforeDrag: IslandTab?

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let canRead = pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.fileURL.rawValue,
            NSPasteboard.PasteboardType.string.rawValue
        ])
        if canRead {
            if priorStateBeforeDrag == nil {
                priorStateBeforeDrag = InteractionManager.shared.currentState
            }
            if priorTabBeforeDrag == nil {
                priorTabBeforeDrag = IslandNavigationModel.shared.activeTab
            }
            InteractionManager.shared.beginDragSession()
            IslandNavigationModel.shared.selectTab(.fileShelf)
            return .copy
        }
        return []
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let canRead = pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.fileURL.rawValue,
            NSPasteboard.PasteboardType.string.rawValue
        ])
        if canRead {
            if !InteractionManager.shared.isDragSessionActive {
                InteractionManager.shared.beginDragSession()
            }
            return .copy
        }
        return []
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        // If the pointer is still inside the window frame, do not prematurely collapse.
        // This prevents AppKit subview transitions or internal SwiftUI boundaries from closing the island.
        if let window = self.window {
            let screenMouse = NSEvent.mouseLocation
            if window.frame.contains(screenMouse) {
                return
            }
        }

        // The drag truly left the island window
        InteractionManager.shared.endDragSession(completedDrop: false)

        if let priorState = priorStateBeforeDrag {
            if priorState == .collapsed {
                InteractionManager.shared.transition(to: .collapsed)
            }
            priorStateBeforeDrag = nil
        }
        if let priorTab = priorTabBeforeDrag {
            IslandNavigationModel.shared.selectTab(priorTab)
            priorTabBeforeDrag = nil
        }
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        InteractionManager.shared.isDropProcessing = true
        defer {
            InteractionManager.shared.isDropProcessing = false
            InteractionManager.shared.endDragSession(completedDrop: true)
            priorStateBeforeDrag = nil
            priorTabBeforeDrag = nil
        }

        let pasteboard = sender.draggingPasteboard

        // 1. Files
        if let items = pasteboard.pasteboardItems {
            var urls: [URL] = []
            for item in items {
                if let stringURL = item.string(forType: .fileURL), let url = URL(string: stringURL) {
                    urls.append(url)
                }
            }
            if !urls.isEmpty {
                FileShelfManager.shared.addFiles(urls: urls)
                return true
            }
        }

        // 2. Text
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = FileShelfManager.shared.addPastedText(text)
            return true
        }

        return false
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        // If a drop was cancelled or ended outside
        InteractionManager.shared.endDragSession(completedDrop: false)
        if let priorState = priorStateBeforeDrag {
            if priorState == .collapsed {
                InteractionManager.shared.transition(to: .collapsed)
            }
            priorStateBeforeDrag = nil
        }
        if let priorTab = priorTabBeforeDrag {
            IslandNavigationModel.shared.selectTab(priorTab)
            priorTabBeforeDrag = nil
        }
    }
}
