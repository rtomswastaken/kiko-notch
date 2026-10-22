import Foundation
import AppKit
import Combine

/// Manages multi-display detection, notch discovery, and screen parameter adjustments
public final class DisplayManager: ObservableObject, @unchecked Sendable {
    public static let shared = DisplayManager()
    
    @Published public private(set) var availableScreens: [NSScreen] = []
    @Published public private(set) var targetScreen: NSScreen
    @Published public private(set) var presentationMode: IslandPresentationMode
    @Published public private(set) var hasPhysicalNotch: Bool = false
    @Published public private(set) var notchRect: CGRect = .zero
    @Published public private(set) var currentScaleFactor: CGFloat = 2.0
    
    public var screens: [NSScreen] {
        availableScreens
    }
    
    public var activeScreen: NSScreen {
        targetScreen
    }
    
    private var screenChangeObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let screens = NSScreen.screens
        self.availableScreens = screens
        let initialScreen = screens.first ?? NSScreen.main ?? NSScreen()
        self.targetScreen = initialScreen
        self.presentationMode = .nonNotchFloatingPill(pillRect: .zero)
        
        updateScreenConfiguration()
        setupScreenChangeObserver()
        setupSettingsBinding()
    }
    
    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Screen Parameter Listener
    
    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateScreenConfiguration()
        }
    }
    
    private func setupSettingsBinding() {
        SettingsManager.shared.$preferredScreenIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateScreenConfiguration()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notch & Screen Evaluation
    
    public func selectScreen(at index: Int) {
        SettingsManager.shared.preferredScreenIndex = index
        updateScreenConfiguration()
    }
    
    public func displayName(for screen: NSScreen) -> String {
        return screen.localizedName
    }
    
    public func updateScreenConfiguration() {
        let screens = NSScreen.screens
        self.availableScreens = screens
        
        let preferredIndex = SettingsManager.shared.preferredScreenIndex
        let screen: NSScreen
        if preferredIndex >= 0 && preferredIndex < screens.count {
            screen = screens[preferredIndex]
        } else {
            // Fallback safely to main screen or first available
            screen = NSScreen.main ?? screens.first ?? NSScreen()
        }
        self.targetScreen = screen
        self.currentScaleFactor = screen.backingScaleFactor
        
        // Evaluate presentation mode
        let detected = Self.detectPresentationMode(for: screen)
        self.presentationMode = detected
        
        switch detected {
        case .physicalNotch(let rect):
            self.hasPhysicalNotch = true
            self.notchRect = rect
        case .nonNotchFloatingPill(let rect):
            self.hasPhysicalNotch = false
            self.notchRect = rect
        }
    }
    
    /// Detects presentation mode for any given screen
    public static func detectPresentationMode(for screen: NSScreen) -> IslandPresentationMode {
        let evaluated = evaluateNotch(for: screen)
        if evaluated.hasNotch {
            return .physicalNotch(notchRect: evaluated.rect)
        } else {
            let config = SettingsManager.shared.geometry
            let pillWidth = max(config.collapsedWidth, 120.0)
            let pillHeight = max(config.collapsedHeight, 28.0)
            let topY = screen.frame.maxY - config.nonNotchOffsetY - pillHeight
            let pillRect = CGRect(
                x: screen.frame.midX - (pillWidth / 2.0),
                y: topY,
                width: pillWidth,
                height: pillHeight
            )
            return .nonNotchFloatingPill(pillRect: pillRect)
        }
    }
    
    /// Evaluates whether a given screen has a physical hardware notch
    public static func evaluateNotch(for screen: NSScreen) -> (hasNotch: Bool, rect: CGRect) {
        // macOS 12+ auxiliaryTopLeftArea / auxiliaryTopRightArea inspection
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           leftArea.width > 0, rightArea.width > 0 {
            
            // Subpixel anti-aliasing margin (+4pt width, centered -2pt on X)
            let rawWidth = rightArea.minX - leftArea.maxX
            let notchWidth = rawWidth + 4.0
            let notchX = leftArea.maxX - 2.0
            let notchHeight = leftArea.height
            let notchY = screen.frame.maxY - notchHeight
            
            if notchWidth > 0 && notchHeight > 0 {
                let rect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
                return (true, rect)
            }
        }
        
        // Safe area fallback check
        let safeTop = screen.safeAreaInsets.top
        if safeTop > 24.0 {
            // Estimated hardware notch width (standard MacBook Pro 14"/16" notch is ~180-210pt)
            let estimatedWidth: CGFloat = 185.0
            let rect = CGRect(
                x: screen.frame.midX - (estimatedWidth / 2.0),
                y: screen.frame.maxY - safeTop,
                width: estimatedWidth,
                height: safeTop
            )
            return (true, rect)
        }
        
        return (false, .zero)
    }
    
    /// Returns calculated screen target rectangle for current state
    public func frame(for state: IslandDisplayState) -> CGRect {
        return IslandGeometry.targetRect(
            for: state,
            mode: presentationMode,
            screenFrame: targetScreen.frame,
            config: SettingsManager.shared.geometry
        )
    }
}
