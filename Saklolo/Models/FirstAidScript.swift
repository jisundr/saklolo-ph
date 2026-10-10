import Foundation
import SwiftData

/// A fixed, vetted first-aid script. The LLM only ever picks which script
/// matches — it never writes medical instructions itself (see brief's
/// "First-aid scripts (safety rule)").
///
/// Built transient from `database.json` (bundled, or a verified update) each
/// time a guide opens; nothing inserts these into the store. The `@Model`
/// stays so the SwiftData schema does not change.
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
