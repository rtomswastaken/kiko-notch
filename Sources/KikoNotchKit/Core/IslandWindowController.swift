import Foundation
import AppKit
import SwiftUI
import Combine

/// Native AppKit Window and Panel Controller for Kiko Notch Floating Island
@MainActor
public final class IslandWindowController: NSObject, ObservableObject {
    public static let shared = IslandWindowController()
    
    public private(set) var window: IslandPanel?
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFrame = false
    
    private override init() {
        super.init()
    }
    
    /// Initializes and presents the floating island window
    public func showIsland() {
        guard window == nil else {
            window?.orderFrontRegardless()
            return
        }
        
        // 1. Calculate initial frame for collapsed state
        DisplayManager.shared.updateScreenConfiguration()
        let initialFrame = DisplayManager.shared.frame(for: .collapsed)
        
        // 2. Configure Non-Activating Borderless Panel
        let panel = IslandPanel(contentRect: initialFrame)
        
        // 3. Screen Capture Exclusion (CORE-010)
        panel.updateScreenCaptureSharing()
        
        // 4. Set Hosting View
        let hostingView = IslandHostingView(rootView: IslandContainerView())
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        self.window = panel
        panel.orderFrontRegardless()
        
        // 5. Setup Observers for State, Display, Geometry, and Screen Capture
        setupBindings()
    }
    
    private func setupBindings() {
        // State changes -> Animate window geometry
        InteractionManager.shared.onStateChange = { [weak self] newState in
            self?.updateWindowFrame(for: newState)
        }
        
        // Screen parameters or Display changes
        DisplayManager.shared.$targetScreen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateWindowFrame(for: InteractionManager.shared.currentState)
            }
            .store(in: &cancellables)
        
        // Geometry preference updates
        SettingsManager.shared.$geometry
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateWindowFrame(for: InteractionManager.shared.currentState)
            }
            .store(in: &cancellables)
            
        // Screen capture preference updates
        SettingsManager.shared.$hideFromScreenCapture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let panel = self.window else { return }
                panel.updateScreenCaptureSharing()
            }
            .store(in: &cancellables)
    }
    
    public func updateWindowFrame(for state: IslandDisplayState) {
        guard let panel = window, !isUpdatingFrame else { return }
        isUpdatingFrame = true
        
        let targetRect = DisplayManager.shared.frame(for: state)
        
        IslandAnimationEngine.animate(window: panel, to: targetRect, for: state) { [weak self] in
            self?.isUpdatingFrame = false
        }
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

// MARK: - Custom NSHostingView with Event Tracking & Drag Drop

public final class IslandHostingView: NSHostingView<IslandContainerView> {
    private var trackingAreaRef: NSTrackingArea?
    
    @MainActor public required init(rootView: IslandContainerView) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
        self.trackingAreaRef = tracking
    }
    
    public override func mouseEntered(with event: NSEvent) {
        InteractionManager.shared.mouseEntered()
    }
    
    public override func mouseExited(with event: NSEvent) {
        InteractionManager.shared.mouseExited()
    }
    
    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            InteractionManager.shared.handleDoubleClick()
        } else {
            InteractionManager.shared.handleSingleClick()
        }
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        InteractionManager.shared.handleRightClick(with: event, in: self)
    }
    
    public override func scrollWheel(with event: NSEvent) {
        InteractionManager.shared.handleScrollWheel(deltaY: event.scrollingDeltaY)
    }
    
    // MARK: - Drag and Drop File Staging (FILES-001)
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue]) {
            // Expand island to receive files
            if InteractionManager.shared.currentState != .expanded {
                InteractionManager.shared.transition(to: .expanded)
            }
            return .copy
        }
        return []
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let items = pasteboard.pasteboardItems else { return false }
        
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
        return false
    }
}
