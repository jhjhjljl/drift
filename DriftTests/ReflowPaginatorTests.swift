import CoreGraphics
import XCTest
@testable import Drift

final class ReflowPaginatorTests: XCTestCase {
    func testPaginatesLongTextIntoMultiplePages() {
        let paragraph = String(repeating: "word ", count: 400)
        let viewport = CGSize(width: 390, height: 844)

        let paginator = ReflowPaginator()
        paginator.reset(text: paragraph, size: viewport)

        var pages = 0
        repeat {
            if pages > 0, !paginator.appendNextPage() { break }
            else if pages == 0 { _ = paginator.appendNextPage() }
            guard paginator.pageCount > pages else { break }
            pages += 1
        } while paginator.hasMorePages

        XCTAssertGreaterThan(pages, 1)
    }

    func testFirstPageIsNonEmpty() {
        let paginator = ReflowPaginator()
        paginator.reset(text: "Hello, reader.", size: CGSize(width: 390, height: 844))
        _ = paginator.appendNextPage()
        XCTAssertGreaterThan(paginator.text(forPage: 0).length, 0)
    }
}
