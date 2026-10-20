import SwiftUI

/// About tab with monochrome branding, version info, and privacy summary
public struct AboutSettingsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Official Monochrome Logo
            BrandAssets.MonochromeLogoView(size: 48, color: .primary)
                .padding(.top, 16)

            VStack(spacing: 4) {
                Text(BrandAssets.appName)
                    .font(.system(size: 20, weight: .bold))

                Text("Version \(BrandAssets.appVersion) (\(BrandAssets.appBuild))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text("Open Source Foundation & Licensing")
                    .font(.system(size: 13, weight: .semibold))

                Text("Kiko Notch is built on the open-source Boring Notch foundation under the GNU General Public License v3.0 (GPLv3). Special thanks and attribution to The Bored Team (https://github.com/TheBoredTeam/boring.notch).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                Text("Privacy & Security Architecture")
                    .font(.system(size: 13, weight: .semibold))

                Text("Kiko Notch runs entirely locally on your Mac. No telemetry, no background tracking, and no external analytics. Audio visualizer operates with minimal CPU overhead without microphone recording.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Text(BrandAssets.copyrightNotice)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
