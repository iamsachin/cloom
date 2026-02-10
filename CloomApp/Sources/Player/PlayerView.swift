import SwiftUI
import SwiftData
import AVKit

struct PlayerView: View {
    let videoID: String

    @Query private var videos: [VideoRecord]
    @State private var player: AVPlayer?

    init(videoID: String) {
        self.videoID = videoID
        let id = videoID
        _videos = Query(filter: #Predicate<VideoRecord> { $0.id == id })
    }

    private var video: VideoRecord? {
        videos.first
    }

    var body: some View {
        Group {
            if let video {
                videoPlayerView(for: video)
            } else {
                ContentUnavailableView(
                    "Video Not Found",
                    systemImage: "film.fill",
                    description: Text("The requested video could not be loaded.")
                )
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    @ViewBuilder
    private func videoPlayerView(for video: VideoRecord) -> some View {
        VideoPlayer(player: player)
            .onAppear {
                let url = URL(fileURLWithPath: video.filePath)
                let newPlayer = AVPlayer(url: url)
                self.player = newPlayer
                newPlayer.play()
            }
            .navigationTitle(video.title)
    }
}
