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
        let footerSpace: CGFloat = 30
        let textWidth = a4Width - margin * 2
        let textAreaHeight = a4Height - margin * 2 - footerSpace

        // Layout the text to compute pages
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            size: NSSize(width: textWidth, height: textAreaHeight)
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        // Add additional text containers for overflow pages
        layoutManager.ensureLayout(for: textContainer)
        while layoutManager.textContainer(
            forGlyphAt: layoutManager.numberOfGlyphs - 1,
            effectiveRange: nil
        ) == nil || layoutManager.extraLineFragmentTextContainer != nil {
            let extraContainer = NSTextContainer(
                size: NSSize(width: textWidth, height: textAreaHeight)
            )
            extraContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(extraContainer)
            layoutManager.ensureLayout(for: extraContainer)
        }

        // Ensure layout is complete for all containers
        let containers = layoutManager.textContainers
        for container in containers {
            layoutManager.ensureLayout(for: container)
        }
        // Filter to containers that actually have glyphs
        let usedContainers = containers.filter { container in
            let range = layoutManager.glyphRange(for: container)
            return range.length > 0
        }
        let pageCount = max(1, usedContainers.count)

        // Create PDF
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw NSError(domain: "TranscriptExport", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF consumer"])
        }
        var mediaBox = CGRect(x: 0, y: 0, width: a4Width, height: a4Height)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "TranscriptExport", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)

        for pageIndex in 0..<pageCount {
            ctx.beginPDFPage(nil)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx

            // Draw text for this page
            let container = usedContainers[pageIndex]
            let glyphRange = layoutManager.glyphRange(for: container)

            // Translate to margin origin, flipped coordinate
            ctx.saveGState()
            ctx.translateBy(x: margin, y: a4Height - margin)
            ctx.scaleBy(x: 1, y: -1)

            layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)

            ctx.restoreGState()

            // Draw footer (in unflipped CG coordinates, origin bottom-left)
            drawFooter(ctx: ctx, pageNumber: pageIndex + 1, totalPages: pageCount,
                       pageWidth: a4Width, margin: margin)

            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
        }

        ctx.closePDF()
        try pdfData.write(to: destURL, options: .atomic)
        logger.info("Exported transcript as PDF (\(pageCount) pages) → \(destURL.lastPathComponent)")
    }

    private static func drawFooter(
        ctx: CGContext, pageNumber: Int, totalPages: Int,
        pageWidth: CGFloat, margin: CGFloat
    ) {
        let textWidth = pageWidth - margin * 2
        let footerY: CGFloat = 36

        // Reset to unflipped coordinate system for footer
        ctx.saveGState()
        ctx.textMatrix = .identity

        // Thin line above footer
        ctx.setStrokeColor(NSColor(white: 0.88, alpha: 1.0).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: footerY + 12))
        ctx.addLine(to: CGPoint(x: margin + textWidth, y: footerY + 12))
        ctx.strokePath()

        // Left: "Generated by Cloom"
        let footerFont = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let footerColor = NSColor(white: 0.6, alpha: 1.0)
        let leftStr = NSAttributedString(string: "Generated by Cloom", attributes: [
            .font: footerFont, .foregroundColor: footerColor
        ])
        let leftLine = CTLineCreateWithAttributedString(leftStr)
        ctx.textPosition = CGPoint(x: margin, y: footerY)
        CTLineDraw(leftLine, ctx)

        // Right: "Page X of Y"
        let accentColor = NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
        let rightStr = NSAttributedString(string: "Page \(pageNumber) of \(totalPages)", attributes: [
            .font: footerFont, .foregroundColor: accentColor
        ])
        let rightLine = CTLineCreateWithAttributedString(rightStr)
        let rightWidth = CTLineGetTypographicBounds(rightLine, nil, nil, nil)
        ctx.textPosition = CGPoint(x: margin + textWidth - rightWidth, y: footerY)
        CTLineDraw(rightLine, ctx)

        ctx.restoreGState()
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
        let mediumGray = NSColor(white: 0.15, alpha: 1.0)
        let lightGray = NSColor(white: 0.65, alpha: 1.0)
        let dividerColor = NSColor(white: 0.85, alpha: 1.0)

        let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let timestampFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        let captionFont = NSFont.systemFont(ofSize: 9, weight: .medium)

        // Title style
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.paragraphSpacing = 2

        // Subtitle / meta style
        let metaStyle = NSMutableParagraphStyle()
        metaStyle.paragraphSpacing = 8

        // Heading style
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 4
        headingStyle.paragraphSpacing = 4

        // Body style
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 3
        bodyStyle.paragraphSpacing = 8

        // Chapter line style
        let chapterStyle = NSMutableParagraphStyle()
        chapterStyle.lineSpacing = 2
        chapterStyle.paragraphSpacing = 3
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
            summaryLabelStyle.paragraphSpacingBefore = 2
            summaryLabelStyle.paragraphSpacing = 3
            result.append(NSAttributedString(
                string: "SUMMARY\n",
                attributes: [
                    .font: captionFont, .foregroundColor: accentColor,
                    .paragraphStyle: summaryLabelStyle, .kern: 2.0
                ]
            ))
            let summaryStyle = NSMutableParagraphStyle()
            summaryStyle.lineSpacing = 2
            summaryStyle.paragraphSpacing = 6
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
        dividerStyle.paragraphSpacing = 8
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
            chapterDividerStyle.paragraphSpacingBefore = 5
            chapterDividerStyle.paragraphSpacing = 8
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

