import SwiftUI
import UIKit

struct ReflowTextPage: View {
    let text: NSAttributedString
    let contentSize: CGSize

    var body: some View {
        WrappingLabel(attributedText: text, contentSize: contentSize)
            .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
            .clipped()
    }
}

/// UILabel wraps reliably at a fixed width — UITextView was expanding past the screen.
private struct WrappingLabel: UIViewRepresentable {
    let attributedText: NSAttributedString
    let contentSize: CGSize

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.clipsToBounds = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.preferredMaxLayoutWidth = contentSize.width
        label.attributedText = attributedText
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        contentSize
    }
}
