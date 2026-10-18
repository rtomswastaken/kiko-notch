import Foundation
import SwiftUI
import AppKit

/// Official Kiko Notch Branding Assets
public enum BrandAssets {
    public static let appName = "Kiko Notch"
    public static let appVersion = "1.0.0"
    public static let appBuild = "2026.10"
    public static let copyrightNotice = "© 2026 Kiko Notch. All rights reserved."
    
    /// Checks if a custom uploaded logo exists at the workspace root or resource path;
    /// falls back to the official high-fidelity monochrome geometric notch glyph.
    public static func logoImage(pointSize: CGFloat = 20) -> Image {
        let possiblePaths = [
            "kiko_logo.png",
            "kiko_logo.pdf",
            "logo.png",
            "logo.pdf",
            "assets/logo.png"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path),
               let nsImage = NSImage(contentsOfFile: path) {
                // Ensure monochrome rendering mode
                nsImage.isTemplate = true
                return Image(nsImage: nsImage)
            }
        }
        
        // High fidelity monochrome Kiko Notch placeholder glyph:
        // A sleek, symmetrical dynamic notch silhouette with central sensor cut
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
            ZStack {
                // Rounded notch capsule outline
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(color)
                    .frame(width: size * 1.5, height: size * 0.75)
                
                // Sensor core cutout
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: size * 0.35, height: size * 0.35)
                    .offset(x: -size * 0.3)
                
                // Camera aperture
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: size * 0.22, height: size * 0.22)
                    .offset(x: size * 0.3)
            }
            .aspectRatio(1.5 / 0.75, contentMode: .fit)
            .accessibilityLabel("Kiko Notch Official Monochrome Logo")
        }
    }
}
