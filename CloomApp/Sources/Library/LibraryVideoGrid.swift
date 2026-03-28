import SwiftUI
import SwiftData
import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "LibraryVideoGrid")

// MARK: - Video Grid Item & Context Menu

extension LibraryContentView {

    @ViewBuilder
    func videoGridItem(_ video: VideoRecord) -> some View {
        Button {
            if isSelecting {
                toggleSelection(video.id)
            } else {
                navigationState.openEditor(videoID: video.id)
            }
        } label: {
            VideoCardView(video: video)
                .overlay(alignment: .topLeading) {
                    if isSelecting {
                        selectionBadge(isSelected: selectedIDs.contains(video.id))
                            .padding(12)
                    }
                }
                .overlay {
                    if isSelecting && selectedIDs.contains(video.id) {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .draggable(video.id)
        .contextMenu { videoContextMenu(video) }
    }

    @ViewBuilder
    func selectionBadge(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.selectionBadge)
                .frame(width: 24, height: 24)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
    }

    @ViewBuilder
    func videoContextMenu(_ video: VideoRecord) -> some View {
        Button("Open") {
            navigationState.openEditor(videoID: video.id)
        }

        Divider()

        Button("Copy File Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(video.filePath, forType: .string)
        }

        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(video.filePath, inFileViewerRootedAtPath: "")
        }

        Button("Share...") {
            let fileURL = URL(fileURLWithPath: video.filePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let picker = NSSharingServicePicker(items: [fileURL])
            guard let window = NSApp.keyWindow,
                  let contentView = window.contentView else { return }
            let rect = CGRect(x: contentView.bounds.midX - 1, y: contentView.bounds.midY, width: 2, height: 2)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }

        Divider()

        // Move to folder submenu
        Menu("Move to Folder") {
            Button("Remove from Folder") {
                video.folder = nil
                do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
            }
            .disabled(video.folder == nil)

            Divider()

            let flat = flattenedFolders(allFolders.filter { $0.parent == nil })
            ForEach(Array(flat.enumerated()), id: \.offset) { _, item in
                Button {
                    video.folder = item.folder
                    do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
                } label: {
                    HStack {
                        if item.depth > 0 {
                            Text(String(repeating: "  ", count: item.depth))
                        }
                        Image(systemName: "folder")
                        Text(item.folder.name)
                        if video.folder?.id == item.folder.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        // Tags submenu
        Menu("Tags") {
            ForEach(allTags, id: \.id) { tag in
                let isAssigned = video.tags.contains { $0.id == tag.id }
                Button {
                    if isAssigned {
                        video.tags.removeAll { $0.id == tag.id }
                    } else {
                        video.tags.append(tag)
                    }
                    do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: tag.color))
                            .frame(width: 8, height: 8)
                        Text(tag.name)
                        if isAssigned {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        driveContextMenuItems(video)

        Divider()

        Button("Delete", role: .destructive) {
            selectedIDs = [video.id]
            showDeleteConfirmation = true
        }
    }

    @ViewBuilder
    func driveContextMenuItems(_ video: VideoRecord) -> some View {
        let uploadManager = DriveUploadManager.shared
        let authService = GoogleAuthService.shared

        if uploadManager.isUploading(video.id) {
            Label("Uploading...", systemImage: "arrow.up.circle")
                .disabled(true)
        } else if let shareUrl = video.shareUrl, UploadStatus(video.uploadStatus) == .uploaded {
            Button("Copy Share Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(shareUrl, forType: .string)
            }
            Button("Open Share Link") {
                if let url = URL(string: shareUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Re-upload to Google Drive") {
                Task {
                    await uploadManager.reuploadVideo(
                        videoRecord: video,
                        modelContext: modelContext
                    )
                }
            }
        } else if authService.isSignedIn {
            Button("Upload to Google Drive") {
                Task {
                    await uploadManager.uploadVideo(
                        videoRecord: video,
                        modelContext: modelContext
                    )
                }
            }
        }
    }

    func flattenedFolders(_ roots: [FolderRecord], depth: Int = 0) -> [(folder: FolderRecord, depth: Int)] {
        var result: [(FolderRecord, Int)] = []
        for folder in roots.sorted(by: { $0.name < $1.name }) {
            result.append((folder, depth))
            result.append(contentsOf: flattenedFolders(folder.children, depth: depth + 1))
        }
        return result
    }
}
