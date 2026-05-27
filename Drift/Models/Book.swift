import Foundation

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var fileName: String
    var importedAt: Date
    var progress: Double

    var displayTitle: String {
        title.isEmpty ? fileName : title
    }
}
