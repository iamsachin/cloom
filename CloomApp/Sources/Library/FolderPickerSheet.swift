import SwiftUI
import SwiftData

struct FolderPickerSheet: View {
    let folders: [FolderRecord]
    let onSelect: (FolderRecord?) -> Void
    @Environment(\.dismiss) private var dismiss

    private var flatFolders: [(folder: FolderRecord, depth: Int)] {
        var result: [(FolderRecord, Int)] = []
        func flatten(_ items: [FolderRecord], depth: Int) {
            for f in items.sorted(by: { $0.name < $1.name }) {
                result.append((f, depth))
                flatten(f.children, depth: depth + 1)
            }
        }
        flatten(folders, depth: 0)
        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Move to Folder")
                .font(.headline)

            List {
                Button("Remove from Folder") {
                    onSelect(nil)
                    dismiss()
                }

                ForEach(Array(flatFolders.enumerated()), id: \.offset) { _, item in
                    Button {
                        onSelect(item.folder)
                        dismiss()
                    } label: {
                        Label(item.folder.name, systemImage: "folder")
                    }
                    .padding(.leading, CGFloat(item.depth) * 16)
                }
            }
            .frame(width: 280, height: 300)

            Button("Cancel") { dismiss() }
        }
        .padding()
    }
}
