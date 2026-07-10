import SwiftUI
import Charts
import KujtoCore

/// Phase 1 of the Repository Intelligence OS: the Confidence Dashboard.
///
/// Reads the deterministic verdict `StudioModel` computed from the risk scorer
/// and the snapshot history the ledger recorded, and renders four things the
/// roadmap asks for: a verdict card (level, reason, primary action), a Swift
/// Charts risk trend, a cause stack, and a next-action row. No model calls; the
/// numbers match what `kujto` computes in KujtoCore.
///
/// Accessibility is a feature here, not an afterthought: a plain-language
/// summary is exposed to VoiceOver before the chart, and a parallel data table
/// mirrors every point so the trend never depends on sight.
struct ConfidenceDashboardView: View {
    @ObservedObject var model: StudioModel
    /// Bound to the Codex focus field so "focus the riskiest file" works.
    @Binding var focusFile: String

    /// Snapshot history cached here and refreshed only when a new assessment
    /// lands, so scrolling never triggers a SwiftData fetch.
    @State private var history: [RiskSnapshot] = []

    private var verdict: RiskScore? { model.risk }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let verdict {
                verdictCard(verdict)
                trendCard
                if !verdict.causes.isEmpty { causeStack(verdict) }
                nextActionRow(verdict)
            } else {
                pending
            }
        }
        .task(id: model.assessmentTick) {
            history = model.riskHistory().sorted { $0.takenAt < $1.takenAt }
        }
    }

    // MARK: - Verdict card

    private func verdictCard(_ verdict: RiskScore) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(verdict.level.label)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(color(for: verdict.level))
                    SoftPill(text: "\(verdict.score) / 100", tone: tone(for: verdict.level))
                    if let delta = deltaText {
                        SoftPill(text: delta.text, tone: delta.tone)
                    }
                    Spacer(minLength: 0)
                }
                Text(verdict.headline)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(fileSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
            }
            // One spoken sentence for VoiceOver, read before the visuals below.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenSummary)
        }
    }

    // MARK: - Trend chart

    private var trendCard: some View {
        // Uses the cached `history` (refreshed on assessmentTick), never a
        // fetch during render.
        PaperCard(weight: .muted) {
            VStack(alignment: .leading, spacing: 12) {
                Text("RISK TREND")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkTertiary)

                if history.count < 2 {
                    Text(history.isEmpty
                         ? "No history yet. The trend appears once Kujto has recorded more than one assessment."
                         : "One assessment recorded. The trend line appears after the next scan.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    chart(history)
                    dataTable(history)
                }
            }
        }
    }

    private func chart(_ history: [RiskSnapshot]) -> some View {
        Chart {
            ForEach(history, id: \.id) { snap in
                AreaMark(
                    x: .value("Time", snap.takenAt),
                    y: .value("Risk", snap.score)
                )
                .foregroundStyle(Theme.accent.opacity(0.12))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", snap.takenAt),
                    y: .value("Risk", snap.score)
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Time", snap.takenAt),
                    y: .value("Risk", snap.score)
                )
                .foregroundStyle(color(for: snap.level))
                .accessibilityLabel(Text(dateLabel(snap.takenAt)))
                .accessibilityValue(Text("\(snap.level.label), score \(snap.score) of 100"))
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let n = value.as(Int.self) {
                        Text("\(n)").font(.system(size: 9)).foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
            }
        }
        .frame(height: 160)
        // The chart as a whole carries the trend summary for VoiceOver, so a
        // screen-reader user hears direction and worst point before points.
        .accessibilityLabel("Risk trend over the last \(history.count) assessments")
        .accessibilityValue(trendSummary(history))
    }

    /// The table fallback the roadmap requires: every plotted point, in text.
    private func dataTable(_ history: [RiskSnapshot]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
            GridRow {
                tableHeader("When")
                tableHeader("Level")
                tableHeader("Score")
            }
            ForEach(history.reversed(), id: \.id) { snap in
                GridRow {
                    Text(dateLabel(snap.takenAt))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                    Text(snap.level.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color(for: snap.level))
                    Text("\(snap.score)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityLabel("Risk trend data table")
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .medium))
            .tracking(1.0)
            .foregroundStyle(Theme.inkTertiary)
    }

    // MARK: - Cause stack

    private func causeStack(_ verdict: RiskScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S DRIVING IT")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            ForEach(Array(verdict.causes.prefix(3).enumerated()), id: \.offset) { _, cause in
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(color(for: verdict.level))
                        .frame(width: 2)
                        .padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(cause.title)
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundStyle(Theme.ink)
                            SoftPill(text: "+\(cause.weight)", tone: .neutral)
                        }
                        Text(cause.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(cause.title), adds \(cause.weight) points. \(cause.detail)")
            }
        }
    }

    // MARK: - Next action row

    private func nextActionRow(_ verdict: RiskScore) -> some View {
        HStack(spacing: 12) {
            Text(verdict.action.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(verdict.level == .safe ? Theme.success : Theme.accent)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    (verdict.level == .safe ? Theme.successSoft : Theme.accentSoft),
                    in: Capsule()
                )
            if let riskiest = model.riskFiles.first, riskiest.score.level > .safe {
                Button {
                    focusFile = riskiest.path
                } label: {
                    Text("Focus \((riskiest.path as NSString).lastPathComponent)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pending / empty

    private var pending: some View {
        Text("Kujto is assessing this repo's risk. The verdict appears in a moment.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Derived text

    /// The single sentence VoiceOver reads for the verdict card.
    private var spokenSummary: String {
        guard let verdict else { return "Risk verdict pending." }
        var s = "Repository risk is \(verdict.level.label), \(verdict.score) out of 100. \(verdict.headline)"
        if let delta = deltaText { s += " \(delta.spoken)" }
        return s
    }

    private var fileSummary: String {
        guard let verdict else { return "" }
        let files = model.riskFiles
        let flagged = files.filter { $0.score.level > .safe }.count
        if files.isEmpty { return "No rule-matched files assessed yet." }
        return "\(flagged) of \(files.count) assessed files need attention · verdict \(verdict.level.label.lowercased())."
    }

    /// Current score minus the previous snapshot's, as a signed chip.
    private var deltaText: (text: String, spoken: String, tone: SoftPill.Tone)? {
        guard let verdict, let previous = model.previousRisk else { return nil }
        let diff = verdict.score - previous.score
        if diff == 0 { return ("no change", "Unchanged since the last assessment.", .neutral) }
        let sign = diff > 0 ? "+" : ""
        // Higher score is worse, so a rise is a warning, a drop is success.
        let tone: SoftPill.Tone = diff > 0 ? .danger : .success
        let dir = diff > 0 ? "up" : "down"
        return ("\(sign)\(diff) vs last", "Risk is \(dir) \(abs(diff)) points since the last assessment.", tone)
    }

    private func trendSummary(_ history: [RiskSnapshot]) -> Text {
        guard let first = history.first, let last = history.last else { return Text("No data.") }
        let dir = last.score > first.score ? "rising" : (last.score < first.score ? "falling" : "flat")
        let worst = history.max { $0.score < $1.score }
        let worstText = worst.map { "worst was \($0.score) on \(dateLabel($0.takenAt))" } ?? ""
        return Text("Trend is \(dir), now \(last.score) of 100. \(worstText).")
    }

    // MARK: - Formatting and palette

    private func dateLabel(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()

    private func color(for level: RiskScore.Level) -> Color {
        switch level {
        case .safe: return Theme.success
        case .watch: return Theme.warning
        case .escalating: return Theme.danger
        case .blocked: return Theme.danger
        }
    }

    private func tone(for level: RiskScore.Level) -> SoftPill.Tone {
        switch level {
        case .safe: return .success
        case .watch: return .warning
        case .escalating: return .danger
        case .blocked: return .danger
        }
    }
}
