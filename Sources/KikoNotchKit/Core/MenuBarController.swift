import Foundation
import AppKit

/// Manages the companion macOS Menu Bar status item and quick access menu
public final class MenuBarController: NSObject, @unchecked Sendable {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    public var onToggleIsland: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    
    private override init() {
        super.init()
        setupStatusItem()
    }
    
    public func setupStatusItem() {
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "circle.circle.fill", accessibilityDescription: "Kiko Notch")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Kiko Notch"
        }
        
        let menu = NSMenu(title: "Kiko Notch")
        
        let headerItem = NSMenuItem(title: "Kiko Notch v\(BrandAssets.appVersion)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Toggle Island", action: #selector(toggleIslandAction), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let pinItem = NSMenuItem(title: "Pin Island Expanded", action: #selector(togglePinAction), keyEquivalent: "p")
        pinItem.target = self
        menu.addItem(pinItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Kiko Notch", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        item.menu = menu
        self.statusItem = item
    }
    
    @objc private func toggleIslandAction() {
        onToggleIsland?()
    }
    
    @objc private func togglePinAction() {
        InteractionManager.shared.isPinned.toggle()
    }
    
    @objc private func openSettingsAction() {
        onOpenSettings?()
    }
    
    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
