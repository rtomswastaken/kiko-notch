import Foundation
import SwiftUI
import AppKit

/// Official Kiko Notch Branding Assets
public enum BrandAssets {
    public static let appName = "Kiko Notch"
    public static let appVersion = "1.0.0"
    public static let appBuild = "2026.10"
    public static let copyrightNotice = "© 2026 Kiko Notch. All rights reserved."
    
    /// Checks if a custom uploaded logo exists at the workspace root, current directory, or resource path;
    /// falls back to the official high-fidelity monochrome geometric notch glyph.
    public static func loadLogoImage() -> NSImage? {
        let possibleRelativePaths = [
            "kiko_logo.png",
            "kiko_logo.pdf",
            "logo.png",
            "logo.pdf",
            "assets/logo.png",
            "assets/kiko_logo.png"
        ]
        
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        
        for rel in possibleRelativePaths {
            let fullPath = (currentDir as NSString).appendingPathComponent(rel)
            if fileManager.fileExists(atPath: fullPath), let img = NSImage(contentsOfFile: fullPath) {
                img.isTemplate = true
                return img
            }
            if fileManager.fileExists(atPath: rel), let img = NSImage(contentsOfFile: rel) {
                img.isTemplate = true
                return img
            }
        }
        
        if let resPath = Bundle.main.resourcePath {
            for rel in possibleRelativePaths {
                let fullPath = (resPath as NSString).appendingPathComponent(rel)
                if fileManager.fileExists(atPath: fullPath), let img = NSImage(contentsOfFile: fullPath) {
                    img.isTemplate = true
                    return img
                }
            }
        }
        
        return nil
    }
    
    public static func logoImage(pointSize: CGFloat = 20) -> Image {
        if let nsImage = loadLogoImage() {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "circle.circle.fill")
    }
    
    /// Monochrome Logo View preserving exact proportions
    public struct MonochromeLogoView: View {
        public var size: CGFloat
        public var color: Color
        
        public init(size: CGFloat = 20, color: Color = .primary) {
            self.size = size
            self.color = color
        }
        
        public var body: some View {
            if let logo = BrandAssets.loadLogoImage() {
                Image(nsImage: logo)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(color)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .accessibilityLabel("Kiko Notch Official Monochrome Logo")
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.28)
                        .fill(color)
                        .frame(width: size * 1.5, height: size * 0.75)
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: size * 0.35, height: size * 0.35)
                        .offset(x: -size * 0.3)
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: size * 0.22, height: size * 0.22)
                        .offset(x: size * 0.3)
                }
                .aspectRatio(1.5 / 0.75, contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityLabel("Kiko Notch Official Monochrome Logo")
            }
        }
    }
}
