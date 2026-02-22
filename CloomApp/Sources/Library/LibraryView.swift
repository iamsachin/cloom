import SwiftUI
import SwiftData
import AppKit

// MARK: - Sort Order

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case titleAZ = "Title (A-Z)"
    case titleZA = "Title (Z-A)"
    case longestFirst = "Longest First"
    case shortestFirst = "Shortest First"
    case largestFirst = "Largest First"

    var id: String { rawValue }

    func comparator(_ a: VideoRecord, _ b: VideoRecord) -> Bool {
        switch self {
        case .newestFirst: return a.createdAt > b.createdAt
        case .oldestFirst: return a.createdAt < b.createdAt
        case .titleAZ: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case .titleZA: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
        case .longestFirst: return a.durationMs > b.durationMs
        case .shortestFirst: return a.durationMs < b.durationMs
        case .largestFirst: return a.fileSizeBytes > b.fileSizeBytes
        }
    }
}

// MARK: - Transcript Filter

enum TranscriptFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case hasTranscript = "Has Transcript"
    case noTranscript = "No Transcript"

    var id: String { rawValue }
}

// MARK: - Library View

struct LibraryView: View {
    @Query(sort: \VideoRecord.createdAt, order: .reverse) private var videos: [VideoRecord]
    @Query(sort: \FolderRecord.name) private var allFolders: [FolderRecord]
    @Query(sort: \TagRecord.name) private var allTags: [TagRecord]
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    @State private var sidebarSelection: SidebarSelection? = .allVideos
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var searchText: String = ""
    @State private var sortOrder: LibrarySortOrder = .newestFirst
    @State private var transcriptFilter: TranscriptFilter = .all

    // Move to folder
    @State private var showMoveToFolderPicker = false
    @State private var moveTargetVideoIDs: Set<String> = []

    // Bulk tag
    @State private var showBulkTagPicker = false

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView(selection: $sidebarSelection)
        } detail: {
            detailContent
        }
    }

    // MARK: - Filtered & Sorted Videos

    private var filteredVideos: [VideoRecord] {
        var result = videos

        // Filter by sidebar selection
        switch sidebarSelection {
        case .folder(let folderID):
            result = result.filter { $0.folder?.id == folderID }
        case .tag(let tagID):
            result = result.filter { video in
                video.tags.contains { $0.id == tagID }
            }
        case .allVideos, .none:
            break
        }

        // Filter by transcript
        switch transcriptFilter {
        case .all: break
        case .hasTranscript:
            result = result.filter { $0.hasTranscript }
        case .noTranscript:
            result = result.filter { !$0.hasTranscript }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { video in
                video.title.lowercased().contains(query)
                || (video.summary?.lowercased().contains(query) ?? false)
                || (video.transcript?.fullText.lowercased().contains(query) ?? false)
            }
        }

        // Sort
        result.sort(by: sortOrder.comparator)

        return result
    }

    private var navigationTitle: String {
        let count = filteredVideos.count
        switch sidebarSelection {
        case .allVideos, .none:
            return "All Videos (\(count))"
        case .folder(let id):
            if let folder = allFolders.first(where: { $0.id == id }) {
                return "\(folder.name) (\(count))"
            }
            return "Folder (\(count))"
        case .tag(let id):
            if let tag = allTags.first(where: { $0.id == id }) {
                return "\(tag.name) (\(count))"
            }
            return "Tag (\(count))"
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if filteredVideos.isEmpty && searchText.isEmpty && sidebarSelection == .allVideos {
            ContentUnavailableView(
                "No Recordings Yet",
                systemImage: "record.circle",
                description: Text("Start a recording from the menu bar to get started.")
            )
        } else if filteredVideos.isEmpty {
            ContentUnavailableView.search(text: searchText.isEmpty ? "No videos" : searchText)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 250), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(filteredVideos, id: \.id) { video in
                        videoGridItem(video)
                    }
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            .searchable(text: $searchText, prompt: "Search videos...")
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Delete \(selectedIDs.count) recording\(selectedIDs.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the selected recordings and their files from disk.")
            }
            .sheet(isPresented: $showMoveToFolderPicker) {
                FolderPickerSheet(
                    folders: allFolders.filter { $0.parent == nil },
                    onSelect: { folder in
                        moveVideosToFolder(videoIDs: moveTargetVideoIDs, folder: folder)
                    }
                )
            }
            .sheet(isPresented: $showBulkTagPicker) {
                BulkTagSheet(
                    tags: allTags,
                    videoIDs: selectedIDs,
                    videos: videos
                )
            }
        }
    }

    // MARK: - Video Grid Item

    @ViewBuilder
    private func videoGridItem(_ video: VideoRecord) -> some View {
        Button {
            if isSelecting {
                toggleSelection(video.id)
            } else {
                openWindow(value: video.id)
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

    // MARK: - Video Context Menu

    @ViewBuilder
    private func videoContextMenu(_ video: VideoRecord) -> some View {
        Button("Open") {
            openWindow(value: video.id)
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

    // Flatten folder hierarchy for menus
    private func flattenedFolders(_ roots: [FolderRecord], depth: Int = 0) -> [(folder: FolderRecord, depth: Int)] {
        var result: [(FolderRecord, Int)] = []
        for folder in roots.sorted(by: { $0.name < $1.name }) {
            result.append((folder, depth))
            result.append(contentsOf: flattenedFolders(folder.children, depth: depth + 1))
        }
        return result
    }

    // MARK: - Toolbar

    private var storageSummary: String {
        let count = videos.count
        let totalBytes = videos.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(count) video\(count == 1 ? "" : "s") · \(formatter.string(fromByteCount: totalBytes))"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Text(storageSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if isSelecting {
                Button(selectedIDs.count == filteredVideos.count ? "Deselect All" : "Select All") {
                    if selectedIDs.count == filteredVideos.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(filteredVideos.map(\.id))
                    }
                }

                Button("Move to...") {
                    moveTargetVideoIDs = selectedIDs
                    showMoveToFolderPicker = true
                }
                .disabled(selectedIDs.isEmpty)

                Button("Tag...") {
                    showBulkTagPicker = true
                }
                .disabled(selectedIDs.isEmpty)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete (\(selectedIDs.count))", systemImage: "trash")
                }
                .disabled(selectedIDs.isEmpty)

                Button("Done") {
                    isSelecting = false
                    selectedIDs.removeAll()
                }
            } else {
                // Sort picker
                Menu {
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(LibrarySortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }

                // Transcript filter
                Menu {
                    Picker("Filter", selection: $transcriptFilter) {
                        ForEach(TranscriptFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }

                Button {
                    isSelecting = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
            }
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    @ViewBuilder
    private func selectionBadge(isSelected: Bool) -> some View {
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

    // MARK: - Actions

    private func deleteSelected() {
        let idsToDelete = selectedIDs
        for video in videos where idsToDelete.contains(video.id) {
            let filePath = video.filePath
            if !filePath.isEmpty {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            let thumbPath = video.thumbnailPath
            if !thumbPath.isEmpty {
                try? FileManager.default.removeItem(atPath: thumbPath)
            }
            if let webcamPath = video.webcamFilePath, !webcamPath.isEmpty {
                try? FileManager.default.removeItem(atPath: webcamPath)
            }
            modelContext.delete(video)
        }
        try? modelContext.save()
        selectedIDs.removeAll()
        isSelecting = false
    }

    private func moveVideosToFolder(videoIDs: Set<String>, folder: FolderRecord?) {
        for video in videos where videoIDs.contains(video.id) {
            video.folder = folder
        }
        try? modelContext.save()
    }
}

