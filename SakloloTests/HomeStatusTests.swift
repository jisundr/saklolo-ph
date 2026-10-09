import XCTest
@testable import Saklolo

@MainActor
final class HomeStatusTests: XCTestCase {
    private func status(
        model: ModelLoader.Phase = .ready,
        microphone: PermissionState = .on,
        location: PermissionState = .on,
        contacts: Int = 3,
        elapsed: TimeInterval = 0
    ) -> HomeStatus {
        HomeStatus(model: model, microphone: microphone, location: location, contacts: contacts, elapsed: elapsed)
    }

    private func readiness(_ items: [ReadinessItem]) -> [String] {
        items.map { "\($0.isOK ? "ok" : "off") \($0.label)" }
    }

    // E1
    func testEverythingWorkingIsReadyWithNoBannerAndFullRings() {
        let s = status()
        XCTAssertEqual(s.pill, .init(text: "Ready", systemImage: "checkmark", tone: .neutral))
        XCTAssertNil(s.banner)
        XCTAssertEqual(s.lead, "Press the red button.")
        XCTAssertEqual(readiness(s.readiness), ["ok Mic", "ok GPS", "ok 3 contacts ready"])
        XCTAssertFalse(s.ringsDimmed)
    }

    // E2
    func testPreparingTheModelShowsTheClockAndSaysSpeechIsNotUnderstoodYet() {
        let s = status(model: .compiling, elapsed: 102)
        XCTAssertEqual(s.pill, .init(text: "Preparing the listening model · 1:42", systemImage: "clock", tone: .neutral))
        XCTAssertNil(s.banner)
        XCTAssertEqual(s.lead, "Press the red button.\nThe phone can’t understand speech yet.")
        XCTAssertTrue(s.ringsDimmed)
    }

    func testDownloadingTheModelShowsThePercent() {
        let s = status(model: .downloading(0.34))
        XCTAssertEqual(s.pill.text, "Getting the listening model · 34%")
        XCTAssertNil(s.banner)
        XCTAssertTrue(s.ringsDimmed)
    }

    // E3
    func testAFailedModelOffersToTryAgain() {
        let s = status(model: .failed)
        XCTAssertEqual(s.pill, .init(text: "Can’t understand speech", systemImage: "xmark", tone: .fail))
        XCTAssertEqual(s.banner, .init(text: "Listening isn’t ready.", actionTitle: "Try again", fix: .retryModel))
        XCTAssertEqual(s.lead, "Press the red button.\nThe phone can’t understand speech yet.")
        XCTAssertTrue(s.ringsDimmed)
    }

    // E4
    func testMicrophoneOffSendsThePersonToSettings() {
        let s = status(microphone: .off)
        XCTAssertEqual(s.pill, .init(text: "Microphone off", systemImage: "xmark", tone: .fail))
        XCTAssertEqual(s.banner, .init(text: "Microphone is off.", actionTitle: "Open Settings", fix: .openSettings))
        XCTAssertEqual(s.lead, "Press the red button.\nThe phone can’t understand speech yet.")
        XCTAssertEqual(readiness(s.readiness), ["off Mic", "ok GPS", "ok 3 contacts ready"])
        XCTAssertTrue(s.ringsDimmed)
    }

    // E5
    func testLocationOffStillReadsReadyButDimsTheRings() {
        let s = status(location: .off)
        XCTAssertEqual(s.pill.text, "Ready")
        XCTAssertEqual(s.banner, .init(text: "Location is off.", actionTitle: "Open Settings", fix: .openSettings))
        XCTAssertEqual(s.lead, "Press the red button.")
        XCTAssertEqual(readiness(s.readiness), ["ok Mic", "off GPS", "ok 3 contacts ready"])
        XCTAssertTrue(s.ringsDimmed)
    }

    // E6
    func testNoContactsSaysNobodyWillBeAlerted() {
        let s = status(contacts: 0)
        XCTAssertEqual(s.pill.text, "Ready")
        XCTAssertEqual(s.banner, .init(text: "Add someone to alert.", actionTitle: "Add contact", fix: .addContact))
        XCTAssertEqual(s.lead, "Press the red button.\nNobody will be alerted yet.")
        XCTAssertEqual(readiness(s.readiness), ["ok Mic", "ok GPS", "off 0 contacts"])
        XCTAssertTrue(s.ringsDimmed)
    }

    func testOneContactIsSingular() {
        XCTAssertEqual(status(contacts: 1).readiness.last, ReadinessItem(label: "1 contact ready", isOK: true))
    }

    func testOnlyOneBannerShowsAndTheMostSevereWins() {
        let all = status(model: .failed, microphone: .off, location: .off, contacts: 0)
        XCTAssertEqual(all.banner?.fix, .addContact)
        XCTAssertEqual(status(model: .failed, microphone: .off, location: .off).banner?.text, "Microphone is off.")
        XCTAssertEqual(status(model: .failed, location: .off).banner?.text, "Listening isn’t ready.")
    }

    func testMicrophoneOffOutranksAFailedModelInThePill() {
        XCTAssertEqual(status(model: .failed, microphone: .off).pill.text, "Microphone off")
        XCTAssertEqual(status(model: .compiling, microphone: .off).pill.text, "Microphone off")
    }

    func testPermissionsNotAskedYetAreNotShownAsOff() {
        let s = status(microphone: .notAsked, location: .notAsked)
        XCTAssertNil(s.banner)
        XCTAssertTrue(s.readiness.allSatisfy(\.isOK))
    }
}
