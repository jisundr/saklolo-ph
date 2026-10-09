import XCTest
@testable import Saklolo

final class SessionExitTests: XCTestCase {
    func testWhileListeningCancelSavesAndSendsNothing() {
        let exit = SessionExit.header(incidentSaved: false, awaitingPerson: false, alertFired: false)

        XCTAssertEqual(exit, .cancel(keepsIncident: false))
        XCTAssertTrue(exit.hint.contains("Nothing is saved or sent"))
    }

    func testCancelAfterTheDeadlineAlertKeepsTheIncident() {
        let exit = SessionExit.header(incidentSaved: false, awaitingPerson: false, alertFired: true)

        XCTAssertEqual(exit, .cancel(keepsIncident: true))
        XCTAssertFalse(exit.hint.contains("Nothing is saved or sent"))
    }

    func testOnceUnderstoodTheHeaderSaysDone() {
        XCTAssertEqual(SessionExit.header(incidentSaved: true, awaitingPerson: false, alertFired: true), .done)
        // Guide mode: the incident is in, the send has not started yet.
        XCTAssertEqual(SessionExit.header(incidentSaved: true, awaitingPerson: false, alertFired: false), .done)
    }

    func testAloneModeDockHidesDoneAndCancelSendsNothing() {
        let exit = SessionExit.header(incidentSaved: true, awaitingPerson: true, alertFired: false)

        XCTAssertEqual(exit, .cancel(keepsIncident: false))
    }

    func testAfterTheDockFiresTheHeaderSaysDoneAgain() {
        XCTAssertEqual(SessionExit.header(incidentSaved: true, awaitingPerson: false, alertFired: true), .done)
    }
}
