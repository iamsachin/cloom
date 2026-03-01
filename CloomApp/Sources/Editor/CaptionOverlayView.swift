import SwiftUI

struct CaptionOverlayView: View {
    let phrases: [CaptionPhrase]
    let currentTimeMs: Int64
    let isEnabled: Bool

    var body: some View {
        if isEnabled, !phrases.isEmpty, let phrase = currentPhrase {
            HStack(spacing: 4) {
                ForEach(phrase.words) { word in
                    let isActive = word.startMs <= currentTimeMs && currentTimeMs < word.endMs
                    Text(word.word)
                        .fontWeight(isActive ? .bold : .regular)
                        .foregroundStyle(isActive ? Color.accentColor : .white)
                }
            }
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.captionBackground, in: Capsule())
            .padding(.bottom, 16)
            .allowsHitTesting(false)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: phrase.id)
        }
    }

    private var currentPhrase: CaptionPhrase? {
        // Binary search for current phrase
        guard !phrases.isEmpty else { return nil }

        var lo = 0
        var hi = phrases.count - 1
        var result: CaptionPhrase?

        while lo <= hi {
            let mid = (lo + hi) / 2
            let phrase = phrases[mid]
            if currentTimeMs >= phrase.startMs && currentTimeMs < phrase.endMs {
                return phrase
            } else if currentTimeMs < phrase.startMs {
                hi = mid - 1
            } else {
                result = phrase // keep as fallback
                lo = mid + 1
            }
        }
        return result
    }

    /// Forward to the standalone function for backwards compatibility with tests.
    nonisolated static func buildPhrases(from words: [TranscriptWordSnapshot]) -> [CaptionPhrase] {
        buildCaptionPhrases(from: words)
    }
}
