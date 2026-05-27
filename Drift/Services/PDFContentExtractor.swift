import Foundation
import PDFKit

enum PDFContentExtractor {
    /// Minimum extracted characters to treat a page as reflowable text.
    static let minimumTextLength = 80

    static func buildManifest(at url: URL) throws -> BookManifest {
        guard let document = PDFDocument(url: url) else {
            throw LibraryError.noReadableText
        }
        return buildManifest(document: document)
    }

    static func buildManifest(document: PDFDocument) -> BookManifest {
        var segments: [ManifestSegment] = []
        var reflowRawPages: [String] = []

        func flushReflow() {
            guard !reflowRawPages.isEmpty else { return }
            let text = Self.reflowSegmentText(joiningRawPages: reflowRawPages)
            reflowRawPages.removeAll()
            segments.append(.reflow(text: text))
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let raw = page.string ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if isReflowableText(trimmed) {
                reflowRawPages.append(raw)
            } else {
                flushReflow()
                segments.append(.fixed(pdfPageIndex: index))
            }
        }
        flushReflow()

        return BookManifest(segments: segments)
    }

    /// Joins raw PDF page strings into one reflow segment (blank lines in source → paragraph breaks).
    static func reflowSegmentText(joiningRawPages pages: [String]) -> String {
        guard !pages.isEmpty else { return "" }
        let raw = pages
            .joined(separator: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return TextNormalizer.reflowableText(from: raw)
    }

    static func isReflowableText(_ text: String) -> Bool {
        guard text.count >= minimumTextLength else { return false }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return letters.count >= minimumTextLength / 2
    }
}
