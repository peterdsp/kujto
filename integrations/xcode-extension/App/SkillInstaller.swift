import Foundation
import AppKit

/// Installs Kujto skills from the bundled catalog into either the currently
/// picked repo (local install) or a user-granted ~/.claude/skills folder
/// (global install). Copies the skill tree so the sandbox never needs to
/// resolve a symlink outside its granted scope.
enum SkillInstaller {
    /// Prefix that mirrors the shell installer's naming scheme. Users can
    /// spot Kujto-managed skills at a glance.
    static let installPrefix = "kujto-"

    enum Scope {
        /// `<repo>/.claude/skills/kujto-<slug>/`. Uses the repo's grant.
        case local(repoRoot: URL)
        /// `<grant>/kujto-<slug>/`. Prompts once for ~/.claude/skills.
        case global
    }

    enum InstallError: LocalizedError {
        case grantDenied
        case bookmarkFailed
        case copyFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .grantDenied:               return "No folder chosen."
            case .bookmarkFailed:            return "Could not open the granted folder."
            case .copyFailed(let error):     return "Could not write the skill: \(error.localizedDescription)"
            }
        }
    }

    /// Copies `skill` into the location described by `scope`. Replaces any
    /// existing folder at the target path so re-installing after a catalog
    /// update refreshes cleanly.
    @MainActor
    static func install(_ skill: SkillEntry, scope: Scope) throws {
        let (targetParent, needsStop) = try resolveTarget(for: scope)
        defer { if needsStop { targetParent.stopAccessingSecurityScopedResource() } }

        let target = targetParent.appendingPathComponent(installPrefix + skill.slug, isDirectory: true)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.createDirectory(at: targetParent, withIntermediateDirectories: true)
            try fm.copyItem(at: skill.sourceFolder, to: target)
        } catch {
            throw InstallError.copyFailed(underlying: error)
        }
    }

    /// Removes a previously installed skill from the given scope. No-op if
    /// nothing is at the target path.
    @MainActor
    static func uninstall(_ skill: SkillEntry, scope: Scope) throws {
        let (targetParent, needsStop) = try resolveTarget(for: scope)
        defer { if needsStop { targetParent.stopAccessingSecurityScopedResource() } }
        let target = targetParent.appendingPathComponent(installPrefix + skill.slug, isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: target.path) {
            do { try fm.removeItem(at: target) }
            catch { throw InstallError.copyFailed(underlying: error) }
        }
    }

    /// True if the skill is installed at `scope`. Used to switch button
    /// state between Install and Remove without re-prompting for a grant.
    @MainActor
    static func isInstalled(_ skill: SkillEntry, scope: Scope) -> Bool {
        let (parent, needsStop): (URL, Bool)
        switch scope {
        case .local(let repo):
            parent = repo.appendingPathComponent(".claude/skills")
            needsStop = false
        case .global:
            guard let granted = SharedConfig.resolveClaudeSkillsFolder() else { return false }
            parent = granted
            needsStop = true
        }
        defer { if needsStop { parent.stopAccessingSecurityScopedResource() } }
        let path = parent.appendingPathComponent(installPrefix + skill.slug).path
        return FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Internals

    @MainActor
    private static func resolveTarget(for scope: Scope) throws -> (parent: URL, needsStop: Bool) {
        switch scope {
        case .local(let repo):
            return (repo.appendingPathComponent(".claude/skills"), false)
        case .global:
            if let existing = SharedConfig.resolveClaudeSkillsFolder() {
                return (existing, true)
            }
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.title = "Grant Kujto access to your Claude Code skills folder"
            panel.message = "Pick ~/.claude/skills. Kujto only writes its own skill folders (each prefixed with 'kujto-') into it."
            panel.prompt = "Grant"
            let realHome = URL(fileURLWithPath: NSString("~").expandingTildeInPath)
            panel.directoryURL = realHome.appendingPathComponent(".claude/skills")
            guard panel.runModal() == .OK, let url = panel.url else {
                throw InstallError.grantDenied
            }
            SharedConfig.saveClaudeSkillsFolder(url)
            guard let scoped = SharedConfig.resolveClaudeSkillsFolder() else {
                throw InstallError.bookmarkFailed
            }
            return (scoped, true)
        }
    }
}
