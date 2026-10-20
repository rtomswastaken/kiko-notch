//
//  HomeTabView.swift
//  KikoNotchKit
//
//  Clean two-column dashboard composition for the expanded island Home page:
//  - Left Column: Now Playing (top) and System Monitor (bottom).
//  - Right Column: Compact Monthly Calendar + Synchronized Events List (full height).
//

import SwiftUI
import AppKit

public struct HomeTabView: View {
    @ObservedObject public var themeManager = ThemeManager.shared

    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Column: Now Playing & System Monitor
            VStack(spacing: IslandSpacing.sectionSpacing) {
                HomeNowPlayingWidget()
                HomeSystemMonitorWidget()
            }
            .frame(maxWidth: .infinity)

            // Right Column: Calendar & Events (Full Height)
            HomeCalendarWidget()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
