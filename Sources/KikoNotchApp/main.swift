import AppKit
import SwiftUI
import KikoNotchKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Kiko Notch] Application starting up...")

        // Start core systems and present island synchronously
        AppLifecycle.shared.startApplication(runEventLoopIfNeeded: false)

        if ProcessInfo.processInfo.environment["KIKO_START_EXPANDED"] == "1" ||
           CommandLine.arguments.contains("--expanded") {
            InteractionManager.shared.isPinned = true
            InteractionManager.shared.transition(to: .expanded)
        }

        func matchTab(_ raw: String) -> IslandTab? {
            let clean = raw.lowercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
            return IslandTab.allCases.first(where: {
                let candidate1 = $0.rawValue.lowercased().filter { !$0.isWhitespace }
                let candidate2 = $0.shortLabel.lowercased().filter { !$0.isWhitespace }
                let candidate3 = $0.title.lowercased().filter { !$0.isWhitespace }
                return candidate1 == clean || candidate2 == clean || candidate3 == clean || candidate1.contains(clean) || clean.contains(candidate1)
            })
        }

        if let tabEnv = ProcessInfo.processInfo.environment["KIKO_START_TAB"],
           let tab = matchTab(tabEnv) {
            IslandNavigationModel.shared.selectTab(tab)
        }
        for arg in CommandLine.arguments {
            if arg.hasPrefix("--tab=") {
                let name = String(arg.dropFirst(6))
                if let tab = matchTab(name) {
                    IslandNavigationModel.shared.selectTab(tab)
                }
            }
        }

        if ProcessInfo.processInfo.environment["KIKO_OPEN_SETTINGS"] == "1" ||
           CommandLine.arguments.contains("--settings") {
            let tabString = ProcessInfo.processInfo.environment["KIKO_SETTINGS_TAB"]?.lowercased().filter { !$0.isWhitespace && $0 != "&" && $0 != "-" }
            let targetTab = SettingsTab.allCases.first { tab in
                guard let cleanInput = tabString, !cleanInput.isEmpty else { return false }
                let cleanRaw = tab.rawValue.lowercased().filter { !$0.isWhitespace && $0 != "&" && $0 != "-" }
                return cleanRaw == cleanInput || cleanRaw.contains(cleanInput) || cleanInput.contains(cleanRaw)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SettingsWindowController.shared.showSettings(tab: targetTab)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Running as menu bar / floating island companion
        return false
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate.shared
AppLifecycle.shared.appDelegate = delegate
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
