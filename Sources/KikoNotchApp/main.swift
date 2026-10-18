import AppKit
import SwiftUI
import KikoNotchKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Kiko Notch] Application starting up...")
        
        // Start core systems and present island
        AppLifecycle.shared.startApplication()
        
        NotificationCenter.default.post(name: NSNotification.Name("KikoAppDidFinishLaunching"), object: nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Running as menu bar / floating island companion
        return false
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
