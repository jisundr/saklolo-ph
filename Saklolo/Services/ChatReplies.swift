import Foundation

/// The chat's fixed, pre-written replies (F3, F5, F7, G1). The classifier
/// only picks the mode and script; these strings are chosen from that, so the
/// model never writes anything the person reads in the thread.
enum ChatReplies {
    /// First bubble, shown as the chat opens (F1).
    static let opening = "What happened?"

    /// Empty transcript or a transcription error (F5). Never a dead end:
    /// the session carries on with general help.
    static let couldNotUnderstand = "I couldn't understand that. I'm sending a general alert and starting general help."

    /// Alone mode's first reply (G1). Mockup wording (plan flag 7).
    static let aloneHere = "Stay still. I'm here."

    /// Alone mode's check-in while the dock decides (G1), with the dock's
    /// real countdown length.
    static var aloneCheckIn: String {
        let seconds = AloneModePolicy.countdown.components.seconds
        return "Are you okay? Slide if you're okay. If not, I'll tell your contacts in \(seconds) seconds, or tap I need help to do it now."
    }

    static let guideNext = "I'll guide you, one step at a time."

    /// Who and what happened, then what happens next. Alone mode checks in
    /// only while the dock is shown (`dockShown`); if the alert already went
    /// out before understanding finished there is no slide to offer, so it
    /// says the guide follows instead.
    static func replies(for classification: SituationClassification, dockShown: Bool) -> [String] {
        switch classification.mode {
        case .alone:
            [aloneHere, dockShown ? aloneCheckIn : guideNext]
        case .guide:
            ["Got it. " + situation(scriptID: classification.scriptID), guideNext]
        }
    }

    private static func situation(scriptID: String) -> String {
        switch scriptID {
        case "fall": "Someone with you has fallen."
        case "bleeding": "Someone with you is bleeding."
        case "unconscious": "Someone with you isn't responding."
        case "head_injury": "Someone with you has hit their head."
        default: "Someone with you needs help."
        }
    }
}
