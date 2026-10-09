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

    /// Builds the SMS body per the brief's example:
    /// "SAKLOLO: Papa fell, his head is bleeding, he is awake. 7:42pm. Location: maps.apple.com/?ll=..."
    ///
    /// `locationNote` says plainly when the location is not live (I4):
    /// "Last known location (7:31 PM)" replaces "Location" before the link,
    /// and with no coordinates at all the note is sent on its own
    /// ("Location unavailable").
    func buildMessage(summary: String, timestamp: Date, lat: Double?, lng: Double?, locationNote: String? = nil) -> String {
        let time = timestamp.formatted(date: .omitted, time: .shortened)
        var message = "SAKLOLO: \(summary). \(time)."
        if let lat, let lng {
            message += " \(locationNote ?? "Location"): maps.apple.com/?ll=\(lat),\(lng)"
        } else if let locationNote {
            message += " \(locationNote)."
        }
        return message
    }
}
