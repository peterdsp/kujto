# Modele TCA / TCA patterns

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Forma e nje reducer-i
- `State`: vlere, `Equatable`. Pa referenca te bartura.
- `Action`: enum me case-e te qarta. Pa "do everything" action.
- `Reducer`: pure. Side effects vetem permes `Effect`.

### Varesite (DI)
- Perdor `@Dependency` per cdo gje qe prek I/O ose oren.
- Cdo varesi duhet te kete `liveValue`, `testValue` dhe (ne shumicen e rasteve) `previewValue`.
- Pa singletons globale ne reducer.

### Navigimi
- Navigim me state, jo me coordinator te jashtem.
- `@Presents` per modal, `StackState<Path.State>` per stack push.
- Deep link-et zgjidhen ne reducer, jo ne view.

### Composition
- Reducer i madh => `Scope` per fusha, `forEach` per koleksione.
- Mos krijo "feature reducer" qe njeh detajet e childit. Definimi me i mire eshte: child eksporton vetem ate qe parent-i ka nevoje.

### Anti-pattern
- Side effect direkt ne `reduce`. Perdor `Effect.run`.
- `Equatable` permes `==` te shkruar me dore kur kompajleri mund ta sintetizoje.
- Action-e qe transmetojne state-in e plote, perkundrazi i thuaj reducer-it "cfare ndodhi", jo "cfare te shfaqesh".

---

## English

### Reducer shape
- `State`: value, `Equatable`. No carried references.
- `Action`: enum with clear cases. No "do everything" action.
- `Reducer`: pure. Side effects only via `Effect`.

### Dependencies (DI)
- Use `@Dependency` for anything touching I/O or the clock.
- Every dependency must have `liveValue`, `testValue`, and (in most cases) `previewValue`.
- No global singletons inside reducers.

### Navigation
- State-driven navigation, not external coordinator.
- `@Presents` for modal, `StackState<Path.State>` for stack push.
- Deep links resolve in the reducer, not in the view.

### Composition
- Big reducer => `Scope` for sub-domains, `forEach` for collections.
- Do not build a "feature reducer" that knows the child's internals. The better definition: the child exports only what the parent needs.

### Anti-patterns
- Side effect directly in `reduce`. Use `Effect.run`.
- Hand-written `Equatable` via `==` when the compiler can synthesize it.
- Actions that broadcast full state, instead tell the reducer "what happened", not "what to show".
