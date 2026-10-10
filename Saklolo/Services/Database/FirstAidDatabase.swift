import Foundation

/// What the classifier and the guide read from a validated database. The
/// type itself sits in `DatabaseValidator.swift` so the publishing tool can
/// compile it without the app.
extension FirstAidDatabase {
    /// Classifier entries, in file order. `general` has none: it is what the
    /// classifier answers when nothing matches.
    var keywords: KeywordDatabase {
        KeywordDatabase(version: version, entries: scripts
            .filter { $0.id != FirstAidDatabaseValidator.generalScript }
            .map { KeywordDatabase.Entry(script: $0.id, keywords: $0.keywords) })
    }

    /// A fresh, transient script for the guide (never inserted in SwiftData),
    /// so a guide that is open keeps its copy when the database changes.
    func script(id: String) -> FirstAidScript? {
        scripts.first { $0.id == id }.map {
            FirstAidScript(id: $0.id, title: $0.title, keywords: $0.keywords, steps: $0.steps, source: $0.source)
        }
    }

    /// `database.json` from the app bundle, if it passes the validator.
    static func bundled(_ bundle: Bundle = .main) -> FirstAidDatabase? {
        guard let url = bundle.url(forResource: "database", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              case .success(let database) = FirstAidDatabaseValidator.validate(data) else { return nil }
        return database
    }
}
