//
//  ArtworkColorExtractor.swift
//  KikoNotchKit
//
//  High-performance local color extraction pipeline for media artwork and thumbnails.
//  Extracts a coordinated palette of 2 or 3 vibrant, distinct complementary colors
//  with high-contrast legibility against dark backgrounds.
//

import AppKit
import Foundation
import SwiftUI

private final class PaletteCacheEntry: @unchecked Sendable {
    let palette: AccentPalette
    init(_ palette: AccentPalette) {
        self.palette = palette
    }
}

public final class ArtworkColorExtractor: @unchecked Sendable {
    public static let shared = ArtworkColorExtractor()

    private let cache = NSCache<NSString, PaletteCacheEntry>()
    private let queue = DispatchQueue(label: "kiko.artwork.colorextractor", qos: .userInitiated)

    private init() {
        cache.countLimit = 64
    }

    // MARK: - Multi-Color Palette Extraction

    /// Extracts or retrieves cached 2- or 3-color AccentPalette from raw image Data.
    public func extractPalette(from data: Data?, identifier: String) -> AccentPalette {
        guard let data = data, !data.isEmpty else {
            return .defaultWhite
        }

        let key = identifier as NSString
        if let cached = cache.object(forKey: key) {
            return cached.palette
        }

        guard let image = NSImage(data: data) else {
            return .defaultWhite
        }

        return extractPalette(from: image, identifier: identifier)
    }

    /// Extracts or retrieves cached 2- or 3-color AccentPalette from NSImage.
    public func extractPalette(from image: NSImage?, identifier: String) -> AccentPalette {
        guard let image = image else {
            return .defaultWhite
        }

        let key = identifier as NSString
        if let cached = cache.object(forKey: key) {
            return cached.palette
        }

        // Downsample to 48x48 thumbnail for sub-millisecond local pixel analysis
        let targetWidth = 48
        let targetHeight = 48
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .defaultWhite
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)

        guard let context = CGContext(
            data: &rawData,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return .defaultWhite
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Group pixels into 12 hue bins (every 30 degrees across the 360-degree color circle)
        struct ColorBin {
            var weightedR: Double = 0
            var weightedG: Double = 0
            var weightedB: Double = 0
            var totalWeight: Double = 0
            var pixelCount: Int = 0
        }

        var bins = [ColorBin](repeating: ColorBin(), count: 12)
        var totalImageWeight: Double = 0

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = Double(rawData[i]) / 255.0
            let g = Double(rawData[i + 1]) / 255.0
            let b = Double(rawData[i + 2]) / 255.0

            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let delta = maxC - minC
            let sat = maxC > 0 ? delta / maxC : 0
            let lum = 0.299 * r + 0.587 * g + 0.114 * b

            // Filter out near-black, blown-out whites, and desaturated muddy grays
            guard lum > 0.12 && lum < 0.94 && sat > 0.14 else { continue }

            var hueDeg: Double = 0
            if delta > 0.001 {
                if maxC == r {
                    hueDeg = 60.0 * (((g - b) / delta).truncatingRemainder(dividingBy: 6.0))
                } else if maxC == g {
                    hueDeg = 60.0 * (((b - r) / delta) + 2.0)
                } else {
                    hueDeg = 60.0 * (((r - g) / delta) + 4.0)
                }
                if hueDeg < 0 { hueDeg += 360.0 }
            }

            let binIndex = min(11, max(0, Int(hueDeg / 30.0)))
            let weight = sat * (1.0 - abs(lum - 0.55))

            bins[binIndex].weightedR += r * weight
            bins[binIndex].weightedG += g * weight
            bins[binIndex].weightedB += b * weight
            bins[binIndex].totalWeight += weight
            bins[binIndex].pixelCount += 1
            totalImageWeight += weight
        }

        // If artwork is monochromatic, grayscale, or lacked saturated colors: return default white
        guard totalImageWeight > 0.1 else {
            let whitePalette = AccentPalette.defaultWhite
            cache.setObject(PaletteCacheEntry(whitePalette), forKey: key)
            return whitePalette
        }

        // Rank populated bins by total weight
        struct CandidateColor {
            let color: NSColor
            let hue: CGFloat
            let saturation: CGFloat
            let brightness: CGFloat
            let weight: Double
        }

        var candidates: [CandidateColor] = []

        for bin in bins where bin.totalWeight > 0 {
            let avgR = bin.weightedR / bin.totalWeight
            let avgG = bin.weightedG / bin.totalWeight
            let avgB = bin.weightedB / bin.totalWeight

            let base = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            // Enforce minimum contrast against dark notch background
            let boostedB = max(0.68, min(0.96, b))
            let boostedS = max(0.40, min(0.95, s))
            let adjusted = NSColor(hue: h, saturation: boostedS, brightness: boostedB, alpha: 1.0)

            candidates.append(CandidateColor(
                color: adjusted,
                hue: h * 360.0,
                saturation: boostedS,
                brightness: boostedB,
                weight: bin.totalWeight
            ))
        }

        candidates.sort { $0.weight > $1.weight }

        guard let primaryCand = candidates.first else {
            let whitePalette = AccentPalette.defaultWhite
            cache.setObject(PaletteCacheEntry(whitePalette), forKey: key)
            return whitePalette
        }

        func hueDistance(_ h1: CGFloat, _ h2: CGFloat) -> CGFloat {
            let diff = abs(h1 - h2)
            return min(diff, 360.0 - diff)
        }

        // 1. Primary Accent Color
        let primaryColor = Color(primaryCand.color)

        // 2. Secondary Accent Color (Look for distinct hue separation >= 26 degrees)
        var secondaryCand = candidates.dropFirst().first { cand in
            hueDistance(cand.hue, primaryCand.hue) >= 26.0
        }

        let secondaryColor: Color
        if let sec = secondaryCand {
            secondaryColor = Color(sec.color)
        } else {
            // For monochromatic artwork, derive an analogous complement by shifting hue and modulating brightness
            let shiftedHue = (primaryCand.hue + 24.0).truncatingRemainder(dividingBy: 360.0) / 360.0
            let companionNS = NSColor(
                hue: shiftedHue,
                saturation: max(0.35, primaryCand.saturation * 0.88),
                brightness: min(0.96, primaryCand.brightness * 1.08),
                alpha: 1.0
            )
            secondaryColor = Color(companionNS)
            secondaryCand = CandidateColor(
                color: companionNS,
                hue: shiftedHue * 360.0,
                saturation: primaryCand.saturation,
                brightness: primaryCand.brightness,
                weight: primaryCand.weight * 0.5
            )
        }

        // 3. Optional Tertiary Accent Color (Only if a third distinct cluster with >= 15% presence exists)
        var tertiaryColor: Color? = nil
        if let sec = secondaryCand {
            let tertiaryCand = candidates.dropFirst().first { cand in
                cand.weight >= primaryCand.weight * 0.15 &&
                hueDistance(cand.hue, primaryCand.hue) >= 25.0 &&
                hueDistance(cand.hue, sec.hue) >= 25.0
            }
            if let tert = tertiaryCand {
                tertiaryColor = Color(tert.color)
            }
        }

        let palette = AccentPalette(
            primary: primaryColor,
            secondary: secondaryColor,
            tertiary: tertiaryColor,
            isDefaultWhite: false,
            id: identifier
        )

        cache.setObject(PaletteCacheEntry(palette), forKey: key)
        return palette
    }

    /// Asynchronous multi-color palette extraction helper.
    public func extractPaletteAsync(from data: Data?, identifier: String) async -> AccentPalette {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .defaultWhite)
                    return
                }
                let palette = self.extractPalette(from: data, identifier: identifier)
                continuation.resume(returning: palette)
            }
        }
    }

    // MARK: - Backward-Compatible Single Color Extraction

    /// Extract or retrieve dominant accent NSColor (backward-compatible).
    public func extractAccentColor(from data: Data?, identifier: String) -> NSColor {
        let palette = extractPalette(from: data, identifier: identifier)
        if palette.isDefaultWhite { return NSColor.white }
        return NSColor(palette.primary)
    }

    /// Extract or retrieve dominant accent NSColor from NSImage (backward-compatible).
    public func extractAccentColor(from image: NSImage?, identifier: String) -> NSColor {
        let palette = extractPalette(from: image, identifier: identifier)
        if palette.isDefaultWhite { return NSColor.white }
        return NSColor(palette.primary)
    }

    /// Asynchronous single-color extraction helper (backward-compatible).
    public func extractAccentColorAsync(from data: Data?, identifier: String) async -> NSColor {
        let palette = await extractPaletteAsync(from: data, identifier: identifier)
        if palette.isDefaultWhite { return NSColor.white }
        return NSColor(palette.primary)
    }
}
