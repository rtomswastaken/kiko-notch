#!/bin/bash
set -euo pipefail

# Kiko Notch .app Bundle Packager
# Packages the compiled Swift Package Manager binary into a native macOS .app bundle.

CONFIG="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$CONFIG" = "debug" ]; then
    if [ -f "$ROOT_DIR/.build/debug/KikoNotch" ]; then
        BIN_DIR="$ROOT_DIR/.build/debug"
    else
        BIN_DIR="$ROOT_DIR/.build/out/Products/Debug"
    fi
else
    if [ -f "$ROOT_DIR/.build/release/KikoNotch" ]; then
        BIN_DIR="$ROOT_DIR/.build/release"
    else
        BIN_DIR="$ROOT_DIR/.build/out/Products/Release"
    fi
fi

echo "==> Building KikoNotch in ${CONFIG} mode..."
swift build -c "${CONFIG}" --product KikoNotch

APP_BUNDLE="$ROOT_DIR/.build/KikoNotch.app"
RELEASE_APP_BUNDLE="$BIN_DIR/KikoNotch.app"

for BUNDLE in "$APP_BUNDLE" "$RELEASE_APP_BUNDLE"; do
    echo "==> Packaging into ${BUNDLE}..."
    rm -rf "$BUNDLE"
    mkdir -p "$BUNDLE/Contents/MacOS"
    mkdir -p "$BUNDLE/Contents/Resources"
    
    # Copy compiled executable
    cp "$BIN_DIR/KikoNotch" "$BUNDLE/Contents/MacOS/KikoNotch"
    chmod +x "$BUNDLE/Contents/MacOS/KikoNotch"
    
    # Copy logo asset if available
    if [ -f "$ROOT_DIR/assets/logo.png" ]; then
        cp "$ROOT_DIR/assets/logo.png" "$BUNDLE/Contents/Resources/AppIcon.png"
    fi
    if [ -d "$ROOT_DIR/assets" ]; then
        cp -R "$ROOT_DIR/assets" "$BUNDLE/Contents/Resources/"
    fi
    if [ -f "$ROOT_DIR/assets/kiko_logo_clean.png" ]; then
        cp "$ROOT_DIR/assets/kiko_logo_clean.png" "$BUNDLE/Contents/Resources/"
    fi
    
    # Generate Info.plist
    cat <<EOF > "$BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>KikoNotch</string>
    <key>CFBundleIdentifier</key>
    <string>com.kikonotch.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Kiko Notch</string>
    <key>CFBundleDisplayName</key>
    <string>Kiko Notch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Kiko Notch uses your calendar to display upcoming events and schedule details in the Notch.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Kiko Notch uses your calendar to display upcoming events and schedule details in the Notch.</string>
    <key>NSRemindersUsageDescription</key>
    <string>Kiko Notch displays your upcoming reminders in the Notch.</string>
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>Kiko Notch displays your upcoming reminders in the Notch.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Kiko Notch coordinates media playback with Apple Music and Spotify.</string>
</dict>
</plist>
EOF
done

echo "✅ Kiko Notch .app bundle created successfully at:"
echo "   $APP_BUNDLE"
echo "   $RELEASE_APP_BUNDLE"
