import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "TranscriptExport")

enum TranscriptExportService {

    // MARK: - Markdown

    static func exportAsMarkdown(
        title: String,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord],
        destURL: URL
    ) throws {
        var md = "# \(title)\n\n"

        if !chapters.isEmpty {
            md += "## Chapters\n\n"
            for chapter in chapters.sorted(by: { $0.startMs < $1.startMs }) {
                md += "- **\(formatTimestamp(ms: chapter.startMs))** — \(chapter.title)\n"
            }
            md += "\n---\n\n"
        }

        md += "## Transcript\n\n"
        md += buildParagraphs(from: transcript)
        md += "\n"

        try md.write(to: destURL, atomically: true, encoding: .utf8)
        logger.info("Exported transcript as Markdown → \(destURL.lastPathComponent)")
    }

    // MARK: - PDF

    @MainActor
    static func exportAsPDF(
        title: String,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord],
        destURL: URL
    ) throws {
        let attributedString = buildAttributedString(title: title, transcript: transcript, chapters: chapters)

        // US Letter with 1-inch margins
        let pageWidth: CGFloat = 612 - 144  // 468pt text width
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: NSSize(width: pageWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        // Force full layout
        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height

        // Create an NSTextView sized to fit all content
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: textHeight))
        textView.textStorage?.setAttributedString(attributedString)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.size = NSSize(width: pageWidth, height: textHeight)
        textView.isEditable = false
        textView.backgroundColor = .white
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try pdfData.write(to: destURL, options: .atomic)
        logger.info("Exported transcript as PDF → \(destURL.lastPathComponent)")
    }

    // MARK: - Helpers

    private static func buildParagraphs(from transcript: TranscriptRecord) -> String {
        let sortedWords = transcript.words.sorted { $0.startMs < $1.startMs }
        guard !sortedWords.isEmpty else { return transcript.fullText }

        var paragraphs: [String] = []
        var currentParagraph: [String] = []

        for word in sortedWords {
            if word.isParagraphStart && !currentParagraph.isEmpty {
                paragraphs.append(currentParagraph.joined(separator: " "))
                currentParagraph = []
            }
            currentParagraph.append(word.word)
        }
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.joined(separator: " "))
        }

        return paragraphs.joined(separator: "\n\n")
    }


    private static func buildAttributedString(
        title: String,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let headingFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let bodyColor = NSColor.textColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12

        // Title
        result.append(NSAttributedString(
            string: title + "\n\n",
            attributes: [.font: titleFont, .foregroundColor: bodyColor]
        ))

        // Chapters
        if !chapters.isEmpty {
            result.append(NSAttributedString(
                string: "Chapters\n\n",
                attributes: [.font: headingFont, .foregroundColor: bodyColor]
            ))
            for chapter in chapters.sorted(by: { $0.startMs < $1.startMs }) {
                let line = "\(formatTimestamp(ms: chapter.startMs)) — \(chapter.title)\n"
                result.append(NSAttributedString(
                    string: line,
                    attributes: [.font: bodyFont, .foregroundColor: bodyColor, .paragraphStyle: paragraphStyle]
                ))
            }
            result.append(NSAttributedString(string: "\n"))
        }

        // Transcript
        result.append(NSAttributedString(
            string: "Transcript\n\n",
            attributes: [.font: headingFont, .foregroundColor: bodyColor]
        ))

        let paragraphs = buildParagraphs(from: transcript)
        result.append(NSAttributedString(
            string: paragraphs,
            attributes: [.font: bodyFont, .foregroundColor: bodyColor, .paragraphStyle: paragraphStyle]
        ))

        return result
    }

    static func formatTimestamp(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
