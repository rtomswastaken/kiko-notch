import SwiftUI

/// The content well shared by every destination in the expanding island.
/// It deliberately uses a square top edge: the enclosing island owns the
/// hardware-notch seam, while destinations only round their lower surface.
public extension View {
    func notchPageViewport() -> some View {
        self
    }
}
