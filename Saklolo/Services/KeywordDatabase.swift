import Foundation

/// Offline keyword → first-aid script lookup, kept as data (like Whoscall's
/// on-device number list) so it can be edited, and later updated, without a
/// code change. Ships as `keywords.json` in the app bundle; `builtIn` is the
/// last resort if the file is missing or fails validation, so a bad file can
/// never leave the fallback classifier empty.
///
/// Entry order matters: the first script with a matching keyword wins, so
/// more specific scripts go first ("nauntog ... may dugo" is a head injury,
/// not just bleeding).
struct KeywordDatabase: Sendable {
    struct Entry: Codable, Sendable {
        let script: String
        let keywords: [String]
    }

    private struct File: Codable {
        let version: Int
        let scripts: [Entry]
    }

    /// Scripts the app has content for. A file naming anything else is rejected.
    static let knownScripts: Set<String> = ["fall", "bleeding", "unconscious", "head_injury"]

    let version: Int
    /// Keywords are stored already normalized (see `normalize`).
    let entries: [Entry]

    init(version: Int, entries: [Entry]) {
        self.version = version
        self.entries = entries.map { Entry(script: $0.script, keywords: $0.keywords.map(Self.normalize).filter { !$0.isEmpty }) }
    }

    /// Lowercase, strip accents, turn punctuation into spaces, collapse runs of
    /// whitespace. "Mag-isa lang AKO!" and "mag isa lang ako" compare equal.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let spaced = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    /// Script ID of the first entry with a keyword contained in the transcript.
    func match(_ transcript: String) -> String? {
        let text = Self.normalize(transcript)
        return entries.first { $0.keywords.contains { text.contains($0) } }?.script
    }

    // MARK: Loading

    /// Parses and validates JSON. Returns nil for anything unusable: bad JSON,
    /// version < 1, no scripts, an unknown script ID, or a script with no keywords.
    static func parse(_ data: Data) -> KeywordDatabase? {
        guard let file = try? JSONDecoder().decode(File.self, from: data),
              file.version >= 1, !file.scripts.isEmpty else { return nil }
        let db = KeywordDatabase(version: file.version, entries: file.scripts)
        guard db.entries.allSatisfy({ knownScripts.contains($0.script) && !$0.keywords.isEmpty }) else { return nil }
        return db
    }

    static func load(from url: URL) -> KeywordDatabase? {
        (try? Data(contentsOf: url)).flatMap(parse)
    }

    /// `keywords.json` from the app bundle, else `builtIn`.
    static func bundled(_ bundle: Bundle = .main) -> KeywordDatabase {
        bundle.url(forResource: "keywords", withExtension: "json").flatMap(load) ?? builtIn
    }

    /// Same content as the bundled file, kept in code as the last resort.
    static let builtIn = KeywordDatabase(version: 0, entries: [
        Entry(script: "head_injury", keywords: ["tumama ang ulo", "nauntog", "nabagok", "nabagok ang ulo"]),
        Entry(script: "unconscious", keywords: ["walang malay", "nawalan ng malay", "di gumigising", "hindi gumigising", "hindi humihinga", "di humihinga", "hinimatay", "nahimatay"]),
        Entry(script: "bleeding", keywords: ["dumudugo", "dugo", "sugat", "naputol"]),
        Entry(script: "fall", keywords: ["nahulog", "nadulas", "bumagsak", "di makagalaw", "hindi makagalaw"]),
    ])
}
