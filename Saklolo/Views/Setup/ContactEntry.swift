import Foundation

/// The rules a B4 contact entry follows, whether it was typed or filled from the phone's Contacts.
enum ContactEntry {
    /// A phone number needs at least this many digits before it can be saved.
    static let minimumDigits = 7

    struct Draft: Equatable {
        var name: String
        var phone: String
    }

    static func normalisedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The number as it is stored: what the person typed or picked, without surrounding whitespace.
    static func normalisedPhone(_ phone: String) -> String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canSave(name: String, phone: String) -> Bool {
        !normalisedName(name).isEmpty && hasEnoughDigits(phone)
    }

    static func hasEnoughDigits(_ phone: String) -> Bool {
        normalisedPhone(phone).filter(\.isNumber).count >= minimumDigits
    }

    /// The display name for a picked contact: given and family name, or the organisation when a
    /// card has no personal name (a barangay hall, a clinic).
    static func name(given: String, family: String, organization: String = "") -> String {
        let personal = [given, family]
            .map(normalisedName)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return personal.isEmpty ? normalisedName(organization) : personal
    }

    /// The number to prefill: the one the person tapped, else the first of the card's numbers
    /// that is long enough to save, else the first one so they can see and fix it.
    static func phone(chosen: String?, from numbers: [String]) -> String? {
        if let chosen, !normalisedPhone(chosen).isEmpty { return normalisedPhone(chosen) }
        let candidates = numbers.map(normalisedPhone).filter { !$0.isEmpty }
        return candidates.first(where: hasEnoughDigits) ?? candidates.first
    }

    /// What the sheet's Name and Phone fields become after a pick. Nil when the card gives
    /// nothing to fill, so the fields are left as they were.
    static func draft(given: String, family: String, organization: String = "",
                      numbers: [String], chosen: String?) -> Draft? {
        let name = name(given: given, family: family, organization: organization)
        let phone = phone(chosen: chosen, from: numbers) ?? ""
        if name.isEmpty && phone.isEmpty { return nil }
        return Draft(name: name, phone: phone)
    }
}
