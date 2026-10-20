//
//  IslandContainerView.swift
//  KikoNotchKit
//
//  Root container view for Kiko Notch Island anchored directly to the MacBook notch
//  using Boring Notch window geometry and animations.
//

import SwiftUI
import AppKit

public struct IslandContainerView: View {
    @ObservedObject public var interactionManager = InteractionManager.shared
    @ObservedObject public var displayManager = DisplayManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var mediaController = MediaController.shared

    @State private var isHovering = false
    @State private var hoverTask: Task<Void, Never>?

    public init() {}

    private var isExpanded: Bool {
        interactionManager.currentState == .expanded || interactionManager.currentState == .pinned
    }

    private var currentTopRadius: CGFloat {
        isExpanded ? IslandGeometry.cornerRadiusOpened.top : IslandGeometry.cornerRadiusClosed.top
    }

    private var currentBottomRadius: CGFloat {
        isExpanded ? IslandGeometry.cornerRadiusOpened.bottom : IslandGeometry.cornerRadiusClosed.bottom
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: currentTopRadius,
            bottomCornerRadius: currentBottomRadius
        )
    }

    private var currentSize: CGSize {
        if isExpanded {
            return IslandGeometry.openNotchSize
        } else {
            return IslandGeometry.getClosedNotchSize(
                for: displayManager.targetScreen,
                isPlayingMedia: mediaController.currentMedia.isPlaying,
                isShowingTitleBanner: mediaController.isShowingTitleBanner
            )
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Notch Body with continuous curves
                ZStack {
                    if isExpanded {
                        IslandExpandedView()
                            .transition(.opacity)
                    } else {
                        IslandCollapsedView()
                            .transition(.opacity)
                    }
                }
                .frame(width: currentSize.width, height: currentSize.height, alignment: .top)
                .background(Color.black)
                .clipShape(currentNotchShape)
                .overlay(alignment: .top) {
                    // Sub-pixel top sealing strip against physical notch
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                        .padding(.horizontal, currentTopRadius)
                }
                .shadow(
                    color: isExpanded ? Color.black.opacity(0.7) : (isHovering ? Color.black.opacity(0.4) : Color.clear),
                    radius: isExpanded ? 12 : 4,
                    x: 0,
                    y: isExpanded ? 6 : 2
                )
                .contentShape(currentNotchShape)
                .onHover { hovering in
                    handleHover(hovering)
                }
                .onTapGesture {
                    interactionManager.toggleExpandCollapse()
                }
            }
        }
        .frame(width: IslandGeometry.windowSize.width, height: IslandGeometry.windowSize.height, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.8, blendDuration: 0), value: isExpanded)
        .animation(.spring(response: 0.38, dampingFraction: 0.8, blendDuration: 0), value: mediaController.currentMedia.isPlaying)
        .animation(.spring(response: 0.38, dampingFraction: 0.8, blendDuration: 0), value: mediaController.isShowingTitleBanner)
        .preferredColorScheme(.dark)
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        if hovering {
            isHovering = true
            guard interactionManager.currentState == .collapsed else { return }
            guard SettingsManager.shared.openOnHover else { return }

            hoverTask = Task {
                let delay = UInt64(max(0.1, SettingsManager.shared.hoverDelay) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if self.isHovering && self.interactionManager.currentState == .collapsed {
                        self.interactionManager.expand()
                    }
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000) // 120ms debounce
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isHovering = false
                    if self.interactionManager.currentState == .expanded && !self.interactionManager.isPinned {
                        self.interactionManager.collapse()
                    }
                }
            }
        }
    }
}
