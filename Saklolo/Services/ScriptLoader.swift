import Foundation

/// Loads the bundled first-aid scripts (Resources/Scripts/*.json) into
/// SwiftData on first launch. The JSON files, not this loader, are the
/// thing to check against the IFRC first aid guidelines 2020 they cite.
struct ScriptLoader {
    struct ScriptFile: Decodable {
        let id: String
        let title: String
        let keywords: [String]
        let steps: [String]
        let source: String
    }

    /// Xcode copies the script JSONs into the bundle root, not into a
    /// `Scripts` folder, so both places are searched. `keywords.json`
    /// sits next to them and is not a script.
    func loadBundledScripts(in bundle: Bundle = .main) throws -> [FirstAidScript] {
        let inFolder = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Scripts") ?? []
        let atRoot = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let urls = (inFolder + atRoot).filter { $0.lastPathComponent != "keywords.json" }
        let decoder = JSONDecoder()
        var seen = Set<String>()
        var scripts: [FirstAidScript] = []
        for url in urls {
            let data = try Data(contentsOf: url)
            let file = try decoder.decode(ScriptFile.self, from: data)
            guard seen.insert(file.id).inserted else { continue }
            scripts.append(FirstAidScript(id: file.id, title: file.title, keywords: file.keywords, steps: file.steps, source: file.source))
        }
        return scripts
    }
}
