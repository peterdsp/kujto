import ArgumentParser
import Foundation
import KujtoCore

/// `kujto map` prints the repo's memory map: the deterministic aggregate that
/// the Kujto Studio sidebar renders.
struct MapCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "map",
        abstract: "Show the repo's memory map (scoped rules, base memory, risks)."
    )

    @OptionGroup var global: GlobalOptions

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let root = KujtoRoot.locate()
            let map = try MemoryMapScanner.scan(root: root)

            if global.json {
                emitter.emit(type: "memory_map", [
                    "root": .string(map.root),
                    "has_agents_file": .bool(map.hasAgentsFile),
                    "has_memory_index": .bool(map.hasMemoryIndex),
                    "memory_count": .int(map.memoryCount),
                    "skill_count": .int(map.skillCount),
                    "risk_tags": .array(map.riskTags.map { .string($0) }),
                    "scoped_rules": .array(map.scopedRules.map(Self.ruleObject)),
                    "base_rules": .array(map.baseRules.map(Self.ruleObject))
                ])
            } else {
                print("Memory map: \(map.root)")
                print("  AGENTS.md:      \(map.hasAgentsFile ? "yes" : "no")")
                print("  MEMORY.md:      \(map.hasMemoryIndex ? "yes" : "no")")
                print("  memory files:   \(map.memoryCount)")
                print("  skills:         \(map.skillCount)")
                if !map.riskTags.isEmpty {
                    print("  risk tags:      \(map.riskTags.joined(separator: ", "))")
                }
                print("  scoped rules (\(map.scopedRules.count)):")
                for rule in map.scopedRules {
                    print("    • \(rule.title)")
                    print("        \(rule.path)  [\(rule.appliesTo.joined(separator: ", "))]")
                }
                print("  base memory (\(map.baseRules.count) files, read every session)")
            }
        }
    }

    private static func ruleObject(_ rule: Rule) -> NDJSONValue {
        .object([
            "path": .string(rule.path),
            "title": .string(rule.title),
            "kind": .string(rule.kind.rawValue),
            "applies_to": .array(rule.appliesTo.map { .string($0) }),
            "risk": .array(rule.risk.map { .string($0) })
        ])
    }
}
