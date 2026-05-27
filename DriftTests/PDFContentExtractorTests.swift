import XCTest
@testable import Drift

final class PDFContentExtractorTests: XCTestCase {
    func testReflowSegmentJoinsAcrossPDFPagesWithoutParagraphBreak() {
        let page1 = "She could save half of it for the next"
        let page2 = "day or for a snack later that night."
        let text = PDFContentExtractor.reflowSegmentText(joiningRawPages: [page1, page2])
        XCTAssertTrue(text.contains("the next day"))
        XCTAssertFalse(text.contains("the next\n\nday"))
    }

    func testReflowSegmentPreservesSourceBlankLineBetweenPages() {
        let page1 = "End of chapter.\n"
        let page2 = "\nStart of next chapter."
        let text = PDFContentExtractor.reflowSegmentText(joiningRawPages: [page1, page2])
        XCTAssertTrue(text.contains("End of chapter.\n\nStart of next chapter."))
    }
}
