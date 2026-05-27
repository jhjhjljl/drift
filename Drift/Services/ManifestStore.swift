import Foundation

enum ManifestStore {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func url(for bookID: UUID, in libraryURL: URL) -> URL {
        libraryURL.appendingPathComponent("\(bookID.uuidString).manifest.json")
    }

    static func load(for bookID: UUID, in libraryURL: URL) -> BookManifest? {
        let url = url(for: bookID, in: libraryURL)
        guard let data = try? Data(contentsOf: url),
              let manifest = try? decoder.decode(BookManifest.self, from: data) else {
            return nil
        }
        return manifest
    }

    static func save(_ manifest: BookManifest, for bookID: UUID, in libraryURL: URL) throws {
        let url = url(for: bookID, in: libraryURL)
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    static func remove(for bookID: UUID, in libraryURL: URL) {
        let url = url(for: bookID, in: libraryURL)
        try? FileManager.default.removeItem(at: url)
    }
}
