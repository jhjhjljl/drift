import SwiftUI

/// Single fixed preset (v1: no user settings). System background + label; Georgia body.
enum ReaderTheme {
    /// Bump when typography, normalizer, or paginator changes to invalidate pagination caches.
    static let layoutVersion = 3

    static let background = Color(uiColor: .systemBackground)
    static let text = Color(uiColor: .label)
    static let uiBackground = UIColor.systemBackground
    static let uiText = UIColor.label

    static let bodyFontSize: CGFloat = 22
    static let font = Font.custom("Georgia", size: bodyFontSize)
    static let lineSpacing: CGFloat = 9
    static let horizontalPadding: CGFloat = 28
    static let verticalPadding: CGFloat = 44

    static func contentSize(for viewport: CGSize) -> CGSize {
        CGSize(
            width: max(viewport.width - horizontalPadding * 2, 1),
            height: max(viewport.height - verticalPadding * 2, 1)
        )
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = lineSpacing * 1.5
        style.alignment = .natural
        style.lineBreakMode = .byWordWrapping
        style.hyphenationFactor = 0.9
        return style
    }

    static func attributedString(for text: String) -> NSAttributedString {
        let paragraph = paragraphStyle
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont(name: "Georgia", size: bodyFontSize) ?? .systemFont(ofSize: bodyFontSize),
                .foregroundColor: uiText,
                .paragraphStyle: paragraph,
            ]
        )
    }
}
