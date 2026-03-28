import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "TranscriptExport")

enum TranscriptExportService {

    // MARK: - Markdown

    static func exportAsMarkdown(
        title: String,
        summary: String?,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord],
        destURL: URL
    ) throws {
        var md = "# \(title)\n\n"

        if let summary, !summary.isEmpty {
            md += "> \(summary)\n\n"
        }

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
        summary: String?,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord],
        durationMs: Int64 = 0,
        destURL: URL
    ) throws {
        let attributedString = buildStyledAttributedString(
            title: title, summary: summary, transcript: transcript,
            chapters: chapters, durationMs: durationMs
        )

        // A4 dimensions in points
        let a4Width: CGFloat = 595.28
        let a4Height: CGFloat = 841.89
        let margin: CGFloat = 60
        let footerHeight: CGFloat = 24
        let textWidth = a4Width - margin * 2
        let bottomMargin = margin + footerHeight

        // Create a paginated text view with footer
        let pdfView = PaginatedPDFView(
            attributedString: attributedString,
            pageSize: NSSize(width: a4Width, height: a4Height),
            margins: NSEdgeInsets(top: margin, left: margin, bottom: bottomMargin, right: margin),
            title: title
        )

        // Configure print info for A4
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: a4Width, height: a4Height)
        printInfo.topMargin = margin
        printInfo.bottomMargin = bottomMargin
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destURL

        let printOp = NSPrintOperation(view: pdfView, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false
        printOp.run()

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
        summary: String?,
        transcript: TranscriptRecord,
        chapters: [ChapterRecord],
        durationMs: Int64 = 0
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

        // Meta line: "Cloom Transcript" + duration + date
        let dateStr = Date.now.formatted(date: .abbreviated, time: .shortened)
        var metaText = "Cloom Transcript"
        if durationMs > 0 {
            metaText += "  ·  \(formatTimestamp(ms: durationMs))"
        }
        metaText += "  ·  \(dateStr)"
        result.append(NSAttributedString(
            string: metaText + "\n",
            attributes: [.font: captionFont, .foregroundColor: lightGray, .paragraphStyle: metaStyle]
        ))

        // Summary / description
        if let summary, !summary.isEmpty {
            let summaryLabelStyle = NSMutableParagraphStyle()
            summaryLabelStyle.paragraphSpacingBefore = 4
            summaryLabelStyle.paragraphSpacing = 4
            result.append(NSAttributedString(
                string: "SUMMARY\n",
                attributes: [
                    .font: captionFont, .foregroundColor: accentColor,
                    .paragraphStyle: summaryLabelStyle, .kern: 2.0
                ]
            ))
            let summaryStyle = NSMutableParagraphStyle()
            summaryStyle.lineSpacing = 3
            summaryStyle.paragraphSpacing = 12
            let italicFont = NSFontManager.shared.convert(
                NSFont.systemFont(ofSize: 11), toHaveTrait: .italicFontMask
            )
            result.append(NSAttributedString(
                string: summary + "\n",
                attributes: [
                    .font: italicFont,
                    .foregroundColor: mediumGray,
                    .paragraphStyle: summaryStyle
                ]
            ))
        }

        // Divider
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

// MARK: - Paginated PDF View with Footer

/// NSTextView subclass that draws a footer with page number and branding on each printed page.
private final class PaginatedPDFView: NSTextView {
    private let pdfTitle: String

    init(
        attributedString: NSAttributedString,
        pageSize: NSSize,
        margins: NSEdgeInsets,
        title: String
    ) {
        let textWidth = pageSize.width - margins.left - margins.right
        let textHeight = pageSize.height - margins.top - margins.bottom
        self.pdfTitle = title
        super.init(frame: NSRect(x: 0, y: 0, width: textWidth, height: textHeight))
        textStorage?.setAttributedString(attributedString)
        textContainer?.lineFragmentPadding = 0
        textContainer?.containerSize = NSSize(width: textWidth, height: .greatestFiniteMagnitude)
        isEditable = false
        backgroundColor = .white
        layoutManager?.ensureLayout(for: textContainer!)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func drawPageBorder(with borderSize: NSSize) {
        super.drawPageBorder(with: borderSize)

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        let margin: CGFloat = 60
        let footerY: CGFloat = 30
        let textWidth = borderSize.width - margin * 2
        let footerFont = NSFont.systemFont(ofSize: 8, weight: .regular)
        let footerColor = NSColor(white: 0.6, alpha: 1.0)
        let accentColor = NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)

        // Thin line above footer
        let lineY = footerY + 14
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: margin, y: lineY))
        linePath.line(to: NSPoint(x: margin + textWidth, y: lineY))
        NSColor(white: 0.88, alpha: 1.0).setStroke()
        linePath.lineWidth = 0.5
        linePath.stroke()

        // Left: "Generated by Cloom"
        let leftAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont, .foregroundColor: footerColor
        ]
        let leftStr = NSAttributedString(string: "Generated by Cloom", attributes: leftAttrs)
        leftStr.draw(at: NSPoint(x: margin, y: footerY))

        // Right: page number
        let currentPage = self.currentPage
        let pageStr = NSAttributedString(
            string: "Page \(currentPage)",
            attributes: [.font: footerFont, .foregroundColor: accentColor]
        )
        let pageStrSize = pageStr.size()
        pageStr.draw(at: NSPoint(x: margin + textWidth - pageStrSize.width, y: footerY))

        context.restoreGraphicsState()
    }

    private var currentPage: Int {
        guard let printOp = NSPrintOperation.current else { return 1 }
        return printOp.currentPage
    }
}
