import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

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
    /// Keyword → script lookup, loaded from the bundled `keywords.json`.
    var keywords: KeywordDatabase = .bundled()

    func classifyByKeyword(transcript: String) -> SituationClassification {
        let mode: IncidentMode = transcript.lowercased().contains(" ako") ? .alone : .guide
        if let scriptID = keywords.match(transcript) {
            return SituationClassification(mode: mode, scriptID: scriptID, summary: transcript, urgency: "high")
        }
        return SituationClassification(mode: mode, scriptID: "general", summary: transcript, urgency: "unknown")
    }

    /// Runs the on-device LLM when this OS has it; nil otherwise (iOS < 26,
    /// no Apple Intelligence, guardrail block, or any other error).
    private func llmClassification(transcript: String) async -> SituationClassification? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return try? await classifyWithLLM(transcript: transcript)
        }
        #endif
        return nil
    }

    /// Entry point for the alert flow. The keyword result is always computed
    /// first and is what we return if the LLM is slow, blocked by the safety
    /// guardrail, or unavailable — the LLM can refine the result but never
    /// delay or replace it with nothing.
    func classify(transcript: String, timeout: Duration = .seconds(3)) async -> SituationClassification {
        let keyword = classifyByKeyword(transcript: transcript)
        let llm: SituationClassification? = await withTaskGroup(of: SituationClassification?.self) { group in
            group.addTask { await llmClassification(transcript: transcript) }
            group.addTask { try? await Task.sleep(for: timeout); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard var result = llm else { return keyword }
        // The model sometimes answers "general" for an utterance the keywords
        // recognise (e.g. "dumudugo"); a specific script is the safer pick.
        if result.scriptID == "general", keyword.scriptID != "general" {
            result.scriptID = keyword.scriptID
        }
        return result
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension SituationClassifierService {
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

    static let instructions = """
        You classify emergency utterances (Taglish/Filipino/English) into fixed categories. \
        You never give medical advice. Only choose from the allowed values.
        mode: "alone" if the speaker is the one hurt ("ako", "ko", "sa akin"); "guide" if they are \
        helping someone else (Lola, anak, kapatid, Tatay, friend, kapitbahay).
        script: fall = fell/slipped (nahulog, nadulas, bumagsak); bleeding = visible blood or cut \
        (dumudugo, dugo, naputol, sugat); unconscious = not responding or not breathing (walang malay, \
        hindi gumigising, nawalan ng malay); head_injury = hit or bumped head (nauntog, nabagok, tumama \
        ang ulo), even with vomiting or dizziness; general = anything else.
        Examples:
        "Nahulog si Lola sa hagdan" -> guide, fall
        "may dumudugo sa braso ko" -> alone, bleeding
        "walang malay yung kapatid ko" -> guide, unconscious
        "Nauntog yung anak ko, nagsusuka" -> guide, head_injury
        "Nabagok ulo ko, nahihilo ako" -> alone, head_injury
        "Naputol daliri ko sa kutsilyo" -> alone, bleeding
        "may sunog sa kapitbahay" -> guide, general
        """

    func classifyWithLLM(transcript: String) async throws -> SituationClassification {
        // Permissive guardrails: the default ones reject injury text ("nagsusuka",
        // "dugo") as unsafe, which would block exactly the emergencies we serve.
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        guard case .available = model.availability else {
            throw CocoaError(.featureUnsupported)
        }
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
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
#endif
