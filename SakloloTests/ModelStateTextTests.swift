import XCTest
@testable import Saklolo

@MainActor
final class ModelStateTextTests: XCTestCase {
    func testNothingIsShownOnceTheModelIsReady() {
        XCTAssertNil(ModelStateText.text(for: .ready, elapsed: 90, compact: true))
        XCTAssertNil(ModelStateText.text(for: .ready, elapsed: 90, compact: false))
    }

    func testPreparingShowsHowLongItHasBeenRunning() {
        XCTAssertEqual(ModelStateText.text(for: .compiling, elapsed: 72, compact: true), "Preparing listening… 1:12")
        XCTAssertEqual(ModelStateText.text(for: .compiling, elapsed: 102, compact: false), "Preparing the listening model · 1:42")
        XCTAssertEqual(ModelStateText.text(for: .testing, elapsed: 5.9, compact: false), "Preparing the listening model · 0:05")
    }

    func testDownloadingShowsTheWholePercentFetched() {
        XCTAssertEqual(ModelStateText.text(for: .downloading(0.349), elapsed: 10, compact: false), "Getting the listening model · 34%")
        XCTAssertEqual(ModelStateText.text(for: .downloading(1), elapsed: 10, compact: true), "Getting listening… 100%")
    }

    func testAFailedModelStillSaysSomething() {
        XCTAssertNotNil(ModelStateText.text(for: .failed, elapsed: 0, compact: true))
        XCTAssertNotNil(ModelStateText.text(for: .failed, elapsed: 0, compact: false))
    }

    func testTheClockNeverGoesNegativeAndPadsSeconds() {
        XCTAssertEqual(ModelStateText.clockText(-3), "0:00")
        XCTAssertEqual(ModelStateText.clockText(9), "0:09")
        XCTAssertEqual(ModelStateText.clockText(610), "10:10")
    }
}
