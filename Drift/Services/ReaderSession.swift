import Foundation
import Observation
import PDFKit
import UIKit

enum ReaderScreen: Equatable {
    case reflow(textHash: Int, pageIndex: Int)
    case fixed(pdfPageIndex: Int)

    static func == (lhs: ReaderScreen, rhs: ReaderScreen) -> Bool {
        switch (lhs, rhs) {
        case let (.reflow(h1, p1), .reflow(h2, p2)):
            h1 == h2 && p1 == p2
        case let (.fixed(i1), .fixed(i2)):
            i1 == i2
        default:
            false
        }
    }
}

@MainActor
@Observable
final class ReaderSession {
    let book: Book
    let pdfURL: URL

    private(set) var screens: [ReaderScreen] = []
    private(set) var totalScreens: Int = 0
    /// Highest virtual page index that can be displayed (0-based, inclusive).
    private(set) var readyThroughIndex: Int = -1
    private(set) var isComplete = false

    private var reflowPages: [Int: [NSAttributedString]] = [:]
    private var document: PDFDocument?

    init(book: Book, pdfURL: URL) {
        self.book = book
        self.pdfURL = pdfURL
    }

    var isReady: Bool {
        readyThroughIndex >= 0
    }

    func isPageReady(at index: Int) -> Bool {
        index >= 0 && index <= readyThroughIndex
    }

    func progress(forVirtualIndex index: Int) -> Double {
        guard totalScreens > 1 else { return totalScreens == 1 && index > 0 ? 1 : 0 }
        return Double(index) / Double(totalScreens - 1)
    }

    func screen(at index: Int) -> ReaderScreen? {
        guard index >= 0, index < screens.count else { return nil }
        return screens[index]
    }

    func reflowText(for screen: ReaderScreen) -> NSAttributedString {
        guard case let .reflow(hash, pageIndex) = screen,
              let pages = reflowPages[hash],
              pageIndex < pages.count else {
            return NSAttributedString(string: "")
        }
        return pages[pageIndex]
    }

    func fixedPage(at pdfIndex: Int) -> PDFPage? {
        document?.page(at: pdfIndex)
    }

    func load(
        viewportSize: CGSize,
        manifest: BookManifest,
        libraryURL: URL
    ) async -> Bool {
        reset()

        guard viewportSize.width > 50, viewportSize.height > 50 else { return false }

        if let cache = PaginationCacheStore.load(for: book.id, viewportSize: viewportSize, in: libraryURL) {
            apply(cache: cache)
            isComplete = true
            return isReady
        }

        guard manifest.isReflowable else { return false }
        document = PDFDocument(url: pdfURL)

        var builtScreens: [ReaderScreen] = []
        var builtReflowPages: [Int: [NSAttributedString]] = [:]
        var cacheScreens: [CachedScreen] = []
        var cacheReflowTexts: [Int: [String]] = [:]
        var chunkID = 0

        for segment in manifest.segments {
            if Task.isCancelled { return false }

            switch segment {
            case let .reflow(text):
                var pages: [NSAttributedString] = []
                var pageTexts: [String] = []

                for await (pageIndex, pageString) in Self.reflowPageStream(text: text, size: viewportSize) {
                    if Task.isCancelled { return false }

                    let pageText = ReaderTheme.attributedString(for: pageString)
                    pages.append(pageText)
                    pageTexts.append(pageString)

                    builtScreens.append(.reflow(textHash: chunkID, pageIndex: pageIndex))
                    cacheScreens.append(.reflow(chunkIndex: chunkID, pageIndex: pageIndex))
                    screens = builtScreens
                    totalScreens = builtScreens.count
                    readyThroughIndex = builtScreens.count - 1
                    builtReflowPages[chunkID] = pages
                    reflowPages = builtReflowPages

                    if builtScreens.count == 1 {
                        #if DEBUG
                        OpenDiagnostics.logFirstScreenReady(extra: "reflow chunk \(chunkID)")
                        #endif
                        await Task.yield()
                    }
                }

                guard !pages.isEmpty else { continue }

                cacheReflowTexts[chunkID] = pageTexts
                chunkID += 1

            case let .fixed(pdfPageIndex):
                builtScreens.append(.fixed(pdfPageIndex: pdfPageIndex))
                cacheScreens.append(.fixed(pdfPageIndex: pdfPageIndex))
                screens = builtScreens
                totalScreens = builtScreens.count
                readyThroughIndex = builtScreens.count - 1

                if builtScreens.count == 1 {
                    await Task.yield()
                }
            }
        }

        isComplete = true

        let cache = PaginationCache(
            layoutVersion: ReaderTheme.layoutVersion,
            viewportWidth: Double(viewportSize.width.rounded()),
            viewportHeight: Double(viewportSize.height.rounded()),
            screens: cacheScreens,
            reflowTexts: cacheReflowTexts
        )
        try? PaginationCacheStore.save(cache, for: book.id, viewportSize: viewportSize, in: libraryURL)

        return isReady
    }

    nonisolated private static func reflowPageStream(
        text: String,
        size: CGSize
    ) -> AsyncStream<(Int, String)> {
        AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                let paginator = ReflowPaginator()
                paginator.reset(text: text, size: size)

                guard paginator.pageCount > 0 || paginator.hasMorePages else {
                    continuation.finish()
                    return
                }

                var pageIndex = 0
                repeat {
                    if pageIndex > 0, !paginator.appendNextPage() {
                        break
                    } else if pageIndex == 0 {
                        _ = paginator.appendNextPage()
                    }

                    guard paginator.pageCount > pageIndex else { break }

                    let pageText = paginator.text(forPage: pageIndex)
                    continuation.yield((pageIndex, pageText.string))
                    pageIndex += 1
                } while paginator.hasMorePages

                continuation.finish()
            }
        }
    }

    private func reset() {
        screens = []
        totalScreens = 0
        readyThroughIndex = -1
        isComplete = false
        reflowPages.removeAll()
        document = nil
    }

    private func apply(cache: PaginationCache) {
        var builtScreens: [ReaderScreen] = []
        var builtReflowPages: [Int: [NSAttributedString]] = [:]

        for cached in cache.screens {
            switch cached {
            case let .reflow(chunkIndex, pageIndex):
                builtScreens.append(.reflow(textHash: chunkIndex, pageIndex: pageIndex))
            case let .fixed(pdfPageIndex):
                builtScreens.append(.fixed(pdfPageIndex: pdfPageIndex))
            }
        }

        for (chunkIndex, texts) in cache.reflowTexts {
            builtReflowPages[chunkIndex] = texts.map { ReaderTheme.attributedString(for: $0) }
        }

        document = PDFDocument(url: pdfURL)
        screens = builtScreens
        reflowPages = builtReflowPages
        totalScreens = builtScreens.count
        readyThroughIndex = max(builtScreens.count - 1, -1)
    }
}
