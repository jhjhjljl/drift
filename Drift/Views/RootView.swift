import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var didLaunch = false

    var body: some View {
        Group {
            if appModel.showLibrary {
                LibraryView()
            } else if let id = appModel.activeBookID,
                      let book = appModel.library.book(id: id),
                      appModel.library.hasPDF(for: book) {
                ReaderView(book: book)
            } else {
                LibraryView()
                    .onAppear {
                        appModel.activeBookID = nil
                        appModel.showLibrary = true
                    }
            }
        }
        .onAppear {
            guard !didLaunch else { return }
            didLaunch = true
            appModel.onLaunch()
        }
    }
}
