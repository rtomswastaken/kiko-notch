# Third-Party Licenses and Attributions

Kiko Notch incorporates foundational components, architectural patterns, and sizing geometries adapted from open-source native macOS software.

---

## 1. Boring Notch Foundation

- **Project**: Boring Notch
- **Authors**: Harsh Vardhan Goswami, Alexander, TheBoredTeam
- **Repository / Source Reference**: `/Users/rtoms/Documents/boring notch`
- **License**: GNU General Public License v3.0 (GPLv3)
- **Copyright**: Copyright © 2024 Harsh Vardhan Goswami, Alexander, TheBoredTeam

### Reused & Adapted Components in Kiko Notch:
1. **Notch Geometry & Sizing**:
   - `DisplayManager.swift`: Physical notch detection utilizing `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea`.
   - Incorporates Boring Notch's proven `+ 4pt` anti-aliasing margin formula (`(rightArea.minX - leftArea.maxX) + 4.0`, centered with `- 2.0pt` X-offset) preventing subpixel light bleeding under MacBook Pro hardware bezels.
   - `IslandGeometry.swift`: Standard corner radius insets (`opened: (top: 19, bottom: 24), closed: (top: 6, bottom: 14)`).
2. **Event-Driven System HUD & Battery Sensors**:
   - Adapted core patterns from Boring Notch's `VolumeManager`, `BrightnessManager`, and `BatteryActivityManager`.
   - Utilizes `CoreAudio` (`AudioObjectAddPropertyListenerBlock`) and `IOKit.ps` (`IOPSNotificationCreateRunLoopSource`) for 0% idle CPU event notifications.
3. **Now Playing Observation**:
   - Adapted media observation architectures from Boring Notch's media controller integrations.
4. **Deliberate Exclusions**:
   - Boring Notch's `WebcamManager` is **strictly excluded**. Kiko Notch does not request camera permissions or include webcam/mirror features.

---

## 2. License Terms (GPLv3)

A complete copy of the GNU General Public License v3.0 is provided in the root `LICENSE` file.
