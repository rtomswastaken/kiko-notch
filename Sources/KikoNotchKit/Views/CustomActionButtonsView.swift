import SwiftUI

/// Compact custom quick-action buttons row for expanded island
public struct CustomActionButtonsView: View {
    @Binding public var isPinned: Bool
    public var onOpenSettings: () -> Void
    public var onToggleShelf: () -> Void
    
    public init(
        isPinned: Binding<Bool>,
        onOpenSettings: @escaping () -> Void,
        onToggleShelf: @escaping () -> Void
    ) {
        self._isPinned = isPinned
        self.onOpenSettings = onOpenSettings
        self.onToggleShelf = onToggleShelf
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Pin Button
            ActionButton(
                icon: isPinned ? "pin.fill" : "pin",
                title: isPinned ? "Pinned" : "Pin",
                isActive: isPinned,
                action: { isPinned.toggle() }
            )
            .accessibilityLabel(isPinned ? "Unpin island" : "Pin island expanded")
            
            // File Shelf Quick Toggle
            ActionButton(
                icon: "tray.fill",
                title: "Shelf",
                isActive: false,
                action: onToggleShelf
            )
            .accessibilityLabel("Toggle file shelf")
            
            // Settings Button
            ActionButton(
                icon: "gearshape.fill",
                title: "Settings",
                isActive: false,
                action: onOpenSettings
            )
            .accessibilityLabel("Open Kiko Notch settings")
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
            )
            .foregroundColor(isActive ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
