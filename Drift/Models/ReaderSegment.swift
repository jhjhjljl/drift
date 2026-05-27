import Foundation

enum ManifestSegment: Codable, Equatable {
    case reflow(text: String)
    case fixed(pdfPageIndex: Int)
}

struct BookManifest: Codable, Equatable {
    /// Bump when manifest extraction rules change; stale manifests are rebuilt from the library PDF.
    static let currentVersion = 1

    var manifestVersion: Int
    let segments: [ManifestSegment]

    init(manifestVersion: Int = BookManifest.currentVersion, segments: [ManifestSegment]) {
        self.manifestVersion = manifestVersion
        self.segments = segments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manifestVersion = try container.decodeIfPresent(Int.self, forKey: .manifestVersion) ?? 0
        segments = try container.decode([ManifestSegment].self, forKey: .segments)
    }

    var isCurrent: Bool {
        manifestVersion >= Self.currentVersion
    }

    var isReflowable: Bool {
        segments.contains { segment in
            if case let .reflow(text) = segment {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
    }
}

enum CachedScreen: Codable, Equatable {
    case reflow(chunkIndex: Int, pageIndex: Int)
    case fixed(pdfPageIndex: Int)
}

struct PaginationCache: Codable, Equatable {
    let layoutVersion: Int
    let viewportWidth: Double
    let viewportHeight: Double
    let screens: [CachedScreen]
    /// Reflow page plain text keyed by chunk index.
    let reflowTexts: [Int: [String]]
}
