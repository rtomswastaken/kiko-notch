import Foundation
import AppKit
import Combine

/// Dispatches mouse, trackpad, gesture, and global interaction events for the Kiko Notch Island
public final class InteractionManager: ObservableObject, @unchecked Sendable {
    public static let shared = InteractionManager()
    
    @Published public private(set) var currentState: IslandDisplayState = .collapsed
    @Published public var isPinned: Bool = false {
        didSet {
            if isPinned && currentState != .expanded {
                transition(to: .expanded)
            }
        }
    }
    
    public var displayState: IslandDisplayState {
        get { currentState }
        set { transition(to: newValue) }
    }
    
    public var isHovered: Bool {
        currentState == .peek
    }
    
    public var onStateChange: ((IslandDisplayState) -> Void)?
    public var onOpenSettings: (() -> Void)?
    
    private var hoverWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var globalClickMonitor: Any?
    
    private init() {
        setupGlobalClickDismissal()
    }
    
    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        hoverWorkItem?.cancel()
        collapseWorkItem?.cancel()
    }
    
    // MARK: - State Transitions
    
    public func transition(to newState: IslandDisplayState) {
        guard currentState != newState else { return }
        currentState = newState
        onStateChange?(newState)
    }
    
    public func toggleExpandCollapse() {
        if currentState == .collapsed {
            transition(to: .expanded)
        } else if currentState == .expanded || currentState == .pinned {
            if !isPinned {
                transition(to: .collapsed)
            }
        }
    }
    
    public func togglePin() {
        isPinned.toggle()
        if isPinned && currentState != .expanded {
            transition(to: .expanded)
        }
    }
    
    public func collapse() {
        if !isPinned {
            transition(to: .collapsed)
        }
    }
    
    public func expand() {
        transition(to: .expanded)
    }
    
    // MARK: - Hover Tracking & Delayed Expand/Collapse
    
    public func handleMouseEnter() {
        mouseEntered()
    }
    
    public func handleMouseExit() {
        mouseExited()
    }
    
    public func mouseEntered() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard currentState == .collapsed else { return }
        
        // Show subtle peek immediately if configured
        transition(to: .peek)
        
        let delayMs = SettingsManager.shared.hoverDelayMs
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.currentState == .peek else { return }
            self.transition(to: .expanded)
        }
        self.hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: work)
    }
    
    public func mouseExited() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        
        guard currentState == .expanded || currentState == .peek else { return }
        guard !isPinned else { return }
        
        let delayMs = SettingsManager.shared.collapseDelayMs
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isPinned else { return }
            self.transition(to: .collapsed)
        }
        self.collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: work)
    }
    
    // MARK: - Mouse Click Dispatchers
    
    public func handleSingleClick() {
        toggleExpandCollapse()
    }
    
    public func handleDoubleClick() {
        onOpenSettings?()
    }
    
    public func handleRightClick(with event: NSEvent, in view: NSView) {
        let menu = NSMenu(title: "Kiko Notch")
        
        let toggleItem = NSMenuItem(
            title: currentState == .collapsed ? "Expand Island" : "Collapse Island",
            action: #selector(menuToggleAction),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let pinItem = NSMenuItem(
            title: isPinned ? "Unpin Island" : "Pin Island Expanded",
            action: #selector(menuPinAction),
            keyEquivalent: ""
        )
        pinItem.target = self
        menu.addItem(pinItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(menuSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit Kiko Notch",
            action: #selector(menuQuitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
    
    @objc private func menuToggleAction() {
        toggleExpandCollapse()
    }
    
    @objc private func menuPinAction() {
        togglePin()
    }
    
    @objc private func menuSettingsAction() {
        onOpenSettings?()
    }
    
    @objc private func menuQuitAction() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Swipe Gesture Handling
    
    public func handleScrollWheel(event: NSEvent) {
        handleScrollWheel(deltaY: event.scrollingDeltaY)
    }
    
    public func handleScrollWheel(deltaY: CGFloat) {
        // Downward trackpad swipe: expand
        if deltaY < -2.0 && currentState == .collapsed {
            transition(to: .expanded)
        }
        // Upward trackpad swipe: collapse
        else if deltaY > 2.0 && (currentState == .expanded || currentState == .peek) && !isPinned {
            transition(to: .collapsed)
        }
    }
    
    // MARK: - Click-Outside Dismissal
    
    private func setupGlobalClickDismissal() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self else { return }
            // If expanded and not pinned, clicking anywhere outside dismisses back to collapsed
            if (self.currentState == .expanded || self.currentState == .peek) && !self.isPinned {
                DispatchQueue.main.async {
                    self.transition(to: .collapsed)
                }
            }
        }
    }
}
