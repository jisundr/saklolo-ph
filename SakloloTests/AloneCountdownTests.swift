import XCTest
@testable import Saklolo

@MainActor
final class AloneCountdownTests: XCTestCase {
    private var clock: TestClock!
    private var countdown: AloneCountdown<TestClock>!

    override func setUp() async throws {
        clock = TestClock()
        countdown = AloneCountdown(clock: clock)
    }

    override func tearDown() async throws {
        countdown.stop()
        clock.advance(by: .seconds(60))
    }

    /// Lets the countdown's task run after the clock moves.
    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    // MARK: - Fires on its own

    func testTheCountdownIsTenSeconds() {
        XCTAssertEqual(AloneModePolicy.countdown, .seconds(10))
        XCTAssertEqual(countdown.total, .seconds(10))
        XCTAssertEqual(countdown.remaining, .seconds(10))
    }

    func testNothingFiresBeforeTheCountdownEnds() async {
        countdown.start { XCTFail("fired early") }

        clock.advance(by: .seconds(10) - .milliseconds(1))
        await settle()

        XCTAssertEqual(countdown.state, .running)
    }

    func testItFiresOnItsOwnWhenTheCountdownEnds() async {
        let fired = expectation(description: "fired")
        countdown.start { fired.fulfill() }

        clock.advance(by: .seconds(10))
        await fulfillment(of: [fired], timeout: 2)

        XCTAssertEqual(countdown.state, .fired)
        XCTAssertEqual(countdown.remaining, .zero)
    }

    func testItFiresOnceEvenWhenTimeKeepsGoing() async {
        var count = 0
        let fired = expectation(description: "fired")
        countdown.start {
            count += 1
            fired.fulfill()
        }

        clock.advance(by: .seconds(10))
        await fulfillment(of: [fired], timeout: 2)
        clock.advance(by: .seconds(30))
        await settle()
        countdown.fireNow()

        XCTAssertEqual(count, 1)
    }

    func testTheBarCountsDownASecondAtATime() async {
        countdown.start {}

        clock.advance(by: .seconds(3))
        await settle()

        XCTAssertEqual(countdown.remaining, .seconds(7))
        XCTAssertEqual(AloneModePolicy.clockText(countdown.remaining), "0:07")
        XCTAssertEqual(countdown.fractionLeft, 0.7, accuracy: 0.0001)
    }

    // MARK: - Tapped

    func testTappingTheBarFiresAtOnce() {
        var count = 0
        countdown.start { count += 1 }

        countdown.fireNow()

        XCTAssertEqual(count, 1)
        XCTAssertEqual(countdown.state, .fired)
    }

    func testTappingTwiceFiresOnce() async {
        var count = 0
        countdown.start { count += 1 }

        countdown.fireNow()
        countdown.fireNow()
        clock.advance(by: .seconds(10))
        await settle()

        XCTAssertEqual(count, 1)
    }

    func testTappingBeforeStartDoesNothing() {
        countdown.fireNow()

        XCTAssertEqual(countdown.state, .idle)
    }

    // MARK: - I'm okay

    func testOkayBeforeTheEndMeansNothingIsEverFired() async {
        countdown.start { XCTFail("fired after okay") }
        clock.advance(by: .seconds(9))
        await settle()

        let stopped = countdown.okay()
        clock.advance(by: .seconds(30))
        await settle()
        countdown.fireNow()

        XCTAssertTrue(stopped)
        XCTAssertEqual(countdown.state, .okay)
    }

    func testOkayAfterFiringIsTooLate() {
        countdown.start {}
        countdown.fireNow()

        XCTAssertFalse(countdown.okay())
        XCTAssertEqual(countdown.state, .fired)
    }

    func testStoppingWhenTheDockGoesAwayFiresNothing() async {
        countdown.start { XCTFail("fired after stop") }

        countdown.stop()
        clock.advance(by: .seconds(30))
        await settle()

        XCTAssertEqual(countdown.state, .stopped)
    }

    // MARK: - Slide and label rules

    func testASlideCountsOnlyNearTheEndOfTheTrack() {
        XCTAssertFalse(AloneModePolicy.slideCompletes(fraction: AloneModePolicy.slideFraction(translation: 40, travel: 200)))
        XCTAssertFalse(AloneModePolicy.slideCompletes(fraction: AloneModePolicy.slideFraction(translation: 160, travel: 200)))
        XCTAssertTrue(AloneModePolicy.slideCompletes(fraction: AloneModePolicy.slideFraction(translation: 180, travel: 200)))
        XCTAssertTrue(AloneModePolicy.slideCompletes(fraction: AloneModePolicy.slideFraction(translation: 500, travel: 200)))
    }

    func testABackwardsDragOrNoTrackNeverCounts() {
        XCTAssertEqual(AloneModePolicy.slideFraction(translation: -50, travel: 200), 0)
        XCTAssertEqual(AloneModePolicy.slideFraction(translation: 50, travel: 0), 0)
    }

    func testTheClockReadsWholeSecondsRoundedUp() {
        XCTAssertEqual(AloneModePolicy.clockText(.seconds(10)), "0:10")
        XCTAssertEqual(AloneModePolicy.clockText(.milliseconds(200)), "0:01")
        XCTAssertEqual(AloneModePolicy.clockText(.zero), "0:00")
        XCTAssertEqual(AloneModePolicy.clockText(.seconds(75)), "1:15")
    }
}
