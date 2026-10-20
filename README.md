# Kiko Notch

A native macOS notch companion and expandable dynamic island application built with Swift, AppKit, and SwiftUI.

## Overview

Kiko Notch transforms the MacBook camera notch—or floating pill on displays without a notch—into an interactive island interface. It provides glanceable system telemetry, media playback controls with dynamic gradient accents derived from artwork, an active file shelf, AI usage dashboards, and on-island system HUDs, all running with zero idle sensor overhead.

## Features

### Dynamic Multi-Color Gradient Accents
- Extracts coordinated two- or three-color palettes from active album artwork or video thumbnails using a local 12-hue-bin quantization engine.
- Dynamically tints the collapsed mini-player border, real-time 3-bar audio visualizer, playback controls, navigation pill indicators, and hardware telemetry graphs.
- Smooth 0.85-second cubic ease transitions between tracks with normalized stop counts to eliminate visual flicker.
- Retains artwork palette during paused playback, and smoothly reverts to a clean monochrome white theme when playback stops.

### Universal Media Playback & Visualizer
- Detects media metadata and playback states across Apple Music, Spotify, YouTube in web browsers, and system audio sessions.
- Real-time 3-bar audio spectrum visualizer (Bass, Mid, Treble) rendered using dynamic gradient color stops.
- Interactive playback controls for play/pause, track skipping, and scrubbing progress bars.

### System Activity & Hardware Telemetry
- Real-time CPU utilization sampled via Mach kernel APIs (`host_processor_info`) with a 60-sample historical sparkline.
- Memory breakdown (active, wired, compressed, free) and memory pressure levels via Mach VM statistics.
- Storage capacity, used space, and free volume tracking via `FileManager`.
- Network download and upload throughput measured via `getifaddrs`.
- Power management and battery diagnostics via `IOPowerSources` (charging state, wattage draw, condition, time remaining).
- Thermal state monitoring and fan cooling speeds via SMC and IOKit.
- GPU device identification and memory details via Metal.

### File Shelf
- Drag-and-drop staging zone for temporary file management and quick transfers.
- Integrated QuickLook preview generation.
- Native AirDrop sharing and file sender service.

### AI Usage & Developer Dashboard
- Quota tracking and session metrics for Antigravity, Claude, and Codex with secure Keychain credential storage.
- Developer activity integration via WakaTime API for daily and weekly coding time summaries.

### System HUD Overlays
- Non-intrusive on-island HUD indicators for volume, display brightness, and keyboard backlight adjustments.

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Swift 5.9+ / Xcode 15.0+ or macOS Command Line Tools 27.0+

## Building and Packaging

### Build with Swift Package Manager
```bash
swift build -c release
```

### Build and Package `.app` Bundle
The repository includes a packaging script that builds the binary, creates the bundle structure, and applies local entitlements:
```bash
./Scripts/package_app.sh release
```
The compiled bundle will be available at `.build/release/KikoNotch.app`.

### Launch the Application
```bash
open .build/release/KikoNotch.app
```

## Running Tests

Run the full automated test suite using SPM:
```bash
swift run KikoNotchTests
```
The test suite includes 19 test suites and 177 unit tests covering media detection, palette extraction, system metrics sampling, file shelf interactions, and navigation.

## Architecture

The project is structured into three main modules:

- `Sources/KikoNotchKit`: Core business logic, hardware telemetry services, media controller, accent theme manager, and SwiftUI views.
- `Sources/KikoNotchApp`: Application delegate, window controller management, status bar items, and AppKit entry point.
- `Tests/KikoNotchTests`: Comprehensive test suites for unit testing, mocks, and lifecycle verification.

```
Sources/KikoNotchKit/
├── AI/                 # AI provider connectors, quota models, and WakaTime integration
├── Appearance/         # AccentThemeManager, DesignTokens, NotchShape, and themes
├── Core/               # AppLifecycle, IslandWindowController, Volume/Brightness managers
├── FileShelf/          # FileShelfManager, Drag-and-drop destination, and AirDrop handoff
├── Media/              # MediaController, ArtworkColorExtractor, and AudioSignalMonitor
├── Navigation/         # IslandNavigation coordinator and tab definitions
├── Sensors/            # BatteryMonitor and hardware listeners
├── Settings/           # Settings views, HUD settings, and configuration persistence
├── SystemHUD/          # SystemHUDManager for volume/brightness/backlight overlays
├── SystemMetrics/      # Mach kernel telemetry service, SMC, and metric providers
└── Views/              # SwiftUI views for collapsed, expanded, and tabbed island layouts
```

## Known Limitations

- **Apple Silicon GPU Utilization**: macOS restricts real-time per-core GPU execution load behind private Apple Silicon entitlements. Kiko Notch displays GPU device specifications and unified memory attributes, but marks instantaneous GPU core load as unavailable rather than estimating false values.
- **Automation Permissions**: Media controls for Spotify and Apple Music require AppleScript permissions under System Settings > Privacy & Security > Automation.
- **Microphone / Screen Recording Permissions**: Audio spectrum analysis requires appropriate system audio permissions when monitoring system audio streams.

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
