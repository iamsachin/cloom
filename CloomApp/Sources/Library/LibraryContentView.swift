import SwiftUI
import SwiftData
import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "LibraryContent")

// MARK: - Library Content View

struct LibraryContentView: View {
    @Query(sort: \VideoRecord.createdAt, order: .reverse) var videos: [VideoRecord]
    @Query(sort: \FolderRecord.name) var allFolders: [FolderRecord]
    @Query(sort: \TagRecord.name) var allTags: [TagRecord]
    @Environment(NavigationState.self) var navigationState
    @Environment(\.modelContext) var modelContext

    @Binding var sidebarSelection: SidebarSelection?

    @State var isSelecting = false
    @State var selectedIDs: Set<String> = []
    @State var showDeleteConfirmation = false
    @State var searchText: String = ""
    @State var debouncedSearchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State var sortOrder: LibrarySortOrder = .newestFirst
    @State var transcriptFilter: TranscriptFilter = .all

    // Move to folder
    @State var showMoveToFolderPicker = false
    @State var moveTargetVideoIDs: Set<String> = []

    // Bulk tag
    @State var showBulkTagPicker = false

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
        if !debouncedSearchText.isEmpty {
            let query = debouncedSearchText.lowercased()
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

    var navigationTitle: String {
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

    // MARK: - Body

    var body: some View {
        Group {
            if filteredVideos.isEmpty && debouncedSearchText.isEmpty && sidebarSelection == .allVideos
                && !PostRecordingTracker.shared.isProcessing {
                ContentUnavailableView(
                    "No Recordings Yet",
                    systemImage: "record.circle",
                    description: Text("Start a recording from the menu bar to get started.")
                )
            } else if filteredVideos.isEmpty && !PostRecordingTracker.shared.isProcessing {
                ContentUnavailableView.search(text: debouncedSearchText.isEmpty ? "No videos" : debouncedSearchText)
            } else {
                switch navigationState.viewStyle {
                case .grid:
                    gridContent
                case .list:
                    listContent
                }
            }
        }
        .navigationTitle(navigationTitle)
        .searchable(text: $searchText, prompt: "Search videos...")
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedSearchText = newValue
            }
        }
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

    // MARK: - Grid Content

    @ViewBuilder
    private var gridContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 280), spacing: 20)],
                spacing: 20
            ) {
                if let info = PostRecordingTracker.shared.activeRecording {
                    ProcessingCardView(info: info)
                }
                ForEach(filteredVideos, id: \.id) { video in
                    videoGridItem(video)
                }
            }
            .padding()
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredVideos, id: \.id) { video in
                    LibraryListRowView(
                        video: video,
                        isSelecting: isSelecting,
                        isSelected: selectedIDs.contains(video.id),
                        onTap: {
                            if isSelecting {
                                toggleSelection(video.id)
                            } else {
                                navigationState.openEditor(videoID: video.id)
                            }
                        }
                    )
                    .contextMenu { videoContextMenu(video) }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
                @Bindable var navState = navigationState
                Picker("View", selection: $navState.viewStyle) {
                    Image(systemName: "square.grid.2x2")
                        .tag(NavigationState.ViewStyle.grid)
                    Image(systemName: "list.bullet")
                        .tag(NavigationState.ViewStyle.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
            }

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
        VideoLibraryService.deleteVideos(ids: selectedIDs, from: videos, context: modelContext)
        selectedIDs.removeAll()
        isSelecting = false
    }

    private func moveVideosToFolder(videoIDs: Set<String>, folder: FolderRecord?) {
        VideoLibraryService.moveVideos(ids: videoIDs, toFolder: folder, from: videos, context: modelContext)
    }
}
