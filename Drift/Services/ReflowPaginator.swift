import CoreGraphics
import UIKit

/// Paginates reflowed book text to fit the reader viewport using TextKit.
final class ReflowPaginator {
    private let storage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private var containers: [NSTextContainer] = []
    private var containerSize: CGSize = .zero
    private var nextCharacterIndex = 0
    private(set) var pageCount: Int = 0

    init() {
        storage.addLayoutManager(layoutManager)
    }

    func reset(text: String, size: CGSize) {
        while layoutManager.textContainers.count > 0 {
            layoutManager.removeTextContainer(at: 0)
        }
        containers.removeAll()
        pageCount = 0
        nextCharacterIndex = 0
        containerSize = ReaderTheme.contentSize(for: size)

        storage.setAttributedString(ReaderTheme.attributedString(for: text))
    }

    func paginate(text: String, size: CGSize) {
        reset(text: text, size: size)
        guard storage.length > 0 else { return }

        while nextCharacterIndex < storage.length {
            guard appendNextPage() else { break }
        }

        if pageCount == 0 {
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            pageCount = 1
        }
    }

    @discardableResult
    func appendNextPage() -> Bool {
        guard nextCharacterIndex < storage.length else { return false }

        let container = NSTextContainer(size: containerSize)
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let glyphRange = layoutManager.glyphRange(for: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        containers.append(container)
        pageCount += 1

        if charRange.length == 0 {
            nextCharacterIndex = storage.length
            return false
        }

        nextCharacterIndex = NSMaxRange(charRange)
        return true
    }

    var hasMorePages: Bool {
        nextCharacterIndex < storage.length
    }

    func text(forPage index: Int) -> NSAttributedString {
        guard index >= 0, index < containers.count else {
            return NSAttributedString(string: "")
        }
        let container = containers[index]
        let glyphRange = layoutManager.glyphRange(for: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        return storage.attributedSubstring(from: charRange)
    }
}
