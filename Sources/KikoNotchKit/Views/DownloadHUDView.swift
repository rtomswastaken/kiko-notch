import SwiftUI
import AppKit

/// Download progress and completion banner in the Island.
/// Implements DL-003.
public struct DownloadHUDView: View {
    public let download: DownloadItem
    public var onDismiss: (() -> Void)?
    
    public init(download: DownloadItem, onDismiss: (() -> Void)? = nil) {
        self.download = download
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: download.state == .completed ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(download.state == .completed ? .green : .blue)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(download.targetFilename)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if download.state == .active {
                        Text(download.formattedSpeed)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                if download.state == .active {
                    ProgressView(value: download.progress)
                        .progressViewStyle(.linear)
                } else if download.state == .completed {
                    Text("Download Complete")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
            
            if download.state == .completed {
                Button("Show") {
                    let url = URL(fileURLWithPath: download.path)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    onDismiss?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(minWidth: 260)
    }
}
