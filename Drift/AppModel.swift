import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    let library = LibraryService()

    var activeBookID: UUID?
    var showLibrary = false
    var importErrorMessage: String?
    var isImporting = false

    func onLaunch() {
        library.reconcileLastOpenedBook()

        if let lastID = library.lastOpenedBookID,
           let book = library.book(id: lastID),
           library.hasPDF(for: book) {
            activeBookID = lastID
            showLibrary = false
        } else {
            activeBookID = nil
            showLibrary = true
        }
    }

    func openBook(_ id: UUID) {
        activeBookID = id
        library.lastOpenedBookID = id
        showLibrary = false
    }

    func openLibrary() {
        showLibrary = true
    }

    func closeReader() {
        showLibrary = true
    }

    func importPDF(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let book = try await library.importPDF(from: url)
            openBook(book.id)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}
