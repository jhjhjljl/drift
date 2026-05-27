import Foundation
import UniformTypeIdentifiers

enum PDFDropLoader {
  @MainActor
  static func importFirstPDF(from providers: [NSItemProvider], appModel: AppModel) async {
    for provider in providers {
      if let url = await loadPDFURL(from: provider) {
        await appModel.importPDF(from: url)
        return
      }
    }
  }

  private static func loadPDFURL(from provider: NSItemProvider) async -> URL? {
    let types = [UTType.pdf.identifier, UTType.fileURL.identifier]
    for type in types where provider.hasItemConformingToTypeIdentifier(type) {
      if let url = await loadFileRepresentation(from: provider, typeIdentifier: type) {
        return url
      }
    }
    return nil
  }

  private static func loadFileRepresentation(
    from provider: NSItemProvider,
    typeIdentifier: String
  ) async -> URL? {
    await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { tempURL, _ in
        guard let tempURL else {
          continuation.resume(returning: nil)
          return
        }
        let dest = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension("pdf")
        do {
          if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
          }
          try FileManager.default.copyItem(at: tempURL, to: dest)
          continuation.resume(returning: dest)
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }
}
