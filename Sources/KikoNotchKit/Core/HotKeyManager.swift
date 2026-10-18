import Foundation
import AppKit
import Carbon

/// Manages global keyboard shortcuts (e.g. Cmd+Shift+Space) to toggle the island
public final class HotKeyManager: ObservableObject, @unchecked Sendable {
    public static let shared = HotKeyManager()
    
    public var onToggle: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    private init() {
        registerDefaultHotKey()
    }
    
    deinit {
        unregisterHotKey()
    }
    
    /// Registers the default global hotkey: Cmd + Shift + Space
    public func registerDefaultHotKey() {
        unregisterHotKey()
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x4B494B4F), id: 1) // "KIKO", 1
        let modifierFlags: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 49 // Space bar keycode
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if status == noErr && hkID.id == 1 {
                DispatchQueue.main.async {
                    HotKeyManager.shared.onToggle?()
                }
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    public func unregisterHotKey() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
        if let eh = eventHandlerRef {
            RemoveEventHandler(eh)
            eventHandlerRef = nil
        }
    }
}
