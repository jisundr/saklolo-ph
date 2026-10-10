import XCTest
@testable import Saklolo

final class TranscriptFilterTests: XCTestCase {
    func testSilenceAndWhisperMarkersCountAsNothingHeard() {
        for raw in ["...", "…", "[BLANK_AUDIO]", "(silence)", "  ", "", "?!", " … [BLANK_AUDIO] (music) ", "<|endoftext|>"] {
            XCTAssertEqual(SpeechTranscriptionService.speech(in: raw), "", raw.debugDescription)
        }
    }

    func testRealWordsAreKept() {
        XCTAssertEqual(SpeechTranscriptionService.speech(in: "Tulong"), "Tulong")
        XCTAssertEqual(SpeechTranscriptionService.speech(in: "911"), "911")
        XCTAssertEqual(SpeechTranscriptionService.speech(in: " Help! "), "Help!")
    }

    func testMarkersAroundSpeechAreDropped() {
        XCTAssertEqual(SpeechTranscriptionService.speech(in: "[BLANK_AUDIO] Nahulog si Lola (crying)"), "Nahulog si Lola")
    }
}

final class EndOfSpeechTests: XCTestCase {
    private let start = ContinuousClock.now
    private let quiet: Float = -60
    private let loud: Float = -10

    func testDoneStopsTheRecordingAtOnce() {
        var endpoint = EndOfSpeech(startedAt: start)
        XCTAssertEqual(endpoint.update(power: loud, at: start + .milliseconds(100)), .speechStarted)
        XCTAssertEqual(endpoint.update(power: loud, at: start + .seconds(2), stopRequested: true), .stop)
    }

    func testDoneStopsEvenBeforeAnythingIsHeard() {
        var endpoint = EndOfSpeech(startedAt: start)
        XCTAssertEqual(endpoint.update(power: quiet, at: start + .milliseconds(100), stopRequested: true), .stop)
    }

    func testRecordingStopsAfterTheSpeakerGoesQuiet() {
        var endpoint = EndOfSpeech(startedAt: start)
        _ = endpoint.update(power: loud, at: start + .seconds(1))
        XCTAssertEqual(endpoint.update(power: quiet, at: start + .seconds(2)), .keepRecording)
        XCTAssertEqual(endpoint.update(power: quiet, at: start + .milliseconds(3000)), .keepRecording)
        XCTAssertEqual(endpoint.update(power: quiet, at: start + .milliseconds(3500)), .stop)
    }

    func testRecordingGivesUpAfterEightQuietSeconds() {
        var endpoint = EndOfSpeech(startedAt: start)
        XCTAssertEqual(endpoint.update(power: quiet, at: start + .seconds(7)), .keepRecording)
        XCTAssertEqual(endpoint.update(power: quiet, at: start + .seconds(8)), .stop)
    }
}
