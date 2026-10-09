import Foundation

/// What Home says about the phone right now (mockup E1 to E6). Pure, so the precedence and the
/// copy can be tested without a screen.
///
/// The red button always works; this only tells the person what will and won't happen.
struct HomeStatus: Equatable {
    struct Pill: Equatable {
        let text: String
        let systemImage: String
        let tone: StatusPill.Tone
    }

    /// The fix a banner's link leads to.
    enum Fix: Equatable {
        /// Start loading the listening model again.
        case retryModel
        /// The app's page in the Settings app.
        case openSettings
        /// The contacts step of setup.
        case addContact
    }

    struct Banner: Equatable {
        let text: String
        let actionTitle: String
        let fix: Fix
    }

    let pill: Pill
    /// At most one, the most severe.
    let banner: Banner?
    /// The line under the red button.
    let lead: String
    let readiness: [ReadinessItem]
    /// The rings fade whenever anything is short (plan flag 5). The red core never does.
    let ringsDimmed: Bool

    /// `elapsed` is how long the model has been loading, for the pill's clock.
    init(
        model: ModelLoader.Phase,
        microphone: PermissionState,
        location: PermissionState,
        contacts: Int,
        elapsed: TimeInterval = 0
    ) {
        let micOff = microphone == .off
        let locationOff = location == .off
        let noContacts = contacts <= 0

        pill = Self.pill(model: model, micOff: micOff, elapsed: elapsed)
        banner = Self.banner(model: model, micOff: micOff, locationOff: locationOff, noContacts: noContacts)

        let canTakeSpeech = !micOff && model == .ready
        if noContacts {
            lead = "Press the red button.\nNobody will be alerted yet."
        } else if !canTakeSpeech {
            lead = "Press the red button.\nThe phone can\u{2019}t understand speech yet."
        } else {
            // Plan flag 3: the Lock Screen control does not exist yet, so it is not mentioned.
            lead = "Press the red button."
        }

        readiness = [
            ReadinessItem(label: "Mic", isOK: !micOff),
            ReadinessItem(label: "GPS", isOK: !locationOff),
            ReadinessItem(label: Self.contactsLabel(contacts), isOK: !noContacts),
        ]

        ringsDimmed = banner != nil || model != .ready
    }

    private static func pill(model: ModelLoader.Phase, micOff: Bool, elapsed: TimeInterval) -> Pill {
        if micOff {
            return Pill(text: "Microphone off", systemImage: "xmark", tone: .fail)
        }
        switch model {
        case .failed:
            return Pill(text: "Can\u{2019}t understand speech", systemImage: "xmark", tone: .fail)
        case .ready:
            return Pill(text: "Ready", systemImage: "checkmark", tone: .neutral)
        case .compiling, .testing, .downloading:
            // Plan flags 2 and 4: the full model wording, with a clock or a percent.
            let text = ModelStateText.text(for: model, elapsed: elapsed, compact: false) ?? ""
            return Pill(text: text, systemImage: "clock", tone: .neutral)
        }
    }

    /// Most severe first: no contacts, microphone off, model failed, location off.
    private static func banner(model: ModelLoader.Phase, micOff: Bool, locationOff: Bool, noContacts: Bool) -> Banner? {
        if noContacts {
            return Banner(text: "Add someone to alert.", actionTitle: "Add contact", fix: .addContact)
        }
        if micOff {
            return Banner(text: "Microphone is off.", actionTitle: "Open Settings", fix: .openSettings)
        }
        if model == .failed {
            return Banner(text: "Listening isn\u{2019}t ready.", actionTitle: "Try again", fix: .retryModel)
        }
        if locationOff {
            return Banner(text: "Location is off.", actionTitle: "Open Settings", fix: .openSettings)
        }
        return nil
    }

    private static func contactsLabel(_ count: Int) -> String {
        switch count {
        case ..<1: "0 contacts"
        case 1: "1 contact ready"
        default: "\(count) contacts ready"
        }
    }
}
