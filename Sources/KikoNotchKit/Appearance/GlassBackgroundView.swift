import SwiftUI
import AppKit

/// Frosted liquid glass backdrop view for Kiko Notch
public struct GlassBackgroundView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var cornerRadius: CGFloat
    public var blurIntensity: Double
    public var backgroundOpacity: Double
    public var borderHex: String
    
    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        cornerRadius: CGFloat = 18.0,
        blurIntensity: Double = 0.8,
        backgroundOpacity: Double = 0.85,
        borderHex: String = "#FFFFFF25"
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
        self.blurIntensity = blurIntensity
        self.backgroundOpacity = backgroundOpacity
        self.borderHex = borderHex
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = CustomVisualEffectView()
        effectView.material = material
        effectView.blendingMode = blendingMode
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        updateLayerProperties(effectView)
        return effectView
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
        updateLayerProperties(nsView)
    }
    
    private func updateLayerProperties(_ view: NSVisualEffectView) {
        guard let layer = view.layer else { return }
        layer.cornerRadius = cornerRadius
        layer.borderWidth = 1.0
        
        let borderColor = ColorPalette.color(fromHex: borderHex)
        layer.borderColor = NSColor(borderColor).cgColor
        
        // Background tint layer for opacity and frost tint
        view.alphaValue = CGFloat(max(0.2, min(1.0, backgroundOpacity)))
    }
}

private final class CustomVisualEffectView: NSVisualEffectView {
    override var allowsVibrancy: Bool {
        return true
    }
}

/// SwiftUI Modifier for Liquid Glass styling
public struct GlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var blurIntensity: Double
    public var backgroundOpacity: Double
    public var borderHex: String
    
    public func body(content: Content) -> some View {
        content
            .background(
                GlassBackgroundView(
                    cornerRadius: cornerRadius,
                    blurIntensity: blurIntensity,
                    backgroundOpacity: backgroundOpacity,
                    borderHex: borderHex
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorPalette.color(fromHex: borderHex), lineWidth: 1)
            )
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 18.0,
        blurIntensity: Double = 0.8,
        backgroundOpacity: Double = 0.85,
        borderHex: String = "#FFFFFF25"
    ) -> some View {
        self.modifier(
            GlassModifier(
                cornerRadius: cornerRadius,
                blurIntensity: blurIntensity,
                backgroundOpacity: backgroundOpacity,
                borderHex: borderHex
            )
        )
    }
}
