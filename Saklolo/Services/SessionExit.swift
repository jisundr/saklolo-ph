import Foundation

/// The way out of the chat screen shown in its header, and what it does.
enum SessionExit: Equatable {
    /// Ends the session with the saved incident and its alert rows.
    case done
    /// ✕ Cancel. Before the alert has gone out it saves and sends nothing;
    /// once the alert is out (or going out) it keeps the incident like Done,
    /// because the text cannot be taken back.
    case cancel(keepsIncident: Bool)

    /// - Parameters:
    ///   - incidentSaved: understanding finished and the incident exists.
    ///   - awaitingPerson: alone mode's dock is up and nothing is sent yet.
    ///   - alertFired: a send has started (or finished).
    static func header(incidentSaved: Bool, awaitingPerson: Bool, alertFired: Bool) -> SessionExit {
        // While the dock decides, "Done" would silently stand in for
        // "I'm okay"; Cancel is the only way out then (G1, G5).
        if incidentSaved && !(awaitingPerson && !alertFired) { return .done }
        return .cancel(keepsIncident: alertFired)
    }

    /// The accessibility hint for the header button.
    var hint: String {
        switch self {
        case .done: "Ends the session and keeps the incident."
        case .cancel(keepsIncident: false): "Stops listening. Nothing is saved or sent."
        case .cancel(keepsIncident: true): "The alert has gone out. Ends the session and keeps the incident."
        }
    }
}
