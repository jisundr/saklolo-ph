import Foundation

// Foundation only, no app types: `tools/dbtool.sh` compiles this file on its
// own so the publishing tool and the app apply exactly the same rules.

/// The keyword rules and first-aid scripts as one versioned file
/// (`database.json`). The bundled copy is the baseline; a signed update with a
/// higher version replaces it (see `DatabaseStore`).
///
/// Script order is classifier priority: the first script with a matching
/// keyword wins. `general` is the fallback and its keywords are ignored.
struct FirstAidDatabase: Codable, Sendable, Equatable {
    struct Script: Codable, Sendable, Equatable {
        var id: String
        var title: String
        var keywords: [String]
        var steps: [String]
        var source: String
    }

    var version: Int
    var scripts: [Script]
}

/// Why a database file was not used. Any of these leaves the database in use
/// unchanged.
enum DatabaseRejection: Error, Equatable, Sendable {
    case malformed
    case badVersion
    case duplicateScript(String)
    case missingScript(String)
    case noTitle(String)
    case noKeywords(String)
    case stepCount(String)
    case countingStep(String)
    case badSource(String)
    case firstStep(String)
    /// Signature missing, unreadable, or not made by the bundled key.
    case badSignature
}

/// The rules every database file must pass, bundled or downloaded. These used
/// to live only in unit tests on the bundle; a downloaded file never went
/// through those, so they run here at load time instead.
enum FirstAidDatabaseValidator {
    static let generalScript = "general"

    /// Scripts the app has content for. A script with any other id is dropped
    /// (the rest of the file still applies); every one of these must be present.
    static let knownScripts: Set<String> = ["fall", "bleeding", "unconscious", "head_injury", generalScript]

    static let steps = 3...6

    static func validate(_ data: Data) -> Result<FirstAidDatabase, DatabaseRejection> {
        guard let file = try? JSONDecoder().decode(FirstAidDatabase.self, from: data) else { return .failure(.malformed) }
        guard file.version >= 1 else { return .failure(.badVersion) }

        // Unknown ids are dropped first, so a duplicate of one never rejects the file.
        let scripts = file.scripts.filter { knownScripts.contains($0.id) }
        var seen = Set<String>()
        for script in scripts where !seen.insert(script.id).inserted {
            return .failure(.duplicateScript(script.id))
        }
        // Sorted so the reported id does not depend on Set order.
        for id in knownScripts.sorted() where !scripts.contains(where: { $0.id == id }) {
            return .failure(.missingScript(id))
        }

        for script in scripts {
            if let rejection = problem(with: script) { return .failure(rejection) }
        }
        return .success(FirstAidDatabase(version: file.version, scripts: scripts))
    }

    private static func problem(with script: FirstAidDatabase.Script) -> DatabaseRejection? {
        let id = script.id
        if isBlank(script.title) { return .noTitle(id) }
        if id != generalScript, script.keywords.isEmpty || script.keywords.contains(where: { !isUsableKeyword($0) }) {
            return .noKeywords(id)
        }
        if !steps.contains(script.steps.count) || script.steps.contains(where: isBlank) { return .stepCount(id) }
        // The app does not count CPR compressions, so no step may promise it.
        if script.steps.contains(where: { $0.localizedCaseInsensitiveContains("count") }) { return .countingStep(id) }
        if !script.source.contains("IFRC") || script.source.localizedCaseInsensitiveContains("TODO") { return .badSource(id) }
        // FR-S4: the guide opens by making sure help is being called.
        let first = script.steps[0]
        if !first.localizedCaseInsensitiveContains("help") || !first.contains("911") { return .firstStep(id) }
        return nil
    }

    /// At least three letters or digits: the classifier normalizes keywords and
    /// matches them as substrings, so "!!!" would be empty and "a" would match
    /// almost any transcript.
    private static func isUsableKeyword(_ text: String) -> Bool {
        text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count >= 3
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
