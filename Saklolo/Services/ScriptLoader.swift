import Foundation

/// The bundled first-aid scripts, read from `database.json` through the same
/// validator a downloaded update goes through. The file, not this loader, is
/// the thing to check against the IFRC first aid guidelines 2020 it cites.
struct ScriptLoader {
    /// Throws if `database.json` is missing or fails validation
    /// (`DatabaseRejection`).
    func loadBundledScripts(in bundle: Bundle = .main) throws -> [FirstAidScript] {
        guard let url = bundle.url(forResource: "database", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let database = try FirstAidDatabaseValidator.validate(Data(contentsOf: url)).get()
        return database.scripts.compactMap { database.script(id: $0.id) }
    }
}
