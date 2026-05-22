# Konventat Swift / Swift conventions

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Emertimi
- `UpperCamelCase` per tipe, `lowerCamelCase` per properties dhe funksione.
- Funksionet duhet te lexohen si fjali ne piken e thirrjes.
- Pa shkurtime ambigue. `userIdentifier`, jo `usrID`.

### Strukturimi
- Nje tip per file kur file kalon ~200 rreshta.
- `MARK: -` per ndaresa logjike brenda file-ave me te medhenj.
- `private` si default, `internal` kur duhet, `public` vetem ne API biblioteke.

### Swift 6 dhe concurrency
- Adopto `Sendable` ku tipi e mban premtimin.
- Perdor `@MainActor` per UI-state, jo `DispatchQueue.main.async`.
- `async/await` mbi `completion: @escaping`.
- `actor` per gjendje te shperndare qe ka rrezik race-i.

### Stilemra
- 2 hapesira indentim (jo tabs).
- Pa `self.` te panevojshme.
- `guard let x = x` => `guard let x` (Swift 5.7+).

### Cfare te shmangesh
- Force unwrap (`!`) ne kod produksioni.
- Singletons globale per gjendje qe mund te injektohet.
- `@unchecked Sendable` pa koment qe shpjegon pse.

---

## English

### Naming
- `UpperCamelCase` for types, `lowerCamelCase` for properties and functions.
- Functions should read like a sentence at the call site.
- No ambiguous abbreviations. `userIdentifier`, not `usrID`.

### Structure
- One type per file once a file exceeds ~200 lines.
- `MARK: -` for logical sections inside larger files.
- `private` by default, `internal` when needed, `public` only in library APIs.

### Swift 6 and concurrency
- Adopt `Sendable` where the type holds its promise.
- Use `@MainActor` for UI state, not `DispatchQueue.main.async`.
- `async/await` over `completion: @escaping`.
- `actor` for shared state with race risk.

### Style
- 2-space indent (not tabs).
- No unnecessary `self.`.
- `guard let x = x` => `guard let x` (Swift 5.7+).

### Avoid
- Force unwrap (`!`) in production code.
- Global singletons for state that could be injected.
- `@unchecked Sendable` without a comment explaining why.
