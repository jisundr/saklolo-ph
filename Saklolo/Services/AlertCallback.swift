import Foundation

/// The Shortcuts x-callback-url round trip that tells the app whether the
/// alert text actually went out.
///
/// What iOS does and does not report:
/// - `canOpenURL` and `UIApplication.open` only say the Shortcuts app could
///   be opened. They say nothing about whether a shortcut named "Saklolo"
///   exists or whether its Send Message action ran.
/// - Shortcuts opens `x-success` when the shortcut finishes, `x-cancel` when
///   the person stops it, and `x-error` when an action fails while running.
/// - A shortcut that does not exist: observed in the iOS 27 simulator,
///   Shortcuts opens `x-error` at once, with no alert of its own:
///   `saklolo://alert/<id>/failed?errorDomain=NSCocoaErrorDomain&errorMessage=Could not find the shortcut "Saklolo."&errorCode=4`.
///   (The plain `shortcuts://run-shortcut` form shows that message as an
///   alert and reports nothing.) Not verified on a device, and nothing
///   documents that every failure calls back, so silence also counts as
///   "not confirmed": `AlertPolicy.confirmationWait` after the person is
///   back in the app.
/// - Even `x-success` only means the shortcut ran to the end. Whether the
///   carrier delivered the SMS is never reported to any app.
enum AlertCallback {
    /// The URL scheme this app registers (project.yml, `CFBundleURLTypes`).
    static let scheme = "saklolo"

    enum Result: String, Equatable, Sendable {
        /// The shortcut ran to the end.
        case sent
        /// An action in the shortcut failed.
        case failed
        /// The person stopped the shortcut.
        case cancelled
    }

    /// `saklolo://alert/<id>/<result>`. The id and result are in the path, so
    /// the query Shortcuts appends (`errorMessage=...`, `result=...`) never
    /// gets in the way of reading them.
    static func url(_ result: Result, id: UUID) -> URL {
        URL(string: "\(scheme)://alert/\(id.uuidString)/\(result.rawValue)")!
    }

    /// The alert and result a callback URL is about, or nil for any other URL.
    static func parse(_ url: URL) -> (id: UUID, result: Result)? {
        guard url.scheme?.lowercased() == scheme, url.host == "alert" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2,
              let id = UUID(uuidString: parts[0]),
              let result = Result(rawValue: parts[1]) else { return nil }
        return (id, result)
    }

    /// The Shortcut's input: JSON text `{"to": [<numbers>], "text": <message>}`.
    /// The Shortcut reads it with Get Dictionary from Input, so the numbers
    /// entered in the app are the ones texted and the Shortcut itself holds
    /// no contacts (one shared Shortcut works for everyone).
    static func shortcutInput(message: String, recipients: [String]) -> String? {
        let payload: [String: Any] = ["to": recipients, "text": message]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes]),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    /// Runs the "Saklolo" shortcut with `shortcutInput` as its text input,
    /// asking Shortcuts to come back with the result for alert `id`.
    static func shortcutURL(message: String, recipients: [String], id: UUID) -> URL? {
        // Never plain text: a Shortcut expecting a dictionary would get none.
        guard let input = shortcutInput(message: message, recipients: recipients) else { return nil }
        let query = [
            ("name", "Saklolo"),
            ("input", "text"),
            ("text", input),
            ("x-success", url(.sent, id: id).absoluteString),
            ("x-error", url(.failed, id: id).absoluteString),
            ("x-cancel", url(.cancelled, id: id).absoluteString),
        ]
        .map { "\($0)=\(encode($1))" }
        .joined(separator: "&")
        return URL(string: "shortcuts://x-callback-url/run-shortcut?\(query)")
    }

    /// Strict query-value encoding: `&`, `=`, `+`, `?` and `/` in the text or
    /// a callback URL would otherwise end or split the value.
    private static func encode(_ value: String) -> String {
        // ASCII only: `.alphanumerics` would let "ñ" through unencoded.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
