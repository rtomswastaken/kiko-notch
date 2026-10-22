# Kiko Notch Distribution

This folder provides release and installation guidance for Kiko Notch.

## Downloadable Release Artifacts

Official pre-built binary releases are distributed as compressed macOS application bundles attached to GitHub Releases:

- **Release Asset**: `Kiko-Notch-v1.0.0-macOS.zip`
- **Contained Bundle**: `Kiko Notch.app`
- **Target OS**: macOS 13.0 (Ventura) or later
- **Architecture**: Universal / Apple Silicon native (arm64) & Intel (x86_64)

Download the latest release from the [GitHub Releases page](https://github.com/rtomswastaken/kiko-notch/releases/latest).

## Installation

1. Download `Kiko-Notch-v1.0.0-macOS.zip` from GitHub Releases.
2. Uncompress the archive:
   ```bash
   unzip Kiko-Notch-v1.0.0-macOS.zip
   ```
3. Move `Kiko Notch.app` to your `/Applications` directory:
   ```bash
   mv "Kiko Notch.app" /Applications/
   ```
4. Launch Kiko Notch from `/Applications` or via Spotlight.

## First Launch & macOS Gatekeeper

Kiko Notch is an open-source application built directly from source. If macOS Gatekeeper presents a prompt stating the app cannot be opened because the developer cannot be verified:

1. Right-click (or Control-click) `Kiko Notch.app` in Finder.
2. Select **Open** from the context menu.
3. Click **Open** in the confirmation dialog.

Alternatively, you can clear the quarantine attribute via Terminal:
```bash
xattr -cr "/Applications/Kiko Notch.app"
```

## Verifying Checksums

Each release includes an official SHA-256 checksum in the release notes. To verify your downloaded archive:

```bash
shasum -a 256 Kiko-Notch-v1.0.0-macOS.zip
```

Compare the output hash against the hash listed in the corresponding release notes.

## Building from Source

You can also compile Kiko Notch directly on your Mac:

```bash
git clone https://github.com/rtomswastaken/kiko-notch.git
cd kiko-notch
./Scripts/package_app.sh release
open .build/release/KikoNotch.app
```
