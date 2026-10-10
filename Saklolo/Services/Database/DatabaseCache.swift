import Foundation

/// The last verified update on disk: one file holding the database bytes and
/// their signature together, so a crash mid-write can never pair a new file
/// with an old signature. Re-verified on every load (`DatabaseStore`), so a
/// file changed on disk is ignored rather than trusted.
struct DatabaseCache: Sendable {
    private struct Envelope: Codable {
        /// Base64 in the JSON (JSONEncoder's default for Data).
        let payload: Data
        let signature: Data
    }

    let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("database-cache.json")
    }

    /// Application Support/Saklolo.
    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Saklolo", isDirectory: true)
    }

    /// Nil when there is no file or it is not a readable envelope.
    func read() -> (payload: Data, signature: Data)? {
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        return (envelope.payload, envelope.signature)
    }

    /// Atomic, and readable after the first unlock since boot so an alert
    /// raised from the lock screen still sees the update.
    func write(payload: Data, signature: Data) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Envelope(payload: payload, signature: signature))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
