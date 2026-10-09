import Foundation

/// Loads the bundled first-aid scripts (Resources/Scripts/*.json) into
/// SwiftData on first launch. The JSON files, not this loader, are the
/// thing to check against Philippine Red Cross material before submission
/// (brief: "Before submission" checklist).
struct ScriptLoader {
    struct ScriptFile: Decodable {
        let id: String
        let title: String
        let keywords: [String]
        let steps: [String]
        let source: String
    }

    func loadBundledScripts() throws -> [FirstAidScript] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Scripts") else {
            return []
        }
        let decoder = JSONDecoder()
        return try urls.map { url in
            let data = try Data(contentsOf: url)
            let file = try decoder.decode(ScriptFile.self, from: data)
            return FirstAidScript(id: file.id, title: file.title, keywords: file.keywords, steps: file.steps, source: file.source)
        }
    }
}
