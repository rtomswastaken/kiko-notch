<div align="center">

<img src="assets/logo.png" alt="Kiko Notch Logo" width="128" height="128" />

# Kiko Notch

**A native macOS notch companion experiment.**

</div>

> [!WARNING]
> ### 🚧 STATUS: IN DEVELOPMENT — PROOF OF CONCEPT
> **Kiko Notch is an experimental native macOS application currently under active development.**
> It explores a Dynamic Island-style companion experience for macOS. The project is a **Proof of Concept (PoC)** and is **NOT production-ready**.
>
> - Features, user interface designs, architecture, and internal APIs may change rapidly.
> - Certain features are incomplete, experimental, or dependent on hardware and platform permissions.
> - **Build success and passing unit tests do not guarantee that every feature functions correctly at runtime** across all macOS versions and hardware configurations.
> - Use at your own risk in personal development environments.

---

## 1. Overview

**Kiko Notch** is an open-source macOS status companion designed to turn the MacBook display notch (or a floating notch-style island on non-notch displays) into a functional, glanceable, and interactive productivity hub. Built natively in **Swift**, **AppKit**, and **SwiftUI**, Kiko Notch aims to deliver a fluid, high-performance experience with zero idle CPU overhead.

### Key Conceptual Pillars
- **Native & Lightweight**: Built directly on AppKit and SwiftUI with zero external non-Apple runtime dependencies.
- **Display Agnostic**: Automatically detects physical display notches (`NSScreen.auxiliaryTopLeftArea`) or simulates a floating island on external monitors and notchless Macs.
- **Zero-Idle Efficiency**: Timer-free resting state. Audio visualizers, sensor polling, and animations halt when the island is collapsed.
- **Privacy First**: All clipboard history, local usage statistics, and credentials stay on your device. Zero telemetry SDKs or analytics trackers.

---

## 2. Current Development Status

Kiko Notch is in active pre-release development (**v0.1.0-alpha / Proof of Concept**).

- **Current State**: Core window architecture, event-handling mechanics, multi-tab navigation model, and Darwin system sampling engines are implemented.
- **Stability**: Alpha quality. While all core unit tests pass (105/105 tests across 16 test suites), unexpected edge cases may occur when interacting with varied external displays, multi-monitor arrangements, or differing macOS permission configurations.
- **Architecture**: Incorporates architectural patterns and open-source foundations inspired by [Boring Notch](https://github.com), adapted for an expandable multi-tab workspace and Darwin system metrics.

---

## 3. Experimental Features

The table below provides an honest assessment of current features across four distinct readiness tiers:

| Feature / Module | Tier | Description & Current State |
|---|---|---|
| **Floating Island Window** | **Implemented** | Non-activating `NSPanel` floating at `.statusBar + 1` level with smooth spring animations and click-outside dismissal. |
| **Physical Notch Detection** | **Implemented** | Screen geometry inspection via `auxiliaryTopLeftArea`; anchors seamlessly beneath the hardware notch. |
| **Simulated Notch (Pill Mode)** | **Implemented** | Floating pill positioned near the top-center on displays without a physical notch. |
| **Multi-Tab Navigation** | **Implemented** | 8 dedicated destinations (Home, File Shelf, AI Usage, Now Playing, Agenda, System, Weather, Settings). |
| **Darwin System Metrics (CPU/RAM/Disk/Net)** | **Implemented** | Real-time sampling via Mach kernel (`host_processor_info`), VM statistics, `sysctl`, `FileManager`, and `getifaddrs`. |
| **Bounded Metric Sparklines** | **Implemented** | 60-sample thread-safe FIFO ring buffer feeding live SVG/SwiftUI charts with zero memory leaks. |
| **GPU Telemetry** | **Implemented** | Metal device inspection (`MTLCreateSystemDefaultDevice`). Truthfully reports execution utilization as unavailable due to Apple Silicon private entitlement restrictions. |
| **Battery & Power Monitoring** | **Implemented** | Event-driven `IOPowerSources` listener tracking battery percentage, charging state, and time remaining. |
| **Per-Event System HUDs** | **Implemented** | Real-time on-island overlays for volume, display brightness, and keyboard backlight adjustments. |
| **File Shelf & Drag-and-Drop** | **Experimental** | `NSDraggingDestination` staging area with QuickLook preview generation and native AirDrop handoff. |
| **Now Playing & Audio Controls** | **Experimental** | AppleScript / DistributedNotification bridge for Apple Music & Spotify. Play/pause, track seeking, album art, and audio visualizer. |
| **Clipboard History** | **Experimental** | Low-overhead `pasteboard.changeCount` monitor with ConcealedType password exclusion. |
| **AI Provider Usage Monitor** | **Experimental** | Local quota/session inspection for Antigravity, with optional API connectors for Codex and Claude via macOS Keychain. |
| **Weather Integration** | **Experimental** | Open-Meteo REST client with offline caching and automatic CoreLocation coordinates. |
| **Calendar & Reminders Agenda** | **Experimental** | EventKit reader displaying upcoming events and task checklists with permission fallback prompts. |
| **Multi-Display Dynamic Re-anchoring** | **Not yet verified** | Code handles `didChangeScreenParametersNotification`, but full multi-monitor layout transitions need broader physical hardware testing. |
| **Bluetooth Peripheral Battery Tracking** | **Not yet verified** | `IOBluetoothDevice` peripheral battery polling requires verification across varied third-party accessory chipsets. |
| **Download Progress Hook** | **Not yet verified** | `FSEventStream` watching `~/Downloads` for browser temporary files (`.crdownload`, `.download`, etc.). |
| **Global Hotkey Daemon** | **Planned** | Configurable system-wide shortcuts for island toggling and quick actions. |
| **Custom Plugin / Extension Ecosystem** | **Planned** | Sandboxed third-party widget extensions via the `KikoModule` protocol. |

> [!NOTE]
> **Camera / Mirror features are deliberately excluded.** Kiko Notch will never access or activate the FaceTime HD camera.

---

## 4. Screenshots and Demo

Real interface screenshots and animated demonstrations will be published here as the visual styling, window animations, and tab layouts reach stable production polish.

*Official Monochrome Logo Asset:*
<p align="left">
  <img src="assets/logo.png" alt="Kiko Notch Logo" width="80" />
</p>

---

## 5. Requirements

- **Operating System**: macOS 13.0 (Ventura) or later (macOS 14 Sonoma and macOS 15 Sequoia recommended).
- **Architecture**: Apple Silicon (M1/M2/M3/M4) native, Intel (x86_64) supported.
- **Development Toolchain**:
  - Swift 5.9+ / Swift 6.0 compiler
  - Xcode 15.0+ or macOS Command Line Tools 27.0+

---

## 6. Building and Running

You can compile and run Kiko Notch directly from terminal using the Swift Package Manager.

### Clone the Repository
```bash
git clone https://github.com/rtomswastaken/kiko-notch.git
cd kiko-notch
```

### Build for Release
To build the optimized release binary:
```bash
swift build -c release --product KikoNotch
```

### Run the Application
```bash
swift run -c release KikoNotch
```

### Run Test Suite
To verify the automated test suites:
```bash
swift run KikoNotchTests
```
*(All 16 test suites, totaling 105 tests, run in < 0.5s)*

---

## 7. Known Limitations

As an active Proof of Concept, Kiko Notch has the following known constraints:

1. **Automation Permissions**: Media controls for Spotify and Apple Music rely on AppleScript. macOS will prompt you once to grant automation permissions under *System Settings > Privacy & Security > Automation*.
2. **GPU Metric Restrictions**: On Apple Silicon, system-wide instantaneous GPU execution load is governed by private IOKit / Apple Silicon entitlements. Kiko Notch displays GPU device details and memory truthfully, while marking real-time core utilization as unavailable rather than fabricating fake numbers.
3. **macOS Notification Sandboxing**: macOS strictly isolates third-party application notifications. Kiko Notch presents internal system HUDs and alerts, but does not intercept arbitrary third-party banners without insecure private APIs.
4. **Display Geometry Variations**: Apple has produced multiple notch dimensions across the 14" MacBook Pro, 16" MacBook Pro, and 13"/15" MacBook Air lineups. Island padding and offset fine-tuning can be adjusted in *Settings > Displays*.

---

## 8. Roadmap

- [ ] Complete UI polish and responsive layout transitions for all MacBook screen sizes.
- [ ] Refine audio visualizer frequency smoothing with low-power Accelerate/vDSP transforms.
- [ ] Add pre-built `.dmg` and `.zip` distribution packages via GitHub Releases.
- [ ] Code signing and notarization automation for gatekeeper-friendly installation.
- [ ] Expand Calendar & Reminders interactive actions (mark complete, join meeting link).
- [ ] Finalize custom theme editor with live preview and JSON theme sharing.

---

## 9. Contributing

Contributions, feedback, and bug reports are warmly welcome! Because Kiko Notch is an active experiment:

1. **Check existing issues** before submitting new bug reports or feature requests.
2. **Open a Discussion or Issue** for major architectural proposals before writing large pull requests.
3. Ensure all automated tests compile and pass cleanly (`swift run KikoNotchTests`) before submitting a PR.
4. Please follow the codebase style: standard Swift formatting, descriptive commit messages, and zero unnecessary dependencies.

---

## 10. License

Kiko Notch is licensed under the **GNU General Public License v3.0** (GPLv3).  
See the [LICENSE](LICENSE) file for full details.

Portions of window layout and notch detection logic are derived from or inspired by open-source macOS island experiments, including [Boring Notch](https://github.com). All respective copyrights and licenses are acknowledged and preserved.
