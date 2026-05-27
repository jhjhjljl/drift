import Foundation

@MainActor
final class LibraryService {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var books: [Book] = []

    var lastOpenedBookID: UUID? {
        get { UserDefaults.standard.string(forKey: Keys.lastBook).flatMap(UUID.init) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: Keys.lastBook)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastBook)
            }
        }
    }

    private var libraryURL: URL {
        documentsURL.appendingPathComponent("Library", isDirectory: true)
    }

    private var booksURL: URL {
        libraryURL.appendingPathComponent("books.json")
    }

    private var positionsURL: URL {
        libraryURL.appendingPathComponent("positions.json")
    }

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        try? fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        loadBooks()
    }

    func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func artifacts(for book: Book) -> BookArtifacts {
        BookArtifacts(bookID: book.id, pdfFileName: book.fileName, libraryURL: libraryURL)
    }

    func pdfURL(for book: Book) -> URL {
        artifacts(for: book).pdfURL
    }

    func hasPDF(for book: Book) -> Bool {
        artifacts(for: book).hasPDF()
    }

    /// Clears resume target when the last book is missing or its PDF is gone.
    func reconcileLastOpenedBook() {
        guard let lastID = lastOpenedBookID else { return }
        guard let book = book(id: lastID), hasPDF(for: book) else {
            lastOpenedBookID = books.first?.id
            return
        }
    }

    func importPDF(from sourceURL: URL) async throws -> Book {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let id = UUID()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileName = "\(id.uuidString).pdf"
        let dest = libraryURL.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: sourceURL, to: dest)

        let manifest = try await Task.detached(priority: .userInitiated) {
            try PDFContentExtractor.buildManifest(at: dest)
        }.value

        guard manifest.isReflowable else {
            try? fileManager.removeItem(at: dest)
            throw LibraryError.noReadableText
        }

        let artifacts = BookArtifacts(bookID: id, pdfFileName: fileName, libraryURL: libraryURL)
        try artifacts.saveManifest(manifest)

        let book = Book(
            id: id,
            title: baseName,
            fileName: fileName,
            importedAt: Date(),
            progress: 0
        )
        books.insert(book, at: 0)
        saveBooks()
        savePosition(ReadingPosition(virtualPageIndex: 0, progress: 0), for: id)
        return book
    }

    func manifest(for book: Book) async throws -> BookManifest {
        let artifacts = artifacts(for: book)
        if let cached = artifacts.loadManifest(), cached.isCurrent {
            return cached
        }

        let manifest = try await Task.detached(priority: .userInitiated) {
            try PDFContentExtractor.buildManifest(at: artifacts.pdfURL)
        }.value

        try artifacts.saveManifest(manifest)
        artifacts.invalidatePaginationCache()
        return manifest
    }

    func removeBook(id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        let book = books[index]
        artifacts(for: book).removeAll()
        books.remove(at: index)
        saveBooks()
        removePosition(for: id)
        if lastOpenedBookID == id {
            lastOpenedBookID = books.first?.id
        }
    }

    func renameBook(id: UUID, title: String) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].title = title
        saveBooks()
    }

    func position(for bookID: UUID) -> ReadingPosition {
        loadPositions()[bookID.uuidString] ?? ReadingPosition(virtualPageIndex: 0, progress: 0)
    }

    func savePosition(_ position: ReadingPosition, for bookID: UUID) {
        var map = loadPositions()
        map[bookID.uuidString] = position
        persistPositions(map)
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            books[index].progress = position.progress
            saveBooks()
        }
    }

    var libraryDirectoryURL: URL {
        libraryURL
    }

    private func loadBooks() {
        guard let data = try? Data(contentsOf: booksURL),
              let decoded = try? decoder.decode([Book].self, from: data) else {
            books = []
            return
        }
        books = decoded.filter { fileManager.fileExists(atPath: pdfURL(for: $0).path) }
    }

    private func saveBooks() {
        guard let data = try? encoder.encode(books) else { return }
        try? data.write(to: booksURL, options: .atomic)
    }

    private func loadPositions() -> [String: ReadingPosition] {
        guard let data = try? Data(contentsOf: positionsURL),
              let decoded = try? decoder.decode([String: ReadingPosition].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistPositions(_ map: [String: ReadingPosition]) {
        guard let data = try? encoder.encode(map) else { return }
        try? data.write(to: positionsURL, options: .atomic)
    }

    private func removePosition(for bookID: UUID) {
        var map = loadPositions()
        map.removeValue(forKey: bookID.uuidString)
        persistPositions(map)
    }

    private enum Keys {
        static let lastBook = "drift.lastOpenedBookID"
    }
}

enum LibraryError: LocalizedError {
    case noReadableText

    var errorDescription: String? {
        switch self {
        case .noReadableText:
            "This PDF has no readable text to reflow."
        }
    }
}
