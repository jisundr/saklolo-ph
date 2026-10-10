import CryptoKit
import Foundation

/// Checks the detached Ed25519 signature on a database file
/// (`database.json.sig`): the base64 of the 64-byte signature over the file's
/// exact bytes, made with the private key Jayson holds outside the repo.
/// Checked before the JSON is even parsed.
enum DatabaseSignature {
    /// A base64 Ed25519 signature is 88 characters; anything far bigger is not one.
    static let maxLength = 256

    static func isValid(_ signature: Data, for payload: Data, publicKey: Curve25519.Signing.PublicKey) -> Bool {
        guard let raw = decode(signature) else { return false }
        return publicKey.isValidSignature(raw, for: payload)
    }

    /// Base64 text, surrounding whitespace allowed, to the 64 raw bytes.
    static func decode(_ signature: Data) -> Data? {
        guard signature.count <= maxLength,
              let text = String(data: signature, encoding: .ascii),
              let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              raw.count == 64 else { return nil }
        return raw
    }

    /// A public key from the base64 of its 32 raw bytes, nil for anything else.
    static func publicKey(base64: String) -> Curve25519.Signing.PublicKey? {
        guard let raw = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)), raw.count == 32 else { return nil }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }
}
