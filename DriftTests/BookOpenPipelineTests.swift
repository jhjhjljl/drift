import XCTest
@testable import Drift

final class BookOpenPipelineTests: XCTestCase {
    func testCompletionPageIndexUsesOpenTargetWhenStillAtZero() {
        XCTAssertEqual(
            BookOpenPipeline.completionPageIndex(virtualIndex: 0, openTargetIndex: 42),
            42
        )
    }

    func testCompletionPageIndexKeepsUserNavigationDuringLoad() {
        XCTAssertEqual(
            BookOpenPipeline.completionPageIndex(virtualIndex: 7, openTargetIndex: 42),
            7
        )
    }

    func testCompletionPageIndexWhenAlreadyAtTarget() {
        XCTAssertEqual(
            BookOpenPipeline.completionPageIndex(virtualIndex: 42, openTargetIndex: 42),
            42
        )
    }

    func testCompletionPageIndexAtBeginning() {
        XCTAssertEqual(
            BookOpenPipeline.completionPageIndex(virtualIndex: 0, openTargetIndex: 0),
            0
        )
    }
}
