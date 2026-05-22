# Indeksi i memories / Memory index

Lexo kete file te parin pas `AGENTS.md`. Hap vetem skedaret e referuar qe lidhen me detyren.
Read this file first after `AGENTS.md`. Open only the referenced files relevant to the task.

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Berthama (core)
- [Stili i shkrimit](core/writing_style.md): rregull i forte, pa vize te gjate.
- [Siguria dhe git](core/safety_and_git.md): pa veprime autonome shkaterruese, pa sekrete.
- [Handoff](core/handoff.md): kur konteksti afrohet limitit, shkruaj `handoff_active.md`.

### iOS, te pergjithshme
- [Konventat Swift](domains/ios/swift_conventions.md): emertim, struktura, modernizim Swift 6.
- [Workflow Xcode](domains/ios/xcode_workflow.md): worktree, scheme, simulator, build.
- [Snapshots](domains/ios/snapshot_testing.md): regjistrim, rishikim, kufij testimi.
- [Navigim](domains/ios/navigation.md): coordinator vs TCA, deep links, modal.

### iOS, arkitektura
- [Permbledhje arkitekturash](domains/ios/architectures/README.md): si te zgjedhesh midis tyre.
- [MVVM](domains/ios/architectures/mvvm.md): SwiftUI + Combine, ekipe te vogla.
- [MVVM-C](domains/ios/architectures/mvvm_c.md): UIKit me Coordinator.
- [VIPER](domains/ios/architectures/viper.md): UIKit, ekipe te medha, ndarje strikte rolesh.
- [Clean Swift / VIP](domains/ios/architectures/clean_swift_vip.md): unidireksional ne shtresen prezantuese.
- [Clean Architecture](domains/ios/architectures/clean_architecture.md): shtresa Domain/Data/Presentation.
- [TCA](domains/ios/architectures/tca.md): The Composable Architecture, state-driven, DI te forte.
- [Unidirectional / Redux](domains/ios/architectures/unidirectional.md): familja e gjere, jo specifike TCA.
- [MV + @Observable](domains/ios/architectures/mv_observable.md): Apple-recommended per SwiftUI 17+.

### Workflows
- [Rendi i pergjigjeve](workflows/answer_order.md): pasqyro saktesisht renditjen e perdoruesit.
- [Pershkrim PR](workflows/pr_descriptions.md): template minimale, pa mure teksti.
- [Higjiena git](workflows/git_hygiene.md): commit-e te vegjel, pa noise, pa sekrete.

---

## English

### Core
- [Writing style](core/writing_style.md): hard rule, no em-dash.
- [Safety and git](core/safety_and_git.md): no autonomous destructive actions, no secrets.
- [Handoff](core/handoff.md): when context budget runs low, write `handoff_active.md`.

### iOS, general
- [Swift conventions](domains/ios/swift_conventions.md): naming, structure, Swift 6 modernisation.
- [Xcode workflow](domains/ios/xcode_workflow.md): worktree, scheme, simulator, build.
- [Snapshots](domains/ios/snapshot_testing.md): recording, review, testing limits.
- [Navigation](domains/ios/navigation.md): coordinator vs TCA, deep links, modals.

### iOS, architectures
- [Architectures overview](domains/ios/architectures/README.md): how to choose between them.
- [MVVM](domains/ios/architectures/mvvm.md): SwiftUI + Combine, small teams.
- [MVVM-C](domains/ios/architectures/mvvm_c.md): UIKit with Coordinator.
- [VIPER](domains/ios/architectures/viper.md): UIKit, large teams, strict role separation.
- [Clean Swift / VIP](domains/ios/architectures/clean_swift_vip.md): unidirectional in the presentation layer.
- [Clean Architecture](domains/ios/architectures/clean_architecture.md): Domain/Data/Presentation layers.
- [TCA](domains/ios/architectures/tca.md): The Composable Architecture, state-driven, strong DI.
- [Unidirectional / Redux](domains/ios/architectures/unidirectional.md): the broader family, not TCA-specific.
- [MV + @Observable](domains/ios/architectures/mv_observable.md): Apple-recommended for SwiftUI 17+.

### Workflows
- [Answer order](workflows/answer_order.md): mirror the user's numbering exactly.
- [PR descriptions](workflows/pr_descriptions.md): minimal template, no wall of text.
- [Git hygiene](workflows/git_hygiene.md): small commits, no noise, no secrets.
