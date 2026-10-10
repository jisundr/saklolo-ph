import XCTest
@testable import Saklolo

final class HomeMenuTests: XCTestCase {
    /// E7 lists its rows in the mockup's order, minus the rows whose work is deferred
    /// (quick trigger, test alert).
    func testMenuRowsFollowTheMockupOrder() {
        XCTAssertEqual(
            MenuChoice.allCases.map(\.title),
            ["Contacts", "Permissions", "Past incidents", "About and disclaimer"]
        )
    }
}
