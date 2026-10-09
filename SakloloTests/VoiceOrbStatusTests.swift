import XCTest
@testable import Saklolo

final class VoiceOrbStatusTests: XCTestCase {
    func testBeforeTheAlertAQuietMicAsksThePersonToSpeakLouder() {
        XCTAssertEqual(VoiceOrb.statusText(phase: .waiting, quietTooLong: true, alert: nil), "Can't hear you. Speak louder.")
        XCTAssertEqual(VoiceOrb.statusText(phase: .waiting, quietTooLong: false, alert: nil), "Listening...")
    }

    func testOnceTheAlertIsGoingOutTheOrbNeverSaysItCannotHear() {
        for alert in [VoiceOrb.AlertState.sending, .sent, .needsPerson] {
            for phase in [VoiceOrb.Phase.waiting, .hearing] {
                let text = VoiceOrb.statusText(phase: phase, quietTooLong: true, alert: alert)
                XCTAssertNotEqual(text, VoiceOrb.cantHearYou, "\(alert) \(phase)")
                XCTAssertTrue(text.hasSuffix("Keep talking if you can."), text)
            }
        }
    }

    func testTheOrbOnlySaysSentOnceTheAlertIsConfirmed() {
        XCTAssertTrue(VoiceOrb.statusText(phase: .waiting, quietTooLong: true, alert: .sent).hasPrefix("Alert sent."))
        XCTAssertFalse(VoiceOrb.statusText(phase: .waiting, quietTooLong: true, alert: .sending).contains("sent"))
        XCTAssertFalse(VoiceOrb.statusText(phase: .waiting, quietTooLong: true, alert: .needsPerson).contains("sent"))
    }

    func testTheAlertStateFollowsTheQueue() {
        XCTAssertEqual(VoiceOrb.AlertState(nil), .sending)
        XCTAssertEqual(VoiceOrb.AlertState(.confirming), .sending)
        XCTAssertEqual(VoiceOrb.AlertState(.waiting), .sending)
        XCTAssertEqual(VoiceOrb.AlertState(.sent(at: .now)), .sent)
        XCTAssertEqual(VoiceOrb.AlertState(.needsComposer), .needsPerson)
    }

    func testTranscribingStillSaysUnderstanding() {
        XCTAssertEqual(VoiceOrb.statusText(phase: .transcribing, quietTooLong: false, alert: .sent), "Understanding...")
    }
}
