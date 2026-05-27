import CoreGraphics
import Foundation

enum PaginationCacheStore {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func directory(for bookID: UUID, in libraryURL: URL) -> URL {
        libraryURL.appendingPathComponent("Cache/\(bookID.uuidString)", isDirectory: true)
    }

    static func fileName(for viewportSize: CGSize) -> String {
        let width = Int(viewportSize.width.rounded())
        let height = Int(viewportSize.height.rounded())
        return "v\(ReaderTheme.layoutVersion)_\(width)x\(height).json"
    }

    static func load(
        for bookID: UUID,
        viewportSize: CGSize,
        in libraryURL: URL
    ) -> PaginationCache? {
        let url = directory(for: bookID, in: libraryURL).appendingPathComponent(fileName(for: viewportSize))
        guard let data = try? Data(contentsOf: url),
              let cache = try? decoder.decode(PaginationCache.self, from: data),
              cache.layoutVersion == ReaderTheme.layoutVersion,
              cache.viewportWidth == Double(viewportSize.width.rounded()),
              cache.viewportHeight == Double(viewportSize.height.rounded()) else {
            return nil
        }
        return cache
    }

    static func save(
        _ cache: PaginationCache,
        for bookID: UUID,
        viewportSize: CGSize,
        in libraryURL: URL
    ) throws {
        let dir = directory(for: bookID, in: libraryURL)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName(for: viewportSize))
        let data = try encoder.encode(cache)
        try data.write(to: url, options: .atomic)
    }

    static func removeAll(for bookID: UUID, in libraryURL: URL) {
        let dir = directory(for: bookID, in: libraryURL)
        try? FileManager.default.removeItem(at: dir)
    }
}
