import Foundation
import FoundationModels

/// Classification result. The LLM only ever fills these fields from fixed
/// choices — it never generates first-aid instructions itself (safety rule
/// in the brief).
struct SituationClassification {
    var mode: IncidentMode
    var scriptID: String
    var summary: String
    var urgency: String
}

/// Works out mode/script/summary from a transcript, two ways:
/// 1. On-device LLM (Apple Foundation Models on Apple Intelligence devices,
///    else Gemma/Qwen via MLX Swift) — returns JSON per the brief step 4.
/// 2. Keyword fallback — must never block the SMS, so this is also the
///    result when the LLM is slow/unavailable, not just when it errors.
///
/// Placeholder: ships the keyword fallback first (fast to build, no model
/// dependency), LLM path is the 11pm-1am block per the build timeline.
struct SituationClassifierService {
    /// Keyword → script ID, straight from the brief's "First-aid scripts" table.
    private static let keywordMap: [(keywords: [String], scriptID: String)] = [
        (["nahulog", "nadulas", "di makagalaw", "hindi makagalaw"], "fall"),
        (["dumudugo", "sugat", "maraming dugo"], "bleeding"),
        (["walang malay", "di gumigising", "hindi gumigising"], "unconscious"),
        (["tumama ang ulo", "nauntog"], "head_injury"),
    ]

    func classifyByKeyword(transcript: String) -> SituationClassification {
        let lowered = transcript.lowercased()
        let mode: IncidentMode = lowered.contains(" ako") ? .alone : .guide

        for entry in Self.keywordMap {
            if entry.keywords.contains(where: { lowered.contains($0) }) {
                return SituationClassification(mode: mode, scriptID: entry.scriptID, summary: transcript, urgency: "high")
            }
        }
        return SituationClassification(mode: mode, scriptID: "general", summary: transcript, urgency: "unknown")
    }

    /// Spike: Apple Foundation Models path. The model only picks from fixed
    /// choices (mode/script/urgency) and writes a short summary.
    @Generable
    struct LLMOutput {
        @Guide(description: "alone if the speaker is the one hurt/by themselves, guide if they are helping someone else", .anyOf(["alone", "guide"]))
        var mode: String
        @Guide(description: "Best matching script ID", .anyOf(["fall", "bleeding", "unconscious", "head_injury", "general"]))
        var scriptID: String
        @Guide(description: "One short English sentence describing the situation")
        var summary: String
        @Guide(description: "Urgency level", .anyOf(["high", "medium", "low"]))
        var urgency: String
    }

    func classifyWithLLM(transcript: String) async throws -> SituationClassification {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw CocoaError(.featureUnsupported)
        }
        let session = LanguageModelSession(model: model, instructions: """
            You classify emergency utterances (Taglish/Filipino/English) into fixed categories. \
            You never give medical advice. Only choose from the allowed values.
            """)
        let response = try await session.respond(to: transcript, generating: LLMOutput.self)
        let out = response.content
        return SituationClassification(
            mode: IncidentMode(rawValue: out.mode) ?? .guide,
            scriptID: out.scriptID,
            summary: out.summary,
            urgency: out.urgency
        )
    }
}
