import SwiftUI
import SwiftData
import AppKit

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

        Divider()

        // Move to folder submenu
        Menu("Move to Folder") {
            Button("Remove from Folder") {
                video.folder = nil
                try? modelContext.save()
            }
            .disabled(video.folder == nil)

            Divider()

            let flat = flattenedFolders(allFolders.filter { $0.parent == nil })
            ForEach(Array(flat.enumerated()), id: \.offset) { _, item in
                Button {
                    video.folder = item.folder
                    try? modelContext.save()
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
                    try? modelContext.save()
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

        Button("Delete", role: .destructive) {
            selectedIDs = [video.id]
            showDeleteConfirmation = true
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
