import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Group {
                if appModel.library.books.isEmpty {
                    ContentUnavailableView(
                        "No books yet",
                        systemImage: "books.vertical",
                        description: Text("Import a PDF novel from Files.")
                    )
                } else {
                    List {
                        ForEach(appModel.library.books) { book in
                            Button {
                                appModel.openBook(book.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.displayTitle)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    ProgressView(value: book.progress)
                                        .tint(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .disabled(appModel.isImporting)
                        }
                        .onDelete(perform: deleteBooks)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Drift")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import PDF")
                    .disabled(appModel.isImporting)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    Task {
                        await importPDF(url)
                    }
                case let .failure(error):
                    importError = error.localizedDescription
                }
            }
            .alert("Import failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { appModel.importErrorMessage != nil },
                    set: { if !$0 { appModel.importErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appModel.importErrorMessage ?? "")
            }
            .overlay {
                if appModel.isImporting {
                    ImportOverlay()
                }
            }
        }
    }

    private func importPDF(_ url: URL) async {
        await appModel.importPDF(from: url)
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            let id = appModel.library.books[index].id
            appModel.library.removeBook(id: id)
        }
    }
}

private struct ImportOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Importing…")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
