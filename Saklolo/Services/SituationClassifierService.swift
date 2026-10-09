import Foundation

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

    /// TODO: on-device LLM path. Must race against / time out before the
    /// keyword fallback would otherwise be used, never add latency to the
    /// alert path.
    func classifyWithLLM(transcript: String) async throws -> SituationClassification {
        throw CocoaError(.featureUnsupported)
    }
}
