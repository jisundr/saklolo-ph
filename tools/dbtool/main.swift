// Publishing tool for the first-aid database. Run through tools/dbtool.sh,
// which compiles this file together with the app's
// Saklolo/Services/Database/DatabaseValidator.swift and DatabaseSignature.swift,
// so a file this tool signs passes exactly the checks the app runs.
//
//   keygen [--key <path>] [--public-out <path>]
//   sign <database.json> [--key <path>] [--out <dir>]
//   verify <database.json> <database.json.sig> <public-key.txt>
//
// The private key lives outside the repo (default ~/.saklolo/database-signing-key).

import CryptoKit
import Foundation

let defaultKeyPath = NSString(string: "~/.saklolo/database-signing-key").expandingTildeInPath
let repoRoot = ProcessInfo.processInfo.environment["DBTOOL_REPO_ROOT"].map { URL(fileURLWithPath: $0).standardizedFileURL.path }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("dbtool: \(message)\n".utf8))
    exit(1)
}

/// Value of `--name`, removed from `args`.
func option(_ name: String, in args: inout [String]) -> String? {
    guard let index = args.firstIndex(of: name) else { return nil }
    guard index + 1 < args.count else { fail("\(name) needs a value") }
    let value = args[index + 1]
    args.removeSubrange(index...(index + 1))
    return value
}

func absolute(_ path: String) -> String {
    URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL.path
}

/// The private key must never sit in the working tree, where it could be committed.
/// Symlinks are resolved (through the nearest existing parent, since the key
/// may not exist yet) and the comparison ignores case, as the macOS volume does.
func refuseInsideRepo(_ path: String) {
    guard let repoRoot else { fail("DBTOOL_REPO_ROOT is not set; run this through tools/dbtool.sh") }
    func resolved(_ path: String) -> String {
        var url = URL(fileURLWithPath: absolute(path))
        var tail: [String] = []
        while !FileManager.default.fileExists(atPath: url.path), url.path != "/" {
            tail.insert(url.lastPathComponent, at: 0)
            url.deleteLastPathComponent()
        }
        return tail.reduce(url.resolvingSymlinksInPath()) { $0.appendingPathComponent($1) }.path.lowercased()
    }
    let root = resolved(repoRoot)
    let target = resolved(path)
    if target == root || target.hasPrefix(root + "/") {
        fail("refusing to keep the private key inside the repo (\(path)); use a path outside it")
    }
}

func read(_ path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: absolute(path)) else { fail("cannot read \(path)") }
    return data
}

func validated(_ data: Data, _ path: String) -> FirstAidDatabase {
    switch FirstAidDatabaseValidator.validate(data) {
    case .success(let database): return database
    case .failure(let rejection): fail("\(path) is not a valid database: \(rejection)")
    }
}

func loadPrivateKey(_ path: String) -> Curve25519.Signing.PrivateKey {
    let text = String(decoding: read(path), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let raw = Data(base64Encoded: text), let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("\(path) is not a base64 Ed25519 private key")
    }
    return key
}

func keygen(_ args: [String]) {
    var args = args
    let keyPath = absolute(option("--key", in: &args) ?? defaultKeyPath)
    let publicOut = option("--public-out", in: &args)
    guard args.isEmpty else { fail("keygen: unexpected \(args)") }
    refuseInsideRepo(keyPath)
    guard !FileManager.default.fileExists(atPath: keyPath) else { fail("\(keyPath) exists; refusing to overwrite a signing key") }

    let key = Curve25519.Signing.PrivateKey()
    let directory = (keyPath as NSString).deletingLastPathComponent
    do {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    } catch {
        fail("cannot create \(directory): \(error)")
    }
    guard FileManager.default.createFile(atPath: keyPath, contents: Data((key.rawRepresentation.base64EncodedString() + "\n").utf8),
                                         attributes: [.posixPermissions: 0o600]) else { fail("cannot write \(keyPath)") }

    let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
    if let publicOut {
        guard FileManager.default.createFile(atPath: absolute(publicOut), contents: Data((publicKey + "\n").utf8)) else {
            fail("cannot write \(publicOut)")
        }
        print("public key written to \(publicOut)")
    }
    print("private key: \(keyPath) (back it up; never commit it)")
    print("public key:  \(publicKey)")
}

func sign(_ args: [String]) {
    var args = args
    let keyPath = option("--key", in: &args) ?? defaultKeyPath
    let outDir = absolute(option("--out", in: &args) ?? (repoRoot.map { "\($0)/database" } ?? "database"))
    guard args.count == 1 else { fail("usage: sign <database.json> [--key <path>] [--out <dir>]") }
    let source = args[0]
    let payload = read(source)
    let database = validated(payload, source)

    // A file is applied only if strictly newer than the one in use, so one
    // that is not newer than the bundle or the last published file would be
    // ignored by every phone.
    if let repoRoot {
        let bundledPath = "\(repoRoot)/Saklolo/Resources/database.json"
        let bundled = validated(read(bundledPath), bundledPath)
        guard database.version > bundled.version else {
            fail("version \(database.version) is not greater than the bundled version \(bundled.version)")
        }
    }
    let publishedPath = "\(outDir)/database.json"
    if let published = FileManager.default.contents(atPath: publishedPath),
       case .success(let previous) = FirstAidDatabaseValidator.validate(published),
       database.version <= previous.version {
        fail("version \(database.version) is not greater than the published version \(previous.version)")
    }

    let key = loadPrivateKey(keyPath)
    let signature: Data
    do {
        signature = Data((try key.signature(for: payload).base64EncodedString() + "\n").utf8)
    } catch {
        fail("signing failed: \(error)")
    }
    guard DatabaseSignature.isValid(signature, for: payload, publicKey: key.publicKey) else { fail("signature does not verify") }

    do {
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        // The exact bytes that were signed, so the signature matches what is served.
        try payload.write(to: URL(fileURLWithPath: publishedPath), options: .atomic)
        try signature.write(to: URL(fileURLWithPath: publishedPath + ".sig"), options: .atomic)
    } catch {
        fail("cannot write to \(outDir): \(error)")
    }
    print("signed version \(database.version): \(publishedPath) and \(publishedPath).sig")
    print("public key: \(key.publicKey.rawRepresentation.base64EncodedString())")
}

func verify(_ args: [String]) {
    guard args.count == 3 else { fail("usage: verify <database.json> <database.json.sig> <public-key.txt>") }
    let payload = read(args[0])
    guard let publicKey = DatabaseSignature.publicKey(base64: String(decoding: read(args[2]), as: UTF8.self)) else {
        fail("\(args[2]) is not a base64 Ed25519 public key")
    }
    guard DatabaseSignature.isValid(read(args[1]), for: payload, publicKey: publicKey) else { fail("signature does not match") }
    let database = validated(payload, args[0])
    print("ok: version \(database.version), signature valid, \(database.scripts.count) scripts")
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail("usage: keygen | sign | verify (see tools/dbtool/main.swift)") }
arguments.removeFirst()
switch command {
case "keygen": keygen(arguments)
case "sign": sign(arguments)
case "verify": verify(arguments)
default: fail("unknown command \(command)")
}
