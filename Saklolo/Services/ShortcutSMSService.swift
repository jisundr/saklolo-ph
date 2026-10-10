import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Sends the emergency SMS via a Shortcut (silent send) and places the call
/// to contact #1, per the brief's Core flow step 5.
///
/// Requires a Shortcut named "Saklolo" to exist on the device with a "Send
/// Message" action with "Show When Run" off — this app can only deep-link
/// into it, Shortcuts itself isn't scriptable from inside the app sandbox.
/// That Shortcut is out-of-band setup, not something this code creates.
struct ShortcutSMSService {
    enum SendError: Error {
        case invalidURL
        case cannotOpenURL
    }

    /// Opens the "Saklolo" Shortcut with the message text as input, through
    /// x-callback-url so Shortcuts can report back (`AlertCallback`).
    /// Returning without throwing does NOT mean the text went out: it only
    /// means Shortcuts is being opened. The confirmation, if any, arrives
    /// later as a `saklolo://` URL. `notOpened` runs if iOS reports that
    /// Shortcuts could not be opened after all.
    /// Fallback per the brief's Risks table: MFMessageComposeViewController
    /// (one tap) if the silent Shortcut send doesn't work on a given device.
    @MainActor
    func sendViaShortcut(message: String, id: UUID, notOpened: @escaping @MainActor () -> Void) throws {
        guard let url = AlertCallback.shortcutURL(message: message, id: id) else {
            throw SendError.invalidURL
        }
        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(url) else { throw SendError.cannotOpenURL }
        UIApplication.shared.open(url) { opened in
            if !opened { MainActor.assumeIsolated { notOpened() } }
        }
        #endif
    }

    /// `tel://` call to contact #1 — one confirm tap, per the brief's stack table.
    @MainActor
    func call(phone: String) throws {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { throw SendError.invalidURL }
        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(url) else { throw SendError.cannotOpenURL }
        UIApplication.shared.open(url)
        #endif
    }

    /// Builds the SMS body per the brief's example, naming who needs help:
    /// "SAKLOLO: Jayson needs help. Papa fell, his head is bleeding. 7:42 PM. Location: maps.apple.com/?ll=..."
    ///
    /// `summary` nil or blank means nothing was understood: "Jayson needs
    /// help. Could not say what happened." `name` is the one entered in
    /// setup; with none stored the text keeps the first-person wording
    /// ("I need help. I could not say what happened.").
    ///
    /// `locationNote` says plainly when the location is not live (I4):
    /// "Last known location (7:31 PM)" replaces "Location" before the link,
    /// and with no coordinates at all the note is sent on its own
    /// ("Location unavailable").
    func buildMessage(
        summary: String?,
        name: String? = nil,
        timestamp: Date,
        lat: Double?,
        lng: Double?,
        locationNote: String? = nil
    ) -> String {
        let time = timestamp.formatted(date: .omitted, time: .shortened)
        let what = Self.sentence(summary)
        let body = switch (Self.sentence(name), what) {
        case let (who?, what?): "\(who) needs help. \(what)"
        case let (who?, nil): "\(who) needs help. \(AlertPolicy.generalSummaryNamed)"
        case let (nil, what?): what
        case (nil, nil): AlertPolicy.generalSummary
        }
        var message = "SAKLOLO: \(body). \(time)."
        if let lat, let lng {
            message += " \(locationNote ?? "Location"): maps.apple.com/?ll=\(lat),\(lng)"
        } else if let locationNote {
            message += " \(locationNote)."
        }
        return message
    }

    /// Trimmed, without a trailing full stop (the text adds its own); nil
    /// when nothing is left.
    private static func sentence(_ text: String?) -> String? {
        var trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        while trimmed.hasSuffix(".") { trimmed.removeLast() }
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
