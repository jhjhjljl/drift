import XCTest
@testable import Drift

final class ReaderPositionLabelTests: XCTestCase {
    func testIncompleteShowsCurrentOnly() {
        XCTAssertEqual(
            ReaderPositionLabel.text(currentIndex: 41, totalScreens: 200, isComplete: false),
            "42"
        )
    }

    func testCompleteShowsCurrentAndTotal() {
        XCTAssertEqual(
            ReaderPositionLabel.text(currentIndex: 41, totalScreens: 1204, isComplete: true),
            "42 / 1204"
        )
    }

    func testFirstScreen() {
        XCTAssertEqual(
            ReaderPositionLabel.text(currentIndex: 0, totalScreens: 1, isComplete: true),
            "1 / 1"
        )
    }

    func testInvalidIndexReturnsNil() {
        XCTAssertNil(ReaderPositionLabel.text(currentIndex: -1, totalScreens: 10, isComplete: true))
        XCTAssertNil(ReaderPositionLabel.text(currentIndex: 10, totalScreens: 10, isComplete: true))
        XCTAssertNil(ReaderPositionLabel.text(currentIndex: 0, totalScreens: 0, isComplete: false))
    }
}
