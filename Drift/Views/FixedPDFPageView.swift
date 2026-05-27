import PDFKit
import SwiftUI

struct FixedPDFPageView: View {
    let page: PDFPage?

    var body: some View {
        Group {
            if let page {
                SinglePDFPageView(page: page)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SinglePDFPageView: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = ReaderTheme.uiBackground
        view.pageBreakMargins = .zero
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        let document = PDFDocument()
        document.insert(page, at: 0)
        pdfView.document = document
        pdfView.go(to: page)
    }
}
