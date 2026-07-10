import SwiftUI
import KujtoCore

/// Phase 8 surface: the memory-debt heartbeat as a Codex card. Shows the grade,
/// the score, and the component breakdown so the number always explains itself.
struct DebtCardView: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        PaperCard {
            if let debt = model.debt {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(debt.grade.label)
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(color(for: debt.grade))
                        SoftPill(text: "\(debt.score) / 100", tone: tone(for: debt.grade))
                        Spacer(minLength: 0)
                    }
                    Text(debt.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(debt.summary)

                    if debt.components.isEmpty {
                        Text("Nothing owed. Memory reads clean.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkTertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(debt.components, id: \.name) { component in
                                HStack(alignment: .top, spacing: 12) {
                                    Rectangle()
                                        .fill(color(for: debt.grade))
                                        .frame(width: 2)
                                        .padding(.vertical, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(component.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Theme.ink)
                                            SoftPill(text: "\(component.count) · +\(component.points)", tone: .neutral)
                                        }
                                        Text(component.note)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.inkTertiary)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            } else {
                Text("Kujto is measuring memory debt…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
    }

    private func color(for grade: MemoryDebt.Grade) -> Color {
        switch grade {
        case .healthy: return Theme.success
        case .watch: return Theme.warning
        case .heavy: return Theme.danger
        }
    }

    private func tone(for grade: MemoryDebt.Grade) -> SoftPill.Tone {
        switch grade {
        case .healthy: return .success
        case .watch: return .warning
        case .heavy: return .danger
        }
    }
}
