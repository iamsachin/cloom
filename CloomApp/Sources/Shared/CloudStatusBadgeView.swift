import SwiftUI

/// Displays cloud upload status (uploading spinner, shared link, or error icon).
struct CloudStatusBadgeView: View {
    let videoId: String
    let uploadStatus: String
    let iconFontSize: CGFloat

    init(videoId: String, uploadStatus: String, iconFontSize: CGFloat = 9) {
        self.videoId = videoId
        self.uploadStatus = uploadStatus
        self.iconFontSize = iconFontSize
    }

    var body: some View {
        let status = UploadStatus(uploadStatus)
        if DriveUploadManager.shared.isUploading(videoId) {
            ProgressView()
                .controlSize(.mini)
        } else if status == .uploaded {
            Image(systemName: "link.circle.fill")
                .font(.system(size: iconFontSize))
                .foregroundStyle(.green)
                .help("Shared on Google Drive")
        } else if status == .failed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: iconFontSize))
                .foregroundStyle(.red)
                .help("Upload failed")
        }
    }
}
