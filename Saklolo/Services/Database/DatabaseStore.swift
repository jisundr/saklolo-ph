import CryptoKit
import Foundation

/// The database the classifier and the guide read right now.
struct ActiveDatabase: Sendable {
    /// 0 when not even the bundle is usable.
    let version: Int
    let keywords: KeywordDatabase
    let database: FirstAidDatabase?

    init(_ database: FirstAidDatabase?) {
        self.database = database
        version = database?.version ?? 0
        keywords = database?.keywords ?? .builtIn
    }

    func title(id: String) -> String? {
        database?.scripts.first { $0.id == id }?.title
    }
}

/// Holds the database in use: the bundled one, or a verified newer update.
///
/// `active` is a plain locked read of an immutable snapshot. It never touches
/// the network or the disk after `init`, so reading it on the alert path
/// cannot delay the alert. `apply` (the updater, off the main thread) swaps
/// the snapshot only after the update is verified and saved.
final class DatabaseStore: @unchecked Sendable {
    enum ApplyResult: Equatable, Sendable {
        case applied(Int)
        case rejected(DatabaseRejection)
        /// Same or older version than the one in use.
        case notNewer
        /// Verified but could not be written to disk; nothing changed.
        case notSaved
    }

    /// The app's store: Application Support cache, the bundled public key.
    /// Created at launch (`SakloloApp`) so the disk read happens before any alert.
    static let shared = DatabaseStore(cache: DatabaseCache(directory: DatabaseCache.defaultDirectory), publicKey: DatabasePublicKey.bundled())

    private let cache: DatabaseCache
    private let state = NSLock()
    private var snapshot: ActiveDatabase
    /// Serializes `apply`, separately from `state`, so the disk write never
    /// holds up a read of `active`.
    private let applying = NSLock()

    /// Bundled database first; then the cache, used only if its signature and
    /// content check out against `publicKey` and it is newer than the bundle
    /// (a newer app build may ship a newer bundle).
    init(bundled: FirstAidDatabase? = .bundled(), cache: DatabaseCache, publicKey: Curve25519.Signing.PublicKey?) {
        self.cache = cache
        var active = ActiveDatabase(bundled)
        if let publicKey, let cached = cache.read(),
           case .success(let database) = Self.verify(payload: cached.payload, signature: cached.signature, publicKey: publicKey),
           database.version > active.version {
            active = ActiveDatabase(database)
        }
        snapshot = active
    }

    var active: ActiveDatabase { state.withLock { snapshot } }

    /// A fresh script for the guide: the one asked for, else `general`.
    func script(id: String) -> FirstAidScript? {
        let database = active.database
        return database?.script(id: id) ?? database?.script(id: FirstAidDatabaseValidator.generalScript)
    }

    /// Signature, then the validator, then strictly newer, then saved; only
    /// then is the in-memory database replaced. Any failure changes nothing.
    func apply(payload: Data, signature: Data, publicKey: Curve25519.Signing.PublicKey) -> ApplyResult {
        let database: FirstAidDatabase
        switch Self.verify(payload: payload, signature: signature, publicKey: publicKey) {
        case .failure(let rejection): return .rejected(rejection)
        case .success(let verified): database = verified
        }
        return applying.withLock {
            guard database.version > active.version else { return .notNewer }
            do {
                try cache.write(payload: payload, signature: signature)
            } catch {
                return .notSaved
            }
            state.withLock { snapshot = ActiveDatabase(database) }
            return .applied(database.version)
        }
    }

    private static func verify(payload: Data, signature: Data, publicKey: Curve25519.Signing.PublicKey) -> Result<FirstAidDatabase, DatabaseRejection> {
        guard DatabaseSignature.isValid(signature, for: payload, publicKey: publicKey) else { return .failure(.badSignature) }
        return FirstAidDatabaseValidator.validate(payload)
    }
}
