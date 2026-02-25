import SwiftUI
import SwiftData
import AppKit

// MARK: - Library View

struct LibraryView: View {
    @Query(sort: \VideoRecord.createdAt, order: .reverse) var videos: [VideoRecord]
    @Query(sort: \FolderRecord.name) var allFolders: [FolderRecord]
    @Query(sort: \TagRecord.name) var allTags: [TagRecord]
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow
    @Environment(\.modelContext) var modelContext

    @State var sidebarSelection: SidebarSelection? = .allVideos
    @State var isSelecting = false
    @State var selectedIDs: Set<String> = []
    @State var showDeleteConfirmation = false
    @State var searchText: String = ""
    @State var sortOrder: LibrarySortOrder = .newestFirst
    @State var transcriptFilter: TranscriptFilter = .all

    // Move to folder
    @State var showMoveToFolderPicker = false
    @State var moveTargetVideoIDs: Set<String> = []

    // Bulk tag
    @State var showBulkTagPicker = false

    // Cached storage summary
    @State private var cachedStorageSummary = ""

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView(selection: $sidebarSelection)
        } detail: {
            detailContent
        }
    }

    // MARK: - Filtered & Sorted Videos

    var filteredVideos: [VideoRecord] {
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
            .onAppear { updateStorageSummary() }
            .onChange(of: videos.count) { updateStorageSummary() }
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

    // MARK: - Toolbar

    private func updateStorageSummary() {
        let count = videos.count
        let totalBytes = videos.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cachedStorageSummary = "\(count) video\(count == 1 ? "" : "s") · \(formatter.string(fromByteCount: totalBytes))"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Text(cachedStorageSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if isSelecting {
            ToolbarItemGroup(placement: .primaryAction) {
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
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(LibrarySortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .menuIndicator(.hidden)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Filter", selection: $transcriptFilter) {
                        ForEach(TranscriptFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .menuIndicator(.hidden)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSelecting = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
            }
        }
    }

    // MARK: - Actions

    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

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
