import Foundation
import SwiftData

/// A fixed, vetted first-aid script. The LLM only ever picks which script
/// matches — it never writes medical instructions itself (see brief's
/// "First-aid scripts (safety rule)").
///
/// MVP ships these bundled from Resources/Scripts/*.json, loaded into the
/// store on first launch — this model is the on-device copy judges/first-aid
/// review can point at, not a live editable thing.
@Model
final class FirstAidScript {
    var id: String
    var title: String
    var keywords: [String]
    var steps: [String]
    /// e.g. "IFRC International First Aid, Resuscitation, and Education
    /// Guidelines 2020 (Red Cross Red Crescent)" — shown in-app per the
    /// brief's "show the source in the app" requirement.
    var source: String

    init(id: String, title: String, keywords: [String], steps: [String], source: String) {
        self.id = id
        self.title = title
        self.keywords = keywords
        self.steps = steps
        self.source = source
    }
}
