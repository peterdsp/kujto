import Foundation
import SwiftUI
import KujtoCore
import KujtoGit
import KujtoSync

/// Keeps the synced project registry current and offers the rehydrate flow on a
/// new machine. Recording a repo happens as a side effect of opening it (so the
/// registry follows the user without extra steps); rehydrate is always an
/// explicit click, since cloning a whole working set should never be silent.
@MainActor
final class RegistryService: ObservableObject {
    @Published private(set) var plan: RehydratePlan?
    @Published private(set) var message: String?

    static let shared = RegistryService()

    private var memoryDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kujto/memory-sync")
    }
    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Records the opened repo into the synced registry, keyed on its remote.
    /// A no-op when there is no memory repo yet or the repo has no remote.
    func record(root: URL) {
        let client = ShellGitClient()
        guard client.isRepository(memoryDir) else { return }
        guard let remote = client.remoteURL(in: root) else { return }
        do {
            let store = RegistryStore(repo: memoryDir)
            try store.ensureInitialized()
            var registry = try store.loadRegistry()
            registry.upsert(RegisteredProject(
                name: root.lastPathComponent,
                remote: remote,
                wiredAgents: ["claude", "codex", "gemini"],
                localPathHint: RegisteredProject.hint(forLocalPath: root, home: home)))
            try store.saveRegistry(registry)
        } catch {
            message = "Could not record repo: \(error.localizedDescription)"
        }
    }

    /// Builds a rehydrate plan for this machine from the synced registry.
    func refreshPlan() {
        let client = ShellGitClient()
        guard client.isRepository(memoryDir) else { plan = nil; return }
        do {
            let registry = try RegistryStore(repo: memoryDir).loadRegistry()
            plan = Rehydrator(client: client).plan(for: registry, on: MachineContext(home: home))
        } catch {
            plan = nil
        }
    }

    /// Projects the plan would clone or re-wire on this machine.
    var actionableCount: Int { plan?.actionable.count ?? 0 }

    /// Executes the plan: clone missing repos and wire the memory into each.
    func rehydrate() {
        guard let plan else { return }
        message = "Rehydrating your projects..."
        Task.detached {
            let results = Rehydrator(client: ShellGitClient()).execute(plan) { path, _ in
                guard let kujtoRoot = KujtoLocator.locate() else { return }
                let service = WireService(root: kujtoRoot, emitter: EventEmitter(mode: .human))
                try service.wire(WireService.Options(target: path))
            }
            let cloned = results.filter { if case .cloned = $0 { return true } else { return false } }.count
            let wired = results.filter { if case .wired = $0 { return true } else { return false } }.count
            await MainActor.run {
                self.message = "Rehydrated: \(cloned) cloned, \(wired) re-wired."
                self.refreshPlan()
            }
        }
    }
}
