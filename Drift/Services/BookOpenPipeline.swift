import CoreGraphics
import Foundation

/// Opens a **Book** for reading: manifest, **Resume** position, and progressive pagination.
@MainActor
enum BookOpenPipeline {
    struct PreparedOpen {
        let session: ReaderSession
        let openTargetIndex: Int
        let manifest: BookManifest
        let libraryURL: URL
    }

    /// Manifest + session ready; call `loadPages` to paginate (may stream screens).
    static func prepare(
        book: Book,
        library: LibraryService
    ) async throws -> PreparedOpen {
        guard library.hasPDF(for: book) else {
            throw BookOpenError.missingPDF
        }

        let saved = library.position(for: book.id)
        let manifest = try await library.manifest(for: book)
        let artifacts = library.artifacts(for: book)
        let session = ReaderSession(book: book, pdfURL: artifacts.pdfURL)

        return PreparedOpen(
            session: session,
            openTargetIndex: saved.virtualPageIndex,
            manifest: manifest,
            libraryURL: library.libraryDirectoryURL
        )
    }

    @discardableResult
    static func loadPages(_ prepared: PreparedOpen, viewportSize: CGSize) async -> Bool {
        await prepared.session.load(
            viewportSize: viewportSize,
            manifest: prepared.manifest,
            libraryURL: prepared.libraryURL
        )
    }

    static func clampedIndex(_ index: Int, session: ReaderSession) -> Int {
        min(index, max(session.totalScreens - 1, 0))
    }

    /// Page to show after pagination finishes. Prefer the saved open target unless the reader
    /// visibly moved to another page while screens were still streaming in.
    nonisolated static func completionPageIndex(virtualIndex: Int, openTargetIndex: Int) -> Int {
        if virtualIndex == openTargetIndex { return openTargetIndex }
        if virtualIndex == 0, openTargetIndex != 0 { return openTargetIndex }
        return virtualIndex
    }
}

enum BookOpenError: Error {
    case missingPDF
    case loadFailed
}
