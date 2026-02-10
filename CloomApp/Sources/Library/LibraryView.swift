import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \VideoRecord.createdAt, order: .reverse) private var videos: [VideoRecord]
    @EnvironmentObject var appState: AppState

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
                            VideoCardView(video: video)
                        }
                    }
                    .padding()
                }
                .navigationTitle("All Videos (\(videos.count))")
            }
        }
    }
}
