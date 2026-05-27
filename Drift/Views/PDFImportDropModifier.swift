import SwiftUI
import UniformTypeIdentifiers

struct PDFImportDropModifier: ViewModifier {
  @Environment(AppModel.self) private var appModel
  @Binding var isDropTargeted: Bool

  func body(content: Content) -> some View {
    content
      .onDrop(of: [.pdf, .fileURL], isTargeted: $isDropTargeted) { providers in
        Task { @MainActor in
          await PDFDropLoader.importFirstPDF(from: providers, appModel: appModel)
        }
        return true
      }
  }
}

extension View {
  func acceptingPDFImport(isTargeted: Binding<Bool> = .constant(false)) -> some View {
    modifier(PDFImportDropModifier(isDropTargeted: isTargeted))
  }
}
