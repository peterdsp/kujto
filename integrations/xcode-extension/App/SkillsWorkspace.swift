import Foundation

/// The user-writable copy of Kujto's skill catalog.
///
/// The app ships a read-only catalog inside its bundle at
/// `Contents/Resources/skills/`. On first launch we mirror that catalog into
/// the sandbox container's Application Support folder so the user can edit
/// skill markdown, add new skills, and have installs pick up their edits.
///
/// Everything happens inside the container, so no user grant is required.
enum SkillsWorkspace {
    /// Absolute URL of the writable workspace. Guaranteed to exist after
    /// `ensurePopulated()` returns.
    static let workspaceURL: URL = {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        return appSupport.appendingPathComponent("KujtoStudio/skills", isDirectory: true)
    }()

    /// Copies the bundled catalog into `workspaceURL` if the workspace does
    /// not yet exist, or if the bundle's catalog is newer than the mirror
    /// (i.e. the user installed a new Kujto Studio build). Existing edits
    /// are preserved: only skills that don't yet exist in the workspace are
    /// copied over.
    static func ensurePopulated() {
        let fm = FileManager.default
        try? fm.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

        guard let bundled = bundledCatalogURL(),
              let entries = try? fm.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil) else {
            return
        }
        for entry in entries {
            let target = workspaceURL.appendingPathComponent(entry.lastPathComponent)
            if !fm.fileExists(atPath: target.path) {
                try? fm.copyItem(at: entry, to: target)
            }
        }
    }

    /// Path where a specific skill's SKILL.md lives in the workspace.
    static func skillMarkdownURL(slug: String) -> URL {
        workspaceURL.appendingPathComponent(slug).appendingPathComponent("SKILL.md")
    }

    /// Overwrite a skill's SKILL.md contents. Callers are the inline editor.
    static func writeSkillMarkdown(slug: String, content: String) throws {
        let url = skillMarkdownURL(slug: slug)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func bundledCatalogURL() -> URL? {
        guard let base = Bundle.main.resourceURL else { return nil }
        for candidate in ["skills", "SkillsCatalog"] {
            let url = base.appendingPathComponent(candidate, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return nil
    }
}
