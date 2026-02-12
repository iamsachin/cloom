import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \VideoRecord.createdAt, order: .reverse) private var videos: [VideoRecord]
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationSplitView {
            List {
                Label("All Videos", systemImage: "film.stack")
                Label("Folders", systemImage: "folder")
            }
            .navigationTitle("Library")
        } detail: {
            if videos.isEmpty {
                ContentUnavailableView(
                    "No Recordings Yet",
                    systemImage: "record.circle",
                    description: Text("Start a recording from the menu bar to get started.")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 250), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(videos, id: \.id) { video in
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
                        }
                    }
                    .padding()
                }
                .navigationTitle("All Videos (\(videos.count))")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if isSelecting {
                            Button(selectedIDs.count == videos.count ? "Deselect All" : "Select All") {
                                if selectedIDs.count == videos.count {
                                    selectedIDs.removeAll()
                                } else {
                                    selectedIDs = Set(videos.map(\.id))
                                }
                            }

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
                            Button {
                                isSelecting = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        }
                    }
                }
                .confirmationDialog(
                    "Delete \(selectedIDs.count) recording\(selectedIDs.count == 1 ? "" : "s")?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        deleteSelected()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete the selected recordings and their files from disk.")
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
                .fill(isSelected ? Color.accentColor : Color.black.opacity(0.4))
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

    // MARK: - Delete

    private func deleteSelected() {
        let idsToDelete = selectedIDs
        for video in videos where idsToDelete.contains(video.id) {
            // Delete files from disk
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
}
