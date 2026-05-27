# Navigim / Navigation

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Modeli i preferuar
1. **SwiftUI NavigationStack me path**: per app SwiftUI, perdor `NavigationStack(path:)` me enum destinations ose state te tipizuar.
2. **TCA me state**: `StackState<Path.State>` per push, `@Presents` per modal. I parashikueshem dhe i testueshem kur app-i eshte TCA.
3. **UIKit coordinator ose router**: per MVVM-C, VIPER, RIBs dhe kodbaza UIKit qe e perdorin tashme.
4. **Router domain-specific**: per deep links komplekse, mbaje perkthimin URL -> destination ne nje vend.

### Deep links
- Resolve ne nje vend te vetem (app-level router, root reducer, coordinator ose deep-link handler).
- Shndrro URL-ne ne destination te tipizuar, `Action`, `Path.State` ose route command, pastaj lere navigimin te ndodhe normalisht.
- Mos beje navigim imperativ ne mes te app-it nga handler-i i URL-se.

### Modal vs push
- Modal kur task-u eshte "side quest" (modifiko nje gje, mbyll dhe kthehu).
- Push kur task-u eshte vazhdim hierarkik i kontekstit.
- Pa modal mbi modal mbi modal. Nese te duhet 3 nivele, kerkesa ka nevoje te ridizajnohet.

### Back navigation
- `NavigationStack` e ka native. Pa "popToRoot" buton manuale.
- Per UIKit, perdor `navigationController?.popViewController(animated:)` jo dismiss.

---

## English

### Preferred model
1. **SwiftUI NavigationStack with path**: for SwiftUI apps, use `NavigationStack(path:)` with enum destinations or typed state.
2. **TCA with state**: `StackState<Path.State>` for push, `@Presents` for modal. Predictable and testable when the app is TCA.
3. **UIKit coordinator or router**: for MVVM-C, VIPER, RIBs, and UIKit codebases that already use it.
4. **Domain-specific router**: for complex deep links, keep URL -> destination translation in one place.

### Deep links
- Resolve in one place (app-level router, root reducer, coordinator, or deep-link handler).
- Translate the URL into a typed destination, `Action`, `Path.State`, or route command, then let navigation happen normally.
- Do not do imperative navigation from the URL handler in the middle of the app.

### Modal vs push
- Modal when the task is a "side quest" (edit one thing, dismiss, return).
- Push when the task is a hierarchical continuation of context.
- No modal-on-modal-on-modal. If you need 3 levels, the requirement needs a redesign.

### Back navigation
- `NavigationStack` handles it natively. No manual "popToRoot" button.
- For UIKit, use `navigationController?.popViewController(animated:)`, not dismiss.
