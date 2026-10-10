import Foundation

/// Offline keyword → first-aid script lookup, kept as data (like Whoscall's
/// on-device number list) so it can be edited, and later updated, without a
/// code change. The lists come from each script's `keywords` in
/// `database.json` (see `FirstAidDatabase`); `builtIn` is the last resort if
/// the file is missing or fails validation, so a bad file can never leave the
/// fallback classifier empty.
///
/// Entry order matters: the first script with a matching keyword wins, so
/// more specific scripts go first ("nauntog ... may dugo" is a head injury,
/// not just bleeding).
struct KeywordDatabase: Sendable {
    struct Entry: Codable, Sendable {
        let script: String
        let keywords: [String]
    }

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

    /// The bundled `database.json`'s keyword lists, else `builtIn`.
    static func bundled(_ bundle: Bundle = .main) -> KeywordDatabase {
        FirstAidDatabase.bundled(bundle)?.keywords ?? builtIn
    }

    /// Same content as the bundled file, kept in code as the last resort.
    static let builtIn = KeywordDatabase(version: 0, entries: [
        Entry(script: "head_injury", keywords: ["tumama ang ulo", "nauntog", "nabagok", "nabagok ang ulo"]),
        Entry(script: "unconscious", keywords: ["walang malay", "nawalan ng malay", "di gumigising", "hindi gumigising", "hindi humihinga", "di humihinga", "hinimatay", "nahimatay"]),
        Entry(script: "bleeding", keywords: ["dumudugo", "dugo", "sugat", "naputol"]),
        Entry(script: "fall", keywords: ["nahulog", "nadulas", "bumagsak", "di makagalaw", "hindi makagalaw"]),
    ])
}
