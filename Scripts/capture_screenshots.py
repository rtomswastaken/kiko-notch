#!/usr/bin/env python3
import os
import sys
import time
import subprocess
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
SCREENSHOTS_DIR = os.path.join(PROJECT_ROOT, "Assets", "screenshots")

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

def get_window_id():
    cmd = r"""
    swift -e '
    import Cocoa
    import CoreGraphics

    let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    for w in windowList {
        if let owner = w[kCGWindowOwnerName as String] as? String, owner.contains("Kiko") {
            if let bounds = w[kCGWindowBounds as String] as? [String: Any],
               let width = bounds["Width"] as? CGFloat, width >= 600 {
                print("\(w[kCGWindowNumber as String] ?? -1)")
                exit(0)
            }
        }
    }
    '
    """
    out = subprocess.check_output(["bash", "-c", cmd]).decode().strip()
    return int(out) if out else None

def send_notification(command, **kwargs):
    pairs = [f'"{k}": "{v}"' if isinstance(v, str) else f'"{k}": {v}' for k, v in kwargs.items()]
    pairs.insert(0, f'"command": "{command}"')
    user_info = "[\n        " + ",\n        ".join(pairs) + "\n    ]"
    
    swift_cmd = f"""
    import Cocoa
    let center = DistributedNotificationCenter.default()
    center.postNotificationName(NSNotification.Name("com.kikonotch.action"), object: nil, userInfo: {user_info}, deliverImmediately: true)
    """
    subprocess.check_call(["swift", "-e", swift_cmd])

def capture_window(win_id, dest_path, crop_mode="none"):
    tmp_path = f"/tmp/kiko_raw_{os.path.basename(dest_path)}"
    subprocess.check_call(["screencapture", "-l", str(win_id), "-o", tmp_path])
    
    im = Image.open(tmp_path)
    bbox = im.getbbox()
    
    if crop_mode == "notch" and bbox:
        # Add modest padding around notch cutout
        w, h = im.size
        pad_x = 16
        pad_bottom = 16
        x0 = max(0, bbox[0] - pad_x)
        y0 = 0
        x1 = min(w, bbox[2] + pad_x)
        y1 = min(h, bbox[3] + pad_bottom)
        cropped = im.crop((x0, y0, x1, y1))
        cropped.save(dest_path, "PNG")
    elif crop_mode == "expanded" and bbox:
        # Clean island window
        im.save(dest_path, "PNG")
    else:
        im.save(dest_path, "PNG")
    
    if os.path.exists(tmp_path):
        os.remove(tmp_path)
    print(f"Captured: {dest_path} ({os.path.getsize(dest_path)} bytes)")

def main():
    win_id = get_window_id()
    if not win_id:
        print("Error: Could not locate KikoNotch window.")
        sys.exit(1)
    
    print(f"Targeting KikoNotch window ID: {win_id}")
    
    # 1. Collapsed island
    print("\n--- 1. Collapsed Island ---")
    send_notification("collapse")
    time.sleep(1.2)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "collapsed-island.png"), crop_mode="notch")
    
    # 2. Volume indicator
    print("\n--- 2. Volume Indicator ---")
    send_notification("collapse")
    time.sleep(0.5)
    send_notification("showVolume", level=0.68)
    time.sleep(0.25)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "volume-indicator.png"), crop_mode="notch")
    
    # 3. Brightness indicator
    print("\n--- 3. Brightness Indicator ---")
    send_notification("collapse")
    time.sleep(0.5)
    send_notification("showBrightness", level=0.55)
    time.sleep(0.25)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "brightness-indicator.png"), crop_mode="notch")
    
    # 4. Expanded Home
    print("\n--- 4. Expanded Home ---")
    send_notification("expand")
    time.sleep(0.5)
    send_notification("selectTab", tab="home")
    time.sleep(1.2)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "expanded-home.png"), crop_mode="expanded")
    
    # 5. System Statistics
    print("\n--- 5. System Statistics ---")
    send_notification("selectTab", tab="system")
    time.sleep(1.5)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "system-statistics.png"), crop_mode="expanded")
    
    # 6. File Shelf
    print("\n--- 6. File Shelf ---")
    send_notification("selectTab", tab="file shelf")
    time.sleep(1.2)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "file-shelf.png"), crop_mode="expanded")
    
    # 7. AI Usage
    print("\n--- 7. AI Usage ---")
    send_notification("selectTab", tab="ai usage")
    time.sleep(1.2)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "ai-usage.png"), crop_mode="expanded")
    
    # 8. Now Playing
    print("\n--- 8. Now Playing ---")
    send_notification("selectTab", tab="home")
    send_notification("simulateMedia", title="Starboy", artist="The Weeknd ft. Daft Punk", album="Starboy")
    time.sleep(1.5)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "now-playing.png"), crop_mode="expanded")
    
    # 9. Dynamic Gradient
    print("\n--- 9. Dynamic Gradient ---")
    send_notification("simulateMedia", title="Midnight City", artist="M83", album="Hurry Up, We're Dreaming")
    time.sleep(1.5)
    capture_window(win_id, os.path.join(SCREENSHOTS_DIR, "dynamic-gradient.png"), crop_mode="expanded")
    
    print("\nAll 9 screenshots captured successfully!")

if __name__ == "__main__":
    main()
