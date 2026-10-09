import Foundation

/// The chat's fixed, pre-written replies (F3, F5, F7). The classifier only
/// picks the mode and script; these strings are chosen from that, so the
/// model never writes anything the person reads in the thread.
enum ChatReplies {
    /// First bubble, shown as the chat opens (F1).
    static let opening = "What happened?"

    /// Empty transcript or a transcription error (F5). Never a dead end:
    /// the session carries on with general help.
    static let couldNotUnderstand = "I couldn't understand that. I'm starting general help."

    /// Who and what happened, then what happens next for the mode.
    static func replies(for classification: SituationClassification) -> [String] {
        let alone = classification.mode == .alone
        return [
            "Got it. " + situation(scriptID: classification.scriptID, alone: alone),
            alone
                ? "Stay with me. I'll help you, one step at a time."
                : "I'll guide you, one step at a time.",
        ]
    }

    private static func situation(scriptID: String, alone: Bool) -> String {
        switch scriptID {
        case "fall": alone ? "You've fallen." : "Someone with you has fallen."
        case "bleeding": alone ? "You're bleeding." : "Someone with you is bleeding."
        case "unconscious": alone ? "You feel like you may pass out." : "Someone with you isn't responding."
        case "head_injury": alone ? "You've hit your head." : "Someone with you has hit their head."
        default: alone ? "You need help." : "Someone with you needs help."
        }
    }
}
