import SwiftUI
import AppKit
import KujtoCore

/// Kujto Studio's primary surface - the Codex.
///
/// A single scrolling editorial document that IS the app. There is no sidebar
/// and no detail pane. Repo memory (AGENTS.md, memory/, skills/, agent files)
/// renders as chapters of a typeset book; live intelligence (agent presence,
/// lint, applies-to matches) lives in the right-hand marginalia column;
/// `⌘K` opens a command palette that floats over the document.
///
/// Design intent is "the document is the product". Everything a user does
/// happens against the same continuous page - no panel switching, no modal
/// context loss.
struct CodexView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.openWindow) private var openWindow

    /// The file the user is focused on. When set, the Codex highlights only
    /// the rules that match. Populated from the focus bar or the palette.
    @State private var focusFile: String = ""
    @State private var showPalette = false

    var body: some View {
        ZStack(alignment: .top) {
            Theme.canvas.ignoresSafeArea()

            if model.rootPath == nil {
                emptyState
            } else {
                document
            }

            if showPalette {
                CommandPaletteOverlay(
                    model: model,
                    focusFile: $focusFile,
                    isVisible: $showPalette
                )
                .transition(.opacity)
            }
        }
        .background(paletteHotkey)
        // Mirror the focus into the model so the Memory-Lens window, a
        // separate scene, can follow the same file.
        .onChange(of: focusFile) { _, newValue in model.focusFile = newValue }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: "memory-lens")
                } label: {
                    Label("Memory Lens", systemImage: "circle.dashed")
                }
                .help("Open the Memory-Lens window")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showPalette.toggle()
                    }
                } label: {
                    Label("Ask Kujto", systemImage: "command")
                }
                .help("Open command palette (⌘K)")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("PROLOGUE")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(Theme.inkTertiary)
                Text("You haven't pointed Kujto at a repo yet.")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Kujto renders your project's AI instructions as a living, source-backed document. Everything stays on your machine. Point it at a repo to begin.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: pickRepo) {
                    Text("Choose a repo").padding(.vertical, 4).padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .padding(.top, 8)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 60)
            .padding(.top, 96)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Document

    private var document: some View {
        ScrollView {
            // LazyVStack so off-screen chapters (runtime, sync, proposals) do
            // not render or run their .task work until scrolled into view.
            LazyVStack(alignment: .leading, spacing: 56) {
                prologue
                confidenceChapter
                debtChapter
                focusBar
                if !focusFile.isEmpty { traceChapter }
                baseMemoryChapter
                scopedRulesChapter
                proposalsChapter
                agentsChapter
                skillsChapter
                if !model.conflicts.isEmpty { conflictsChapter }
                healthChapter
                rewindChapter
                syncChapter
                runtimeChapter
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Prologue

    private var prologue: some View {
        let counts = repoCounts()
        return VStack(alignment: .leading, spacing: 16) {
            Text("PROLOGUE")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Theme.inkTertiary)
            Text("Kujto read your repo memory.")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                CountPill(number: counts.rules, label: "rules")
                CountPill(number: counts.scoped, label: "file-scoped")
                CountPill(number: counts.agents, label: "agents wired")
                CountPill(number: counts.skills, label: "skills")
                if counts.lint > 0 {
                    CountPill(number: counts.lint, label: "issues", tone: .warning)
                }
            }
            .padding(.top, 4)
            if let root = model.rootPath {
                Text(root)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.top, 2)
            }
        }
    }

    private func repoCounts() -> (rules: Int, scoped: Int, agents: Int, skills: Int, lint: Int) {
        let base = model.map?.baseRules.count ?? 0
        let scoped = model.map?.scopedRules.count ?? 0
        return (base + scoped, scoped, model.linkedAgentCount, model.skills.count, model.lintIssues.count)
    }

    // MARK: - Focus bar

    private var focusBar: some View {
        HStack(spacing: 12) {
            Text("FOCUS")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Theme.inkTertiary)
                .padding(.trailing, 4)
            TextField("Paste or type a file path to see only what applies…", text: $focusFile)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))
            if !focusFile.isEmpty {
                Button("Clear") { focusFile = "" }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Confidence chapter (the dashboard)

    private var confidenceChapter: some View {
        chapterSpread(
            mark: "❖",
            title: "Confidence",
            subtitle: "A graded read on how risky this repo is to touch right now, with the trend over time and what is driving it. Deterministic, local, no model calls."
        ) {
            ConfidenceDashboardView(model: model, focusFile: $focusFile)
                .padding(.top, 4)
        } marginalia: {
            VStack(alignment: .leading, spacing: 8) {
                if let risk = model.risk {
                    marginaliaHeader("Verdict", value: "\(risk.level.label) · \(risk.score)/100")
                } else {
                    marginaliaHeader("Verdict", value: "Assessing…")
                }
                if let previous = model.previousRisk {
                    marginaliaHeader("Previous", value: "\(previous.level.label) · \(previous.score)/100")
                }
            }
        }
    }

    // MARK: - Repo sentiment chapter (memory debt)

    private var debtChapter: some View {
        chapterSpread(
            mark: "∑",
            title: "Repo sentiment",
            subtitle: "One memory-debt number, built only from real signals: lint, conflicts, stale rules, and overrides. Every point explains itself."
        ) {
            DebtCardView(model: model).padding(.top, 4)
        } marginalia: {
            if let debt = model.debt {
                marginaliaHeader("Debt", value: "\(debt.grade.label) · \(debt.score)/100")
            } else {
                marginaliaHeader("Debt", value: "Measuring…")
            }
        }
    }

    // MARK: - Proposed rules chapter (generative memory)

    private var proposalsChapter: some View {
        chapterSpread(
            mark: "✎",
            title: "Proposed rules",
            subtitle: "Kujto drafts scoped rules for file groups that have none. Deterministic, and never written for you: you review and adopt."
        ) {
            ProposalsView(model: model).padding(.top, 4)
        } marginalia: {
            marginaliaHeader("Safety", value: "Drafts only · you adopt")
        }
    }

    // MARK: - Governance rewind chapter (rule history)

    private var rewindChapter: some View {
        chapterSpread(
            mark: "↺",
            title: "Governance rewind",
            subtitle: "Trace a rule through git: when it appeared, and when its risk tags or globs changed. Drag the slider back through time."
        ) {
            GovernanceRewindView(model: model).padding(.top, 4)
        } marginalia: {
            marginaliaHeader("Source", value: "Local git history")
        }
    }

    // MARK: - Sync chapter (peer proposal exchange)

    private var syncChapter: some View {
        chapterSpread(
            mark: "⇄",
            title: "Team sync",
            subtitle: "Share signed rule proposals with teammates on the local network. Everything is signature-checked on arrival and nothing installs without your review."
        ) {
            SyncView(model: model).padding(.top, 4)
        } marginalia: {
            marginaliaHeader("Trust", value: "Signed proposals · you adopt")
        }
    }

    // MARK: - Chapter I. Base memory

    private var baseMemoryChapter: some View {
        chapterSpread(
            mark: "I",
            title: "Base memory",
            subtitle: "Rules that apply across the whole repo. Every agent reads these on every session."
        ) {
            if let base = model.map?.baseRules, !base.isEmpty {
                VStack(spacing: 14) {
                    ForEach(base, id: \.path) { rule in
                        RuleParagraph(rule: rule, focusFile: focusFile)
                    }
                }
            } else {
                emptyChapterNote("No base rules found. Kujto looked in memory/ and skills/ for .md files without applies_to frontmatter.")
            }
        } marginalia: {
            marginaliaHeader("Reach", value: "Every session · every agent · every file")
        }
    }

    // MARK: -Avg. Chapter II. Scoped rules

    private var scopedRulesChapter: some View {
        chapterSpread(
            mark: "II",
            title: "Rules by scope",
            subtitle: "Rules that fire only when a matching file is being touched. This is the layer that keeps agents safe around load-bearing code."
        ) {
            let scoped = filteredScopedRules()
            if scoped.isEmpty {
                emptyChapterNote(focusFile.isEmpty
                    ? "No file-scoped rules yet. Add `applies_to` to a memory file to make it fire only for matching paths."
                    : "No scoped rules match this file. Base memory still applies.")
            } else {
                VStack(spacing: 14) {
                    ForEach(scoped, id: \.path) { rule in
                        RuleParagraph(rule: rule, focusFile: focusFile)
                    }
                }
            }
        } marginalia: {
            if focusFile.isEmpty {
                marginaliaHeader("Reach", value: "Selective · matched by glob")
            } else {
                marginaliaHeader("Focused on", value: (focusFile as NSString).lastPathComponent)
            }
        }
    }

    private func filteredScopedRules() -> [Rule] {
        guard let scoped = model.map?.scopedRules else { return [] }
        guard !focusFile.isEmpty else { return scoped }
        return scoped.filter { rule in
            rule.appliesTo.contains { Glob.matches($0, path: focusFile) }
        }
    }

    // MARK: - Chapter III. Agent wiring

    private var agentsChapter: some View {
        chapterSpread(
            mark: "III",
            title: "Who speaks Kujto here",
            subtitle: "Six agents may read this repo's memory. Kujto keeps them in step by pointing every agent file at one source."
        ) {
            VStack(spacing: 12) {
                ForEach(model.agents, id: \.agent) { status in
                    AgentParagraph(status: status)
                }
            }
        } marginalia: {
            VStack(alignment: .leading, spacing: 8) {
                marginaliaHeader("Sync", value: "\(model.linkedAgentCount) of 6 in sync")
                if model.rootPath != nil {
                    Button {
                        _ = model.wireCurrentRepo()
                    } label: {
                        Text(model.linkedAgentCount == 0 ? "Wire this repo" : "Re-wire")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    if model.linkedAgentCount > 0 {
                        Button("Unwire") { _ = model.unwireCurrentRepo() }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Chapter IV. Skills

    private var skillsChapter: some View {
        chapterSpread(
            mark: "IV",
            title: "Techniques your agents can call on",
            subtitle: "Each skill is a reusable procedure - a 'how' the model reads before it acts. Install into a single repo or globally so every session sees it."
        ) {
            if model.skills.isEmpty {
                emptyChapterNote("No skills shipped in this build.")
            } else {
                VStack(spacing: 14) {
                    ForEach(model.skills) { skill in
                        SkillParagraph(skill: skill, model: model)
                    }
                }
            }
        } marginalia: {
            marginaliaHeader("Catalog", value: "\(model.skills.count) available")
        }
    }

    // MARK: - Chapter V. Health

    private var healthChapter: some View {
        chapterSpread(
            mark: "VI",
            title: "Health of this memory",
            subtitle: "Static checks over AGENTS.md, memory/, and skills/. Deterministic, no model calls, safe to trust."
        ) {
            if model.lintIssues.isEmpty {
                emptyChapterNote("Everything reads clean. No missing files, no unmatched globs, no broken wiki-links.")
            } else {
                VStack(spacing: 10) {
                    ForEach(model.lintIssues, id: \.self) { issue in
                        LintParagraph(issue: issue)
                    }
                }
            }
        } marginalia: {
            HStack(spacing: 6) {
                if model.lintErrorCount > 0 {
                    SoftPill(text: "\(model.lintErrorCount)", tone: .danger)
                }
                if model.lintWarningCount > 0 {
                    SoftPill(text: "\(model.lintWarningCount)", tone: .warning)
                }
                if model.lintIssues.isEmpty {
                    SoftPill(text: "clear", tone: .success)
                }
            }
        }
    }

    // MARK: - Memory Trace chapter (appears only when focused)

    private var traceChapter: some View {
        chapterSpread(
            mark: "◆",
            title: "Why this file behaves the way it does",
            subtitle: "A citation chain. Each step in this trace is a discrete cause: a glob that matched, a rule that loaded, an agent that will or will not receive the context."
        ) {
            if let root = model.rootPath.map({ URL(fileURLWithPath: $0) }),
               let trace = try? MemoryTracer.trace(file: focusFile, in: root) {
                MemoryTraceView(trace: trace)
            } else {
                emptyChapterNote("Trace unavailable - no repo selected.")
            }
        } marginalia: {
            marginaliaHeader("Trace target", value: (focusFile as NSString).lastPathComponent)
        }
    }

    // MARK: - Conflicts chapter (appears only when there are any)

    private var conflictsChapter: some View {
        chapterSpread(
            mark: "V",
            title: "Where the memory disagrees with itself",
            subtitle: "Kujto found structural disagreements - duplicated titles or overlapping scopes with divergent risk. It doesn't judge the meaning; the fix is yours to make."
        ) {
            VStack(spacing: 12) {
                ForEach(Array(model.conflicts.enumerated()), id: \.offset) { _, conflict in
                    ConflictParagraph(conflict: conflict)
                }
            }
        } marginalia: {
            marginaliaHeader("Detected", value: "\(model.conflicts.count) disagreement\(model.conflicts.count == 1 ? "" : "s")")
        }
    }

    // MARK: - Runtime chapter (real detection)

    private var runtimeChapter: some View {
        chapterSpread(
            mark: "◈",
            title: "Runtime - Simulator Trace",
            subtitle: "The bridge between rules and behavior. Detection is real today; capture is real once the helper daemon is registered."
        ) {
            VStack(alignment: .leading, spacing: 20) {
                RuntimeReadout()
                SimulatorTraceLab(focusFile: focusFile, repoRoot: model.rootPath.map { URL(fileURLWithPath: $0) })
            }
        } marginalia: {
            RuntimeMarginalia()
        }
    }

    // MARK: - Chapter spread scaffolding

    /// Two-column spread: chapter mark + editorial main text on the left,
    /// live marginalia on the right. The layout collapses gracefully on
    /// narrower windows because the marginalia column has a fixed width.
    @ViewBuilder
    private func chapterSpread<Main: View, Margin: View>(
        mark: String,
        title: String,
        subtitle: String,
        @ViewBuilder main: () -> Main,
        @ViewBuilder marginalia: () -> Margin
    ) -> some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(mark)
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(minWidth: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                main().padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                marginalia()
            }
            .frame(width: 200, alignment: .leading)
            .padding(.top, 60)
        }
    }

    private func marginaliaHeader(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func emptyChapterNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.inkTertiary)
            .padding(.top, 4)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Palette hotkey

    /// Invisible key listener so ⌘K opens the palette. Uses NSEvent's local
    /// monitor because SwiftUI's keyboardShortcut on a hidden button doesn't
    /// fire when the ScrollView owns focus.
    private var paletteHotkey: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.command),
                       event.charactersIgnoringModifiers == "k" {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showPalette.toggle()
                        }
                        return nil
                    }
                    return event
                }
            }
    }

    private func pickRepo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.open(url)
        }
    }
}

// MARK: - Prologue support

/// Small numeric pill for the prologue. Number reads big, label small.
private struct CountPill: View {
    let number: Int
    let label: String
    var tone: SoftPill.Tone = .neutral

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number)")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(fg)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(bg, in: Capsule())
    }

    private var fg: Color {
        switch tone {
        case .neutral: return Theme.ink
        case .accent:  return Theme.accent
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger:  return Theme.danger
        }
    }

    private var bg: Color {
        switch tone {
        case .neutral: return Theme.cardMuted
        case .accent:  return Theme.accentSoft
        case .success: return Theme.successSoft
        case .warning: return Theme.warningSoft
        case .danger:  return Theme.dangerSoft
        }
    }
}

// MARK: - Rule paragraph

/// A single rule rendered as a paragraph in the Codex. Title, path, glob
/// list, and - when a focus file is set and this rule matches - a small
/// "applies to focused file" note in the gutter.
private struct RuleParagraph: View {
    let rule: Rule
    let focusFile: String

    private var isMatched: Bool {
        guard !focusFile.isEmpty else { return false }
        return rule.appliesTo.contains { Glob.matches($0, path: focusFile) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(isMatched ? Theme.accent : Theme.hairline)
                .frame(width: 2)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(rule.title)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    if !rule.risk.isEmpty {
                        ForEach(rule.risk, id: \.self) { tag in
                            SoftPill(text: tag, tone: .danger)
                        }
                    }
                }
                Text(rule.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
                if !rule.appliesTo.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(rule.appliesTo, id: \.self) { glob in
                            Text(glob)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.inkSecondary)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(Theme.cardMuted, in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Agent paragraph

private struct AgentParagraph: View {
    let status: WireStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(status.state == .linked ? Theme.success : Theme.hairline)
                .frame(width: 2)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(status.agent.displayName)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    switch status.state {
                    case .linked:     SoftPill(text: "in sync", tone: .success)
                    case .foreign:    SoftPill(text: "your file", tone: .warning)
                    case .notPresent: EmptyView()
                    }
                }
                Text(story)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status.agent.fileName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var story: String {
        switch status.state {
        case .linked:
            return "\(status.agent.fileName) points at Kujto's memory. Any change flows through."
        case .foreign:
            return "A file called \(status.agent.fileName) already exists here. Kujto will leave it alone."
        case .notPresent:
            return "Not wired here yet. Wiring creates a link from \(status.agent.fileName) to Kujto's memory."
        }
    }
}

// MARK: - Skill paragraph

private struct SkillParagraph: View {
    let skill: SkillEntry
    @ObservedObject var model: StudioModel
    @State private var localInstalled = false
    @State private var globalInstalled = false
    @State private var error: String?
    @State private var showEditor = false

    private var localScope: SkillInstaller.Scope? {
        model.rootPath.map { .local(repoRoot: URL(fileURLWithPath: $0)) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(localInstalled || globalInstalled ? Theme.accent : Theme.hairline)
                .frame(width: 2)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(skill.name)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    switch (localInstalled, globalInstalled) {
                    case (true, true):   SoftPill(text: "here · everywhere", tone: .accent)
                    case (true, false):  SoftPill(text: "here", tone: .accent)
                    case (false, true):  SoftPill(text: "everywhere", tone: .accent)
                    case (false, false): EmptyView()
                    }
                }
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("kujto-\(skill.slug)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
                HStack(spacing: 12) {
                    Button("Edit source") { showEditor = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    if let localScope {
                        Button(localInstalled ? "Remove from repo" : "Install here") {
                            toggle(scope: localScope, isInstalled: localInstalled)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: localInstalled ? .regular : .medium))
                        .foregroundStyle(localInstalled ? Theme.inkTertiary : Theme.accent)
                    }
                    Button(globalInstalled ? "Remove everywhere" : "Install everywhere") {
                        toggle(scope: .global, isInstalled: globalInstalled)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: globalInstalled ? .regular : .medium))
                    .foregroundStyle(globalInstalled ? Theme.inkTertiary : Theme.accent)
                }
                .padding(.top, 2)
                if let error {
                    Text(error).font(.system(size: 11)).foregroundStyle(Theme.danger)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .onAppear(perform: refresh)
        .onChange(of: model.rootPath) { _, _ in refresh() }
        .sheet(isPresented: $showEditor) {
            SkillEditor(skill: skill) {
                // Re-load catalog after edit so frontmatter changes flow.
                model.reloadSkills()
                refresh()
            }
        }
    }

    private func refresh() {
        globalInstalled = SkillInstaller.isInstalled(skill, scope: .global)
        if let localScope {
            localInstalled = SkillInstaller.isInstalled(skill, scope: localScope)
        } else {
            localInstalled = false
        }
    }

    private func toggle(scope: SkillInstaller.Scope, isInstalled: Bool) {
        error = nil
        do {
            if isInstalled {
                try SkillInstaller.uninstall(skill, scope: scope)
            } else {
                try SkillInstaller.install(skill, scope: scope)
            }
            refresh()
        } catch let e as SkillInstaller.InstallError {
            if case .grantDenied = e { return }
            error = e.errorDescription
        } catch let other {
            error = other.localizedDescription
        }
    }
}

// MARK: - Memory Trace view

/// Renders a `MemoryTrace` as a vertical citation column. Steps sit on a
/// single left-aligned rail; each step is a dot + inline prose, with
/// receiver states at the bottom so the reader sees "who gets this" last.
private struct MemoryTraceView: View {
    let trace: MemoryTrace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            step(role: "FILE", text: trace.file, isFirst: true)
            step(role: "BASE MEMORY",
                 text: trace.baseRuleCount > 0
                    ? "\(trace.baseRuleCount) always-on rule\(trace.baseRuleCount == 1 ? "" : "s") load first."
                    : "No base memory in this repo.")
            if trace.matches.isEmpty {
                step(role: "SCOPED MATCH", text: "No file-scoped rules match this path. Only base memory applies.")
            } else {
                ForEach(Array(trace.matches.enumerated()), id: \.offset) { idx, match in
                    step(
                        role: idx == 0 ? "SCOPED MATCHES" : nil,
                        text: "\(match.ruleTitle) - matched by \(match.matchedGlob)",
                        detail: match.rulePath,
                        risk: match.risk
                    )
                }
            }
            ForEach(Array(trace.receivers.enumerated()), id: \.offset) { idx, receiver in
                step(
                    role: idx == 0 ? "AGENTS" : nil,
                    text: "\(receiver.agent.displayName) \(receiver.state == .receiving ? "✓" : "✗") - \(receiver.note)",
                    isLast: idx == trace.receivers.count - 1,
                    isReceiving: receiver.state == .receiving
                )
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func step(
        role: String?,
        text: String,
        detail: String? = nil,
        risk: [String] = [],
        isFirst: Bool = false,
        isLast: Bool = false,
        isReceiving: Bool? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 12)
                }
                Circle()
                    .fill(dotColor(isReceiving: isReceiving))
                    .frame(width: 8, height: 8)
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 1).frame(minHeight: 16)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 3) {
                if let role {
                    Text(role)
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Theme.inkTertiary)
                }
                HStack(spacing: 8) {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(risk, id: \.self) { tag in
                        SoftPill(text: tag, tone: .danger)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .padding(.top, isFirst ? 0 : 4)
            .padding(.bottom, 6)
            Spacer(minLength: 0)
        }
    }

    private func dotColor(isReceiving: Bool?) -> Color {
        if let isReceiving { return isReceiving ? Theme.success : Theme.warning }
        return Theme.accent
    }
}

// MARK: - Conflict paragraph

private struct ConflictParagraph: View {
    let conflict: Conflict
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.warning)
                .frame(width: 2)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(kindLabel)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    SoftPill(text: kindTag, tone: .warning)
                }
                Text(conflict.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Text(conflict.first.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                    Text("vs.").font(.system(size: 11)).foregroundStyle(Theme.inkTertiary)
                    Text(conflict.second.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var kindLabel: String {
        switch conflict.kind {
        case .duplicateTitle:    return "Duplicate title"
        case .overlappingScope:  return "Overlapping scope"
        }
    }

    private var kindTag: String {
        switch conflict.kind {
        case .duplicateTitle:    return "duplicate"
        case .overlappingScope:  return "scope"
        }
    }
}

// MARK: - Runtime marginalia (helper daemon controls + safety tier)

/// Right-column controls for the Runtime chapter. Daemon status, capability
/// tier picker (Observe / Interact / Build / Modify), and Ping. The
/// capability tier is what the helper uses to authorize incoming commands;
/// dropping it here immediately narrows what any Codex or PromptBar
/// request can do.
private struct RuntimeMarginalia: View {
    // The privileged helper daemon ships only in the direct build. The App
    // Store build bundles no helper, so its controls and capability tier are
    // compiled out entirely rather than shown as non-functional affordances.
    #if DIRECT_BUILD
    @ObservedObject private var helper = RuntimeHelperClient.shared
    @State private var pingResult: String?
    @State private var registerError: String?
    #endif
    @ObservedObject private var bridge = PromptBarBridge.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if DIRECT_BUILD
            daemonSection
            capabilitySection
            #endif
            promptbarSection
        }
    }

    #if DIRECT_BUILD
    // MARK: Daemon

    private var daemonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            marginaliaHeader("Helper daemon", value: helper.status.kujtoDescription)
            HStack(spacing: 10) {
                if helper.status == .enabled {
                    Button("Ping") { pingHelper() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    Button("Unregister") { Task { await unregister() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                } else {
                    Button("Register") { register() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            if let pingResult {
                Text(pingResult)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let registerError {
                Text(registerError)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Capability tier

    private var capabilitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            marginaliaHeader("Capability", value: helper.grantedCapability.displayName)
            Picker("Tier", selection: $helper.grantedCapability) {
                ForEach(RuntimeCapability.allCases, id: \.self) { cap in
                    Text(cap.displayName).tag(cap)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Text(helper.grantedCapability.summary)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    #endif

    // MARK: PromptBar bridge

    private var promptbarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            marginaliaHeader("PromptBar bridge",
                             value: bridge.isRunning ? "127.0.0.1:7377" : "Off")
            HStack(spacing: 10) {
                if bridge.isRunning {
                    Button("Stop") { bridge.stop() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                } else {
                    Button("Start") { bridge.start() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            if let err = bridge.lastError {
                Text(err).font(.system(size: 11)).foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Point PromptBar's provider at http://127.0.0.1:7377/v1, model \"kujto-memory\". Kujto answers from this repo's memory.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func marginaliaHeader(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    #if DIRECT_BUILD
    private func register() {
        registerError = nil
        do {
            try helper.register()
        } catch let error {
            registerError = error.localizedDescription
        }
    }

    private func unregister() async {
        registerError = nil
        do {
            try await helper.unregister()
        } catch let error {
            registerError = error.localizedDescription
        }
    }

    private func pingHelper() {
        pingResult = "..."
        Task {
            let result = await helper.ping()
            switch result {
            case .success(let msg): pingResult = msg
            case .failure(let err): pingResult = "xpc: \(err.localizedDescription)"
            }
        }
    }
    #endif
}

// MARK: - Runtime readout

/// Live detection of the local iOS runtime tooling. Shows real Xcode state,
/// prompts once for CoreSimulator access, then lists installed simulators
/// with a "Copy simctl command" affordance per device. Never launches the
/// simulator itself - that's the helper-daemon story.
private struct RuntimeReadout: View {
    @State private var snapshot: RuntimeDetector.Snapshot = RuntimeDetector.snapshot()
    @State private var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            xcodeRow
            simulatorSection
            copyNote
        }
        .padding(.vertical, 4)
    }

    // MARK: Xcode

    private var xcodeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(snapshot.xcodeInstalled ? Theme.success : Theme.warning)
                .frame(width: 2)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Xcode")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    SoftPill(
                        text: snapshot.xcodeInstalled ? "installed" : "not installed",
                        tone: snapshot.xcodeInstalled ? .success : .warning
                    )
                }
                Text(snapshot.xcodeInstalled
                     ? "Kujto detected Xcode. simctl is available at xcrun simctl."
                     : "Xcode is not in /Applications. The Runtime layer needs it.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let path = snapshot.xcodePath {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: Simulators

    @ViewBuilder
    private var simulatorSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.accent.opacity(0.6))
                .frame(width: 2)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Installed simulators")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                if !snapshot.simulatorGranted {
                    grantPrompt
                } else if snapshot.simulators.isEmpty {
                    Text("Kujto found the CoreSimulator folder but no devices inside it. Create a simulator in Xcode → Devices and rescan.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    rescanButton
                } else {
                    VStack(spacing: 8) {
                        ForEach(snapshot.simulators.prefix(8)) { device in
                            SimulatorRow(device: device, copiedCommand: $copiedCommand)
                        }
                    }
                    if snapshot.simulators.count > 8 {
                        Text("+ \(snapshot.simulators.count - 8) more not shown")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    rescanButton
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var grantPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kujto needs one-time access to ~/Library/Developer/CoreSimulator/Devices to read your installed simulators. It only reads; no launches, taps, or writes.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant CoreSimulator access") {
                if RuntimeDetector.grantCoreSimulatorAccess() {
                    snapshot = RuntimeDetector.snapshot()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
    }

    private var rescanButton: some View {
        Button("Rescan simulators") { snapshot = RuntimeDetector.snapshot() }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Theme.accent)
    }

    private var copyNote: some View {
        HStack(spacing: 8) {
            SoftPill(text: "read-only", tone: .neutral)
            SoftPill(text: "no process launch", tone: .neutral)
            SoftPill(text: "helper daemon in Phase D2", tone: .neutral)
        }
        .padding(.top, 6)
    }
}

/// One simulator, with copy-simctl-command actions. The commands are what
/// Kujto's helper daemon will run automatically once it ships; for now the
/// user copies and runs them manually in Terminal.
private struct SimulatorRow: View {
    let device: LocalSimulator
    @Binding var copiedCommand: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(device.state == .booted ? Theme.success : Theme.inkTertiary.opacity(0.5))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    SoftPill(
                        text: device.state.label.lowercased(),
                        tone: device.state == .booted ? .success : .neutral
                    )
                }
                Text(device.displayLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
                Text(device.udid)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 12) {
                    copyAction("Boot", command: SimctlCommand.boot(device: device))
                    copyAction("Open URL…", command: SimctlCommand.openURL(device: device, url: "yourapp://"))
                    copyAction("Screenshot", command: SimctlCommand.screenshot(device: device, to: "~/Desktop/screenshot.png"))
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private func copyAction(_ label: String, command: String) -> some View {
        Button(copiedCommand == command ? "Copied" : label) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            copiedCommand = command
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if copiedCommand == command { copiedCommand = nil }
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: copiedCommand == command ? .regular : .medium))
        .foregroundStyle(copiedCommand == command ? Theme.inkTertiary : Theme.accent)
    }
}

// MARK: - Simulator Trace lab

/// The composition surface. Given a picked simulator, an optional deep link,
/// and the currently-focused file, capture what Kujto can (a screenshot and
/// a log excerpt) and cite the memory rules that apply to the file. Kujto
/// does not interpret the runtime - that's the LLM's job. Kujto stages the
/// evidence and points at the rules that should govern it.
private struct SimulatorTraceLab: View {
    @ObservedObject private var helper = RuntimeHelperClient.shared
    let focusFile: String
    let repoRoot: URL?

    @State private var simulators: [LocalSimulator] = []
    @State private var selectedUDID: String = ""
    @State private var deeplink: String = ""
    @State private var isCapturing = false
    @State private var errorMessage: String?
    @State private var screenshot: NSImage?
    @State private var logExcerpt: String = ""
    @State private var lastCaptureAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(helper.status == .enabled ? Theme.accent : Theme.inkTertiary)
                    .frame(width: 2)
                    .padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capture a trace")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    if helper.status != .enabled {
                        #if DIRECT_BUILD
                        Text("Enable the helper daemon in the margin to unlock capture. Detection above works without it.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        #else
                        Text("Simulator capture ships in the direct build of Kujto Studio. Detection above works here.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        #endif
                    } else {
                        Text("Pick a booted simulator, optionally hit it with a deep link, and Kujto captures screenshot + log excerpt. Cited against the focused file's memory.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if helper.status == .enabled {
                captureControls
                if isCapturing {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.6)
                        Text("Capturing…").font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if screenshot != nil || !logExcerpt.isEmpty {
                    resultsPanel
                }
            }
        }
        .onAppear(perform: loadSims)
        .onChange(of: helper.status) { _, newStatus in
            if newStatus == .enabled { loadSims() }
        }
    }

    // MARK: Controls

    private var captureControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("SIMULATOR")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkTertiary)
                Picker("Simulator", selection: $selectedUDID) {
                    Text("Pick one…").tag("")
                    ForEach(simulators) { sim in
                        Text("\(sim.name) · \(sim.state.label)").tag(sim.udid)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            HStack(spacing: 8) {
                Text("DEEPLINK")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkTertiary)
                TextField("Optional - yourapp://…", text: $deeplink)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            HStack {
                Button("Capture trace") { Task { await capture() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(selectedUDID.isEmpty || isCapturing)
                if let at = lastCaptureAt {
                    Text("last capture \(relative(at))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.leading, 4)
                }
                Spacer()
            }
        }
    }

    // MARK: Results

    private var resultsPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            if let screenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 380)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 0.5))
            }
            VStack(alignment: .leading, spacing: 10) {
                if !focusFile.isEmpty, let root = repoRoot {
                    citedRules(root: root)
                }
                if !logExcerpt.isEmpty {
                    logCard
                }
            }
        }
    }

    @ViewBuilder
    private func citedRules(root: URL) -> some View {
        let trace = try? MemoryTracer.trace(file: focusFile, in: root)
        VStack(alignment: .leading, spacing: 6) {
            Text("CITED FROM MEMORY")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            if let trace, !trace.matches.isEmpty {
                ForEach(Array(trace.matches.prefix(4).enumerated()), id: \.offset) { _, match in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").font(.system(size: 12)).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.ruleTitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text(match.rulePath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.inkTertiary)
                        }
                    }
                }
            } else {
                Text("No file-scoped rules for \(focusFile). Base memory still applies.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOG EXCERPT")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            ScrollView {
                Text(logExcerpt)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            .padding(10)
            .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Capture flow

    private func loadSims() {
        simulators = RuntimeDetector.snapshot().simulators
        if selectedUDID.isEmpty, let firstBooted = simulators.first(where: { $0.state == .booted }) {
            selectedUDID = firstBooted.udid
        }
    }

    private func capture() async {
        errorMessage = nil
        isCapturing = true
        defer { isCapturing = false }

        // 1. Optionally hit the app with a deep link.
        if !deeplink.isEmpty {
            let result = await helper.openURL(udid: selectedUDID, url: deeplink)
            if case .failure(let error) = result {
                errorMessage = "openurl failed: \(error.localizedDescription)"
                return
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        // 2. Screenshot into /tmp; helper reads it and returns the bytes.
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-trace-\(UUID().uuidString).png").path
        let shot = await helper.screenshot(udid: selectedUDID, to: temp)
        switch shot {
        case .success(let data):
            screenshot = NSImage(data: data)
        case .failure(let error):
            errorMessage = "screenshot failed: \(error.localizedDescription)"
            return
        }

        // 3. Last minute of log output - enough to see what the app just did.
        let log = await helper.logShow(udid: selectedUDID, predicate: "", lastMinutes: 1)
        switch log {
        case .success(let data):
            let text = String(data: data, encoding: .utf8) ?? ""
            let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            logExcerpt = lines.suffix(40).joined(separator: "\n")
        case .failure(let error):
            errorMessage = "log show failed: \(error.localizedDescription)"
        }

        lastCaptureAt = Date()
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Lint paragraph

private struct LintParagraph: View {
    let issue: LintIssue
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(issue.severity == .error ? Theme.danger : Theme.warning)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(issue.message)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(issue.file)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("·").foregroundStyle(Theme.inkTertiary)
                    Text(issue.code)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Command palette overlay

/// Floating command surface. Not a real NLP layer yet - a curated list of
/// commands the user can navigate with ↑↓ and invoke with ⏎. The primary
/// input doubles as the file-focus set-command.
private struct CommandPaletteOverlay: View {
    @ObservedObject var model: StudioModel
    @Binding var focusFile: String
    @Binding var isVisible: Bool

    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "command")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                    TextField("Ask Kujto - a file path, a command, or a question…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.ink)
                        .focused($fieldFocused)
                        .onSubmit { commit() }
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 22)

                if !filteredCommands.isEmpty {
                    Divider().background(Theme.hairline)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredCommands, id: \.title) { cmd in
                                Button(action: { invoke(cmd) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: cmd.icon)
                                            .foregroundStyle(Theme.accent)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cmd.title)
                                                .font(.system(size: 14))
                                                .foregroundStyle(Theme.ink)
                                            if let subtitle = cmd.subtitle {
                                                Text(subtitle)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Theme.inkTertiary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 22)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
            .frame(width: 620)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 0.5)
            )
            .padding(.top, 96)
        }
        .onAppear { fieldFocused = true }
        .background(escapeHandler)
    }

    private var escapeHandler: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 { // Escape
                        DispatchQueue.main.async { dismiss() }
                        return nil
                    }
                    return event
                }
            }
    }

    private struct Command {
        let title: String
        let subtitle: String?
        let icon: String
        let action: () -> Void
    }

    private var commands: [Command] {
        var list: [Command] = []
        if model.rootPath != nil {
            list.append(Command(
                title: "Focus on file…",
                subtitle: query.isEmpty ? "Show only the rules that apply" : "Focus on \(query)",
                icon: "scope",
                action: {
                    focusFile = query
                    dismiss()
                }
            ))
            list.append(Command(
                title: model.linkedAgentCount == 0 ? "Wire this repo" : "Re-wire this repo",
                subtitle: "Point every agent file at Kujto's memory",
                icon: "arrow.triangle.merge",
                action: {
                    _ = model.wireCurrentRepo()
                    dismiss()
                }
            ))
            if model.linkedAgentCount > 0 {
                list.append(Command(
                    title: "Unwire",
                    subtitle: "Remove Kujto's symlinks. Your own files are left alone.",
                    icon: "link.badge.minus",
                    action: {
                        _ = model.unwireCurrentRepo()
                        dismiss()
                    }
                ))
            }
        }
        list.append(Command(
            title: "Clear focus",
            subtitle: focusFile.isEmpty ? "Nothing focused" : "Currently on \((focusFile as NSString).lastPathComponent)",
            icon: "xmark.circle",
            action: {
                focusFile = ""
                dismiss()
            }
        ))
        return list
    }

    private var filteredCommands: [Command] {
        guard !query.isEmpty else { return commands }
        let q = query.lowercased()
        return commands.filter { $0.title.lowercased().contains(q) || $0.subtitle?.lowercased().contains(q) == true }
    }

    private func invoke(_ cmd: Command) {
        cmd.action()
    }

    /// Called on Enter with no command selected. Treats the query as a file
    /// path to focus on - the most common power-user shortcut.
    private func commit() {
        if !query.isEmpty {
            focusFile = query
        }
        dismiss()
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isVisible = false
        }
    }
}
