import Foundation

/// On-disk artifacts for one **Book** in the **library** sandbox.
struct BookArtifacts {
    let bookID: UUID
    let pdfFileName: String
    let libraryURL: URL

    var pdfURL: URL {
        libraryURL.appendingPathComponent(pdfFileName)
    }

    func loadManifest() -> BookManifest? {
        ManifestStore.load(for: bookID, in: libraryURL)
    }

    func saveManifest(_ manifest: BookManifest) throws {
        try ManifestStore.save(manifest, for: bookID, in: libraryURL)
    }

    func removeManifest() {
        ManifestStore.remove(for: bookID, in: libraryURL)
    }

    func invalidatePaginationCache() {
        PaginationCacheStore.removeAll(for: bookID, in: libraryURL)
    }

    /// Removes PDF, manifest, and pagination cache for this **Book**.
    func removeAll() {
        try? FileManager.default.removeItem(at: pdfURL)
        removeManifest()
        invalidatePaginationCache()
    }

    func hasPDF() -> Bool {
        FileManager.default.fileExists(atPath: pdfURL.path)
    }
}
