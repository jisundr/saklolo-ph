import Foundation
import XCTest
@testable import Saklolo

final class ClassifierTimeoutTests: XCTestCase {
    private let modelAnswer = SituationClassification(mode: .alone, scriptID: "fall", summary: "From the model", urgency: "high")

    /// A model that answers after `delay` and never notices cancellation.
    private func stubbornModel(answeringAfter delay: TimeInterval) -> @Sendable (String) async -> SituationClassification? {
        let answer = modelAnswer
        return { _ in
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    continuation.resume(returning: answer)
                }
            }
        }
    }

    func testASlowModelThatIgnoresCancellationDoesNotHoldUpTheResult() async {
        var service = SituationClassifierService(keywords: KeywordDatabase(version: 1, entries: []))
        service.model = stubbornModel(answeringAfter: 3)

        let started = Date()
        let result = await service.classify(transcript: "Tulong, nahulog si Lola", timeout: .milliseconds(200))

        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
        XCTAssertEqual(result.summary, "Tulong, nahulog si Lola", "keyword result, not the model's")
    }

    func testAModelThatAnswersInTimeIsUsed() async {
        var service = SituationClassifierService(keywords: KeywordDatabase(version: 1, entries: []))
        service.model = stubbornModel(answeringAfter: 0.05)

        let result = await service.classify(transcript: "Tulong, nahulog si Lola", timeout: .seconds(2))

        XCTAssertEqual(result.summary, "From the model")
        XCTAssertEqual(result.mode, .alone)
    }

    func testFirstResultGivesUpAtTheDeadlineEvenIfTheWorkNeverStops() async {
        let started = Date()
        let value: Int? = await firstResult(within: .milliseconds(100)) {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) { continuation.resume(returning: 1) }
            }
        }
        XCTAssertNil(value)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
    }
}
