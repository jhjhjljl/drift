import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporting = false
    @State private var importError: String?
    @State private var renamingBookID: UUID?
    @State private var renameDraft = ""

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
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Rename") {
                                    startRename(for: book)
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    appModel.library.removeBook(id: book.id)
                                }
                            }
                            .contextMenu {
                                Button("Rename") {
                                    startRename(for: book)
                                }
                                Button("Delete", role: .destructive) {
                                    appModel.library.removeBook(id: book.id)
                                }
                            }
                        }
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
            .sheet(isPresented: Binding(
                get: { renamingBookID != nil },
                set: { if !$0 { cancelRename() } }
            )) {
                RenameBookSheet(
                    title: $renameDraft,
                    originalTitle: currentRenameOriginalTitle,
                    onCancel: cancelRename,
                    onSave: commitRename
                )
            }
        }
    }

    private func importPDF(_ url: URL) async {
        await appModel.importPDF(from: url)
    }

    private var currentRenameOriginalTitle: String {
        guard let id = renamingBookID,
              let book = appModel.library.book(id: id) else { return "" }
        return book.title
    }

    private func startRename(for book: Book) {
        renamingBookID = book.id
        renameDraft = book.title
    }

    private func cancelRename() {
        renamingBookID = nil
        renameDraft = ""
    }

    private func commitRename() {
        guard let id = renamingBookID else { return }
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let book = appModel.library.book(id: id), book.title != trimmed else { return }
        appModel.library.renameBook(id: id, title: trimmed)
        cancelRename()
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

private struct RenameBookSheet: View {
    @Binding var title: String
    let originalTitle: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSaveDisabled: Bool {
        trimmedTitle.isEmpty || trimmedTitle == originalTitle
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Book title", text: $title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Rename Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(isSaveDisabled)
                }
            }
        }
    }
}
