import XCTest
@testable import Saklolo

@MainActor
final class SpokenTextTests: XCTestCase {
    func testPunctuationAndSpaceAloneAreNothingSaid() {
        for text in ["", "...", "  ", "—", "?!", " . \n"] {
            XCTAssertFalse(SpokenText.hasWords(text), "\(text.debugDescription) should count as nothing said")
        }
    }

    func testWordsAndNumbersAreSomethingSaid() {
        for text in ["Tulong", "911", "...tulong!", "Ñ", "a"] {
            XCTAssertTrue(SpokenText.hasWords(text), "\(text.debugDescription) should count as something said")
        }
    }

    func testAPunctuationOnlySummaryReadsNoSummary() {
        let incident = Incident(trigger: "button", mode: .guide, summary: "...")
        XCTAssertEqual(IncidentText.summary(incident), "No summary")
    }

    func testARealSummaryIsShownAsIs() {
        let incident = Incident(trigger: "button", mode: .guide, summary: "Papa fell, his head is bleeding")
        XCTAssertEqual(IncidentText.summary(incident), "Papa fell, his head is bleeding")
    }
}
