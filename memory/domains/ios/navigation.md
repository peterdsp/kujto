# Navigim / Navigation

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Modeli i preferuar
1. **TCA me state**: `StackState<Path.State>` per push, `@Presents` per modal. I parashikueshem dhe i testueshem.
2. **SwiftUI NavigationStack me path**: per app pa TCA, perdor `NavigationStack(path:)` me enum destinations.
3. **UIKit coordinator**: vetem ne kodbaza ekzistuese qe e perdorin tashme. Mos i shtosh coordinator te ri kur ke alternative.

### Deep links
- Resolve ne nje vend te vetem (reducer kryesor ose app-level router).
- Shndrro URL-ne ne `Action` ose `Path.State`, pastaj lere navigimin te ndodhe normalisht.
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
1. **TCA with state**: `StackState<Path.State>` for push, `@Presents` for modal. Predictable and testable.
2. **SwiftUI NavigationStack with path**: for non-TCA apps, use `NavigationStack(path:)` with enum destinations.
3. **UIKit coordinator**: only in existing codebases that already use it. Do not add new coordinators when you have an alternative.

### Deep links
- Resolve in one place (root reducer or app-level router).
- Translate the URL into an `Action` or `Path.State`, then let navigation happen normally.
- Do not do imperative navigation from the URL handler in the middle of the app.

### Modal vs push
- Modal when the task is a "side quest" (edit one thing, dismiss, return).
- Push when the task is a hierarchical continuation of context.
- No modal-on-modal-on-modal. If you need 3 levels, the requirement needs a redesign.

### Back navigation
- `NavigationStack` handles it natively. No manual "popToRoot" button.
- For UIKit, use `navigationController?.popViewController(animated:)`, not dismiss.
