import CryptoKit
import Foundation

/// The key updates must be signed with: `database-public-key.txt` in the app
/// bundle, base64 of the 32 raw bytes. Until that file is added (Jayson runs
/// `tools/dbtool.sh keygen` once), there is no key, the updater never makes a
/// request, and the bundled database is all the app uses.
enum DatabasePublicKey {
    static func bundled(_ bundle: Bundle = .main) -> Curve25519.Signing.PublicKey? {
        guard let url = bundle.url(forResource: "database-public-key", withExtension: "txt") else { return nil }
        return load(from: url)
    }

    static func load(from url: URL) -> Curve25519.Signing.PublicKey? {
        guard let data = try? Data(contentsOf: url), data.count <= 1024,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return DatabaseSignature.publicKey(base64: text)
    }
}
