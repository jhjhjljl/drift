import XCTest
@testable import Drift

final class TextNormalizerTests: XCTestCase {
    func testJoinsLinesWithinParagraph() {
        let raw = "She saved half of it for the\nnext day."
        let result = TextNormalizer.reflowableText(from: raw)
        XCTAssertEqual(result, "She saved half of it for the next day.")
    }

    func testBlankLineCreatesParagraphBreak() {
        let raw = "First paragraph.\n\nSecond paragraph."
        let result = TextNormalizer.reflowableText(from: raw)
        XCTAssertEqual(result, "First paragraph.\n\nSecond paragraph.")
    }
}
