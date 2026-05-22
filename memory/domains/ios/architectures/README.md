# Arkitektura iOS / iOS architectures

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Ky folder mban modelet kryesore te arkitektures qe perdoren ne iOS sot. Cdo file pershkruan modelin, kur ta zgjedhesh, formen e tij minimale ne Swift, dhe anti-pattern-et qe duhen shmangur.

### Modelet e mbuluara

| Modeli | File | Konteksti tipik |
|---|---|---|
| MVVM | [mvvm.md](mvvm.md) | SwiftUI + Combine, ekipe te vogla deri mesatare |
| MVVM-C | [mvvm_c.md](mvvm_c.md) | UIKit me coordinator per navigim |
| VIPER | [viper.md](viper.md) | Ekipe te medha UIKit, ndarje strikte rolesh |
| Clean Swift / VIP | [clean_swift_vip.md](clean_swift_vip.md) | Unidirectional brenda nje moduli, baze e Clean Architecture |
| Clean Architecture | [clean_architecture.md](clean_architecture.md) | App komplekse me shtresa te qarta domain/data |
| TCA | [tca.md](tca.md) | SwiftUI moderne me state-driven navigation dhe DI te forte |
| Unidirectional / Redux | [unidirectional.md](unidirectional.md) | Pasqyrim i pergjithshem i ides, jo TCA specifike |
| MV + @Observable | [mv_observable.md](mv_observable.md) | SwiftUI iOS 17+, Apple-recommended sot |

### Si ta zgjedhesh

Mos zgjidh modelin nga moda. Zgjidh nga kufijte:

1. **App e re, ekip i vogel, SwiftUI 17+**: MV me `@Observable`. Fillo te thjeshte, zgjero kur ke arsye.
2. **App e re, ekip i vogel, SwiftUI dhe Combine**: MVVM klasik.
3. **App e re, ekip mesatar, deshironi testueshmeri dhe DI te forte**: TCA.
4. **Kodbaze ekzistuese UIKit me coordinator**: MVVM-C, mos ndrysho per hir te ndryshimit.
5. **Ekip i madh, ndarje shume strikte rolesh, UIKit**: VIPER.
6. **Pjese e madhe biznes-logjike me rregulla komplekse**: Clean Architecture me shtresa (UI + Domain + Data).
7. **Nje screen me hapa te qarte input -> output**: Clean Swift / VIP.

### Rregull i arte
Pa miksuar tre modele ne te njejtin modul. Brenda nje feature, vendos nje pattern dhe respektoje. Midis feature-ve, mund te ndryshoje vetem nese ekipi e ka dakorduar.

---

## English

This folder holds the main iOS architecture patterns used today. Each file describes the pattern, when to choose it, its minimal Swift shape, and anti-patterns to avoid.

### Patterns covered

| Pattern | File | Typical context |
|---|---|---|
| MVVM | [mvvm.md](mvvm.md) | SwiftUI + Combine, small to mid teams |
| MVVM-C | [mvvm_c.md](mvvm_c.md) | UIKit with coordinator for navigation |
| VIPER | [viper.md](viper.md) | Large UIKit teams, strict role separation |
| Clean Swift / VIP | [clean_swift_vip.md](clean_swift_vip.md) | Unidirectional inside a module, base of Clean Architecture |
| Clean Architecture | [clean_architecture.md](clean_architecture.md) | Complex apps with clear domain/data layers |
| TCA | [tca.md](tca.md) | Modern SwiftUI with state-driven navigation and strong DI |
| Unidirectional / Redux | [unidirectional.md](unidirectional.md) | General overview of the idea, not TCA-specific |
| MV + @Observable | [mv_observable.md](mv_observable.md) | SwiftUI iOS 17+, Apple-recommended today |

### How to choose

Do not pick a pattern by fashion. Pick by constraints:

1. **New app, small team, SwiftUI 17+**: MV with `@Observable`. Start simple, grow when you have reasons.
2. **New app, small team, SwiftUI and Combine**: classic MVVM.
3. **New app, mid team, you want testability and strong DI**: TCA.
4. **Existing UIKit codebase with coordinator**: MVVM-C, do not change for the sake of changing.
5. **Large team, very strict role separation, UIKit**: VIPER.
6. **Large slice of business logic with complex rules**: Clean Architecture with layers (UI + Domain + Data).
7. **One screen with clear input -> output steps**: Clean Swift / VIP.

### Golden rule
Do not mix three patterns inside the same module. Inside a feature, settle on one pattern and respect it. Across features it can differ, only if the team agreed to it.
