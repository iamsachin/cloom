import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "LibrarySidebar")

enum SidebarSelection: Hashable {
    case allVideos
    case folder(String)  // FolderRecord.id
    case tag(String)     // TagRecord.id
}

struct LibrarySidebarView: View {
    @Query private var allVideos: [VideoRecord]
    @Query(sort: \FolderRecord.name) private var allFolders: [FolderRecord]
    @Query(sort: \TagRecord.name) private var allTags: [TagRecord]
    @Binding var selection: SidebarSelection?
    @Environment(\.modelContext) private var modelContext

    @State private var renamingFolderID: String?
    @State private var renamingFolderName: String = ""
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var newFolderParentID: String?
    @State private var showDeleteFolderConfirmation = false
    @State private var folderToDelete: FolderRecord?

    // Tags
    @State private var showNewTagSheet = false
    @State private var renamingTagID: String?
    @State private var renamingTagName: String = ""
    @State private var showDeleteTagConfirmation = false
    @State private var tagToDelete: TagRecord?

    private var rootFolders: [FolderRecord] {
        allFolders.filter { $0.parent == nil }
    }

    private var storageSummary: String {
        let count = allVideos.count
        let totalBytes = allVideos.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(count) video\(count == 1 ? "" : "s") · \(formatter.string(fromByteCount: totalBytes))"
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                // All Videos
                Label("All Videos", systemImage: "film.stack")
                    .tag(SidebarSelection.allVideos)

                // Folders section
            Section {
                ForEach(flatFolders) { item in
                    folderLabel(item.folder)
                        .padding(.leading, CGFloat(item.depth) * 16)
                        .tag(SidebarSelection.folder(item.folder.id))
                        .contextMenu { folderContextMenu(item.folder) }
                }
            } header: {
                HStack {
                    Text("Folders")
                    Spacer()
                    Button {
                        newFolderParentID = nil
                        newFolderName = ""
                        showNewFolderAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 4)
            }

            // Tags section
            Section {
                ForEach(allTags, id: \.id) { tag in
                    tagRow(tag)
                }
            } header: {
                HStack {
                    Text("Tags")
                    Spacer()
                    Button {
                        showNewTagSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 4)
            }
            }

            Divider()

            HStack(spacing: 4) {
                Image(systemName: "internaldrive")
                    .font(.caption2)
                Text(storageSummary)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Library")
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete folder \"\(folderToDelete?.name ?? "")\"?",
            isPresented: $showDeleteFolderConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDeleteFolder() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Videos in this folder will be moved out, not deleted.")
        }
        .confirmationDialog(
            "Delete tag \"\(tagToDelete?.name ?? "")\"?",
            isPresented: $showDeleteTagConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDeleteTag() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The tag will be removed from all videos.")
        }
        .sheet(isPresented: $showNewTagSheet) {
            TagEditorView(mode: .create)
        }
    }

    // MARK: - Folder Row (flattened to avoid recursive some View)

    private struct FolderItem: Identifiable {
        let folder: FolderRecord
        let depth: Int
        var id: String { folder.id }
    }

    private var flatFolders: [FolderItem] {
        var result: [FolderItem] = []
        func flatten(_ folders: [FolderRecord], depth: Int) {
            for folder in folders.sorted(by: { $0.name < $1.name }) {
                result.append(FolderItem(folder: folder, depth: depth))
                flatten(folder.children, depth: depth + 1)
            }
        }
        flatten(rootFolders, depth: 0)
        return result
    }

    @ViewBuilder
    private func folderLabel(_ folder: FolderRecord) -> some View {
        if renamingFolderID == folder.id {
            TextField("Name", text: $renamingFolderName, onCommit: {
                folder.name = renamingFolderName
                do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
                renamingFolderID = nil
            })
            .textFieldStyle(.plain)
        } else {
            HStack {
                Label(folder.name, systemImage: "folder")
                Spacer()
                if folder.videoCount > 0 {
                    Text("\(folder.videoCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: FolderRecord) -> some View {
        Button("Rename") {
            renamingFolderID = folder.id
            renamingFolderName = folder.name
        }
        Button("New Subfolder") {
            newFolderParentID = folder.id
            newFolderName = ""
            showNewFolderAlert = true
        }
        Divider()
        Button("Delete", role: .destructive) {
            folderToDelete = folder
            showDeleteFolderConfirmation = true
        }
    }

    // MARK: - Tag Row

    @ViewBuilder
    private func tagRow(_ tag: TagRecord) -> some View {
        if renamingTagID == tag.id {
            TextField("Name", text: $renamingTagName, onCommit: {
                tag.name = renamingTagName
                do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
                renamingTagID = nil
            })
            .textFieldStyle(.plain)
            .tag(SidebarSelection.tag(tag.id))
        } else {
            HStack {
                Circle()
                    .fill(Color(hex: tag.color))
                    .frame(width: 10, height: 10)
                Text(tag.name)
                Spacer()
                if tag.videos.count > 0 {
                    Text("\(tag.videos.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            .tag(SidebarSelection.tag(tag.id))
            .contextMenu { tagContextMenu(tag) }
        }
    }

    @ViewBuilder
    private func tagContextMenu(_ tag: TagRecord) -> some View {
        Button("Rename") {
            renamingTagID = tag.id
            renamingTagName = tag.name
        }
        Button("Edit Tag...") {
            showNewTagSheet = true // Will need to set editing tag
        }
        Divider()
        Button("Delete", role: .destructive) {
            tagToDelete = tag
            showDeleteTagConfirmation = true
        }
    }

    // MARK: - Actions

    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let folder = FolderRecord(name: newFolderName.trimmingCharacters(in: .whitespaces))
        if let parentID = newFolderParentID,
           let parent = allFolders.first(where: { $0.id == parentID }) {
            folder.parent = parent
        }
        modelContext.insert(folder)
        do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
    }

    private func performDeleteFolder() {
        guard let folder = folderToDelete else { return }
        // Orphan videos
        for video in folder.videos {
            video.folder = nil
        }
        // Orphan children's videos recursively
        orphanVideosRecursively(folder)
        if selection == .folder(folder.id) {
            selection = .allVideos
        }
        modelContext.delete(folder)
        do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
        folderToDelete = nil
    }

    private func orphanVideosRecursively(_ folder: FolderRecord) {
        for video in folder.videos {
            video.folder = nil
        }
        for child in folder.children {
            orphanVideosRecursively(child)
        }
    }

    private func performDeleteTag() {
        guard let tag = tagToDelete else { return }
        // Remove tag from all videos
        for video in tag.videos {
            video.tags.removeAll { $0.id == tag.id }
        }
        if selection == .tag(tag.id) {
            selection = .allVideos
        }
        modelContext.delete(tag)
        do { try modelContext.save() } catch { logger.error("Failed to save: \(error)") }
        tagToDelete = nil
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
