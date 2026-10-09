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

    /// Opens the "Saklolo" Shortcut with the message text as input.
    /// Fallback per the brief's Risks table: MFMessageComposeViewController
    /// (one tap) if the silent Shortcut send doesn't work on a given device.
    @MainActor
    func sendViaShortcut(message: String) throws {
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=Saklolo&input=text&text=\(encoded)") else {
            throw SendError.invalidURL
        }
        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(url) else { throw SendError.cannotOpenURL }
        UIApplication.shared.open(url)
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
    /// "SAKLOLO: Si Papa nahulog, dumudugo ang ulo, gising pa. 7:42pm. Lokasyon: maps.apple.com/?ll=..."
    func buildMessage(summary: String, timestamp: Date, lat: Double?, lng: Double?) -> String {
        let time = timestamp.formatted(date: .omitted, time: .shortened)
        var message = "SAKLOLO: \(summary). \(time)."
        if let lat, let lng {
            message += " Lokasyon: maps.apple.com/?ll=\(lat),\(lng)"
        }
        return message
    }
}
