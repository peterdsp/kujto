import Foundation

/// One installable Kujto skill discovered under the app's bundled
/// `SkillsCatalog/` folder. Each skill is a directory containing a
/// `SKILL.md` markdown file with YAML frontmatter (`name`, `description`,
/// optional `applies_to`).
struct SkillEntry: Identifiable, Hashable {
    var id: String { slug }
    /// Folder name under `skills/`, used as the install slug (`kujto-<slug>`).
    let slug: String
    /// Human name from frontmatter, falling back to the slug.
    let name: String
    /// One-line description from frontmatter, empty if none.
    let description: String
    /// Absolute file URL of the source folder inside the app bundle.
    let sourceFolder: URL
}

/// Reads the bundled skills catalog. Kujto Studio ships every skill it can
/// install inside `Contents/Resources/SkillsCatalog/`; a build phase copies
/// `<repo>/skills/` there so the app never depends on finding a Kujto
/// checkout on disk.
enum SkillsCatalog {
    static func load() -> [SkillEntry] {
        // Always read from the writable workspace, which is a mirror of the
        // bundled catalog seeded on first launch. This is what lets the
        // in-app editor persist changes and lets the installer copy the
        // user's edited version rather than the pristine bundled one.
        SkillsWorkspace.ensurePopulated()
        let root = SkillsWorkspace.workspaceURL
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        var entries: [SkillEntry] = []
        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let skillMD = url.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD.path) else { continue }
            let (name, description) = readFrontmatter(at: skillMD, fallbackName: url.lastPathComponent)
            entries.append(SkillEntry(
                slug: url.lastPathComponent,
                name: name,
                description: description,
                sourceFolder: url
            ))
        }
        return entries.sorted { $0.slug < $1.slug }
    }

    private static func readFrontmatter(at url: URL, fallbackName: String) -> (name: String, description: String) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return (fallbackName, "")
        }
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (fallbackName, "")
        }
        var name = fallbackName
        var description = ""
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = trimmed[..<colon].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "name":        name = String(value)
            case "description": description = String(value)
            default: break
            }
        }
        return (name, description)
    }
}
