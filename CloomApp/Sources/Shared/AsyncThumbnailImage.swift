import SwiftUI
import AppKit

nonisolated(unsafe) let thumbnailCache: NSCache<NSString, NSImage> = {
    let cache = NSCache<NSString, NSImage>()
    cache.countLimit = 100
    cache.totalCostLimit = 100_000_000 // ~100MB
    return cache
}()

/// Async-loading thumbnail with cache. Displays a placeholder while loading.
struct AsyncThumbnailImage: View {
    let thumbnailPath: String
    let placeholderIcon: String
    let placeholderIconFont: Font

    @State private var thumbnailImage: NSImage?

    init(
        thumbnailPath: String,
        placeholderIcon: String = "film",
        placeholderIconFont: Font = .title2
    ) {
        self.thumbnailPath = thumbnailPath
        self.placeholderIcon = placeholderIcon
        self.placeholderIconFont = placeholderIconFont
    }

    var body: some View {
        Group {
            if let nsImage = thumbnailImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: placeholderIcon)
                            .font(placeholderIconFont)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .task(id: thumbnailPath) {
            guard !thumbnailPath.isEmpty else {
                thumbnailImage = nil
                return
            }
            let key = thumbnailPath as NSString
            if let cached = thumbnailCache.object(forKey: key) {
                thumbnailImage = cached
                return
            }
            let path = thumbnailPath
            let loadTask = Task.detached(priority: .medium) {
                NSImage(contentsOfFile: path)
            }
            if let loaded = await loadTask.value {
                thumbnailCache.setObject(loaded, forKey: key)
                thumbnailImage = loaded
            }
        }
    }
}
