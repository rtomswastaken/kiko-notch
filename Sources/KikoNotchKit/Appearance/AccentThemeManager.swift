//
//  AccentThemeManager.swift
//  KikoNotchKit
//
//  Centralized Dynamic Multi-Color Gradient Accent Theme System.
//  Coordinates artwork-derived palettes, smooth color transitions, and white fallback.
//

import SwiftUI
import AppKit

/// Represents a coordinated 2- or 3-color accent palette extracted from media artwork.
public struct AccentPalette: Equatable, Sendable {
    public let primary: Color
    public let secondary: Color
    public let tertiary: Color?
    /// Normalized exactly-3-stop color array for smooth jump-free transitions in SwiftUI gradients
    public let colors: [Color]
    public let isDefaultWhite: Bool
    public let id: String

    public init(
        primary: Color,
        secondary: Color,
        tertiary: Color? = nil,
        isDefaultWhite: Bool = false,
        id: String = UUID().uuidString
    ) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.isDefaultWhite = isDefaultWhite
        self.id = id

        if let tert = tertiary {
            self.colors = [primary, secondary, tert]
        } else {
            // For a 2-color palette, provide a 3-stop normalized progression [primary, midpoint, secondary]
            // so SwiftUI never changes gradient stop count, avoiding popping/jumps during animation!
            self.colors = [primary, secondary, secondary]
        }
    }

    /// Default crisp monochrome white palette with subtle silver depth
    public static let defaultWhite = AccentPalette(
        primary: Color.white,
        secondary: Color(white: 0.85),
        tertiary: Color(white: 0.72),
        isDefaultWhite: true,
        id: "default-white"
    )

    public var linearGradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    public func gradient(start: UnitPoint = .leading, end: UnitPoint = .trailing) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: start, endPoint: end)
    }

    public var horizontalGradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    public var verticalGradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    public var subtleBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: colors.map { $0.opacity(0.12) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public var borderGradient: LinearGradient {
        LinearGradient(
            colors: colors.map { $0.opacity(0.38) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public var foregroundOnAccent: Color {
        isDefaultWhite ? Color.black : Color.white
    }
}

/// Centralized Accent Theme Manager managing application-wide dynamic gradient styling.
public final class AccentThemeManager: ObservableObject, @unchecked Sendable {
    public static let shared = AccentThemeManager()

    @Published public private(set) var currentPalette: AccentPalette = .defaultWhite

    private let lock = NSLock()
    private var _palette: AccentPalette = .defaultWhite

    public var palette: AccentPalette {
        lock.lock()
        defer { lock.unlock() }
        return _palette
    }

    public var primaryAccent: Color { palette.primary }
    public var secondaryAccent: Color { palette.secondary }
    public var tertiaryAccent: Color? { palette.tertiary }
    public var colors: [Color] { palette.colors }
    public var linearGradient: LinearGradient { palette.linearGradient }
    public var horizontalGradient: LinearGradient { palette.horizontalGradient }
    public var verticalGradient: LinearGradient { palette.verticalGradient }
    public var subtleBackgroundGradient: LinearGradient { palette.subtleBackgroundGradient }
    public var borderGradient: LinearGradient { palette.borderGradient }
    public var foregroundOnAccent: Color { palette.foregroundOnAccent }
    public var isDefaultWhite: Bool { palette.isDefaultWhite }

    private init() {}

    /// Updates the global accent palette with a smooth 0.85-second transition.
    public func updatePalette(_ newPalette: AccentPalette, animated: Bool = true) {
        lock.lock()
        guard newPalette.id != _palette.id else {
            lock.unlock()
            return
        }
        _palette = newPalette
        lock.unlock()

        if Thread.isMainThread {
            if animated {
                withAnimation(.easeInOut(duration: 0.85)) {
                    self.currentPalette = newPalette
                }
            } else {
                self.currentPalette = newPalette
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if animated {
                    withAnimation(.easeInOut(duration: 0.85)) {
                        self.currentPalette = newPalette
                    }
                } else {
                    self.currentPalette = newPalette
                }
            }
        }
    }

    /// Resets the accent palette back to the clean white monochrome theme.
    public func resetToWhite(animated: Bool = true) {
        guard !isDefaultWhite else { return }
        updatePalette(.defaultWhite, animated: animated)
    }
}
