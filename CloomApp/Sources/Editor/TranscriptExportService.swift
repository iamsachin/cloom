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
        let attributedString = buildStyledAttributedString(
            title: title, transcript: transcript, chapters: chapters
        )

        // A4: 595.28 x 841.89 points, with 60pt margins
        let a4Width: CGFloat = 595.28
        let margin: CGFloat = 60
        let textWidth = a4Width - margin * 2  // ~475pt

        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: NSSize(width: textWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: textWidth, height: textHeight))
        textView.textStorage?.setAttributedString(attributedString)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.size = NSSize(width: textWidth, height: textHeight)
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


    private static func buildStyledAttributedString(
        title: String,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let accentColor = NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
        let darkGray = NSColor(white: 0.2, alpha: 1.0)
        let mediumGray = NSColor(white: 0.45, alpha: 1.0)
        let lightGray = NSColor(white: 0.65, alpha: 1.0)
        let dividerColor = NSColor(white: 0.85, alpha: 1.0)

        let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
        let headingFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let timestampFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        let captionFont = NSFont.systemFont(ofSize: 9, weight: .medium)

        // Title style
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.paragraphSpacing = 4

        // Subtitle / meta style
        let metaStyle = NSMutableParagraphStyle()
        metaStyle.paragraphSpacing = 16

        // Heading style
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 8
        headingStyle.paragraphSpacing = 8

        // Body style
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 5
        bodyStyle.paragraphSpacing = 14

        // Chapter line style
        let chapterStyle = NSMutableParagraphStyle()
        chapterStyle.lineSpacing = 3
        chapterStyle.paragraphSpacing = 6
        chapterStyle.headIndent = 44
        chapterStyle.firstLineHeadIndent = 0

        // --- Title ---
        result.append(NSAttributedString(
            string: title + "\n",
            attributes: [.font: titleFont, .foregroundColor: darkGray, .paragraphStyle: titleStyle]
        ))

        // Meta line: "Cloom Transcript" + date
        let dateStr = Date.now.formatted(date: .abbreviated, time: .shortened)
        result.append(NSAttributedString(
            string: "Cloom Transcript  \(dateStr)\n",
            attributes: [.font: captionFont, .foregroundColor: lightGray, .paragraphStyle: metaStyle]
        ))

        // Divider (thin line made of underscores styled as a colored line)
        let dividerStyle = NSMutableParagraphStyle()
        dividerStyle.paragraphSpacing = 16
        result.append(NSAttributedString(
            string: String(repeating: "\u{2500}", count: 80) + "\n",
            attributes: [.font: NSFont.systemFont(ofSize: 5), .foregroundColor: dividerColor, .paragraphStyle: dividerStyle]
        ))

        // --- Chapters ---
        if !chapters.isEmpty {
            result.append(NSAttributedString(
                string: "CHAPTERS\n",
                attributes: [
                    .font: captionFont, .foregroundColor: accentColor,
                    .paragraphStyle: headingStyle, .kern: 2.0
                ]
            ))

            for chapter in chapters.sorted(by: { $0.startMs < $1.startMs }) {
                // Timestamp
                result.append(NSAttributedString(
                    string: "  \(formatTimestamp(ms: chapter.startMs))  ",
                    attributes: [.font: timestampFont, .foregroundColor: accentColor, .paragraphStyle: chapterStyle]
                ))
                // Chapter title
                result.append(NSAttributedString(
                    string: "\(chapter.title)\n",
                    attributes: [.font: bodyFont, .foregroundColor: darkGray]
                ))
            }

            // Divider
            let chapterDividerStyle = NSMutableParagraphStyle()
            chapterDividerStyle.paragraphSpacingBefore = 10
            chapterDividerStyle.paragraphSpacing = 16
            result.append(NSAttributedString(
                string: String(repeating: "\u{2500}", count: 80) + "\n",
                attributes: [.font: NSFont.systemFont(ofSize: 5), .foregroundColor: dividerColor, .paragraphStyle: chapterDividerStyle]
            ))
        }

        // --- Transcript ---
        result.append(NSAttributedString(
            string: "TRANSCRIPT\n",
            attributes: [
                .font: captionFont, .foregroundColor: accentColor,
                .paragraphStyle: headingStyle, .kern: 2.0
            ]
        ))

        let paragraphs = buildParagraphs(from: transcript)
        result.append(NSAttributedString(
            string: paragraphs,
            attributes: [.font: bodyFont, .foregroundColor: mediumGray, .paragraphStyle: bodyStyle]
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
