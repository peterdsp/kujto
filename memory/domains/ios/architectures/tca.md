---
applies_to:
  - "**/*Reducer.swift"
  - "**/*Feature.swift"
  - "**/*Store.swift"
---

# TCA (The Composable Architecture) / TCA (The Composable Architecture)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

TCA eshte arkitekturë state-driven nga Point-Free, e ndertuar mbi reducers, actions, dhe Effects. Composition, DI dhe testueshmeria jane shtylla primare.

### Forma e nje reducer-i
- `State`: vlere, `Equatable`. Pa referenca te bartura.
- `Action`: enum me case-e te qarta. Pa "do everything" action.
- `Reducer`: pure. Side effects vetem permes `Effect`.

```swift
@Reducer
struct UsersFeature {
    @ObservableState
    struct State: Equatable {
        var users: [User] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case onAppear
        case usersResponse(Result<[User], EquatableError>)
        case userTapped(User.ID)
    }

    @Dependency(\.usersAPI) var api

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.usersResponse(Result {
                        try await api.fetch()
                    }.mapError(EquatableError.init)))
                }

            case let .usersResponse(.success(users)):
                state.isLoading = false
                state.users = users
                return .none

            case let .usersResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none

            case .userTapped:
                return .none
            }
        }
    }
}
```

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

### Kur ta perdoresh
- App SwiftUI moderne me state-driven navigation.
- Kerkohet test coverage e larte e logjikes (TCA me TestStore eshte unik).
- Ekip qe ka kohe per kurben e nxenies.

### Kur **mos** ta perdoresh
- App e thjeshte ku MVVM mbulon cdo gje.
- Ekip qe nuk e ka perdorur me pare dhe duhet te dergoje ne 2 jave.

### Anti-pattern
- Side effect direkt ne `reduce`. Perdor `Effect.run`.
- `Equatable` permes `==` te shkruar me dore kur kompajleri mund ta sintetizoje.
- Action-e qe transmetojne state-in e plote, perkundrazi i thuaj reducer-it "cfare ndodhi", jo "cfare te shfaqesh".

---

## English

TCA is a state-driven architecture from Point-Free, built on reducers, actions, and Effects. Composition, DI, and testability are primary pillars.

### Reducer shape
- `State`: value, `Equatable`. No carried references.
- `Action`: enum with clear cases. No "do everything" action.
- `Reducer`: pure. Side effects only via `Effect`.

```swift
@Reducer
struct UsersFeature {
    @ObservableState
    struct State: Equatable {
        var users: [User] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case onAppear
        case usersResponse(Result<[User], EquatableError>)
        case userTapped(User.ID)
    }

    @Dependency(\.usersAPI) var api

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.usersResponse(Result {
                        try await api.fetch()
                    }.mapError(EquatableError.init)))
                }

            case let .usersResponse(.success(users)):
                state.isLoading = false
                state.users = users
                return .none

            case let .usersResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none

            case .userTapped:
                return .none
            }
        }
    }
}
```

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

### When to use
- Modern SwiftUI app with state-driven navigation.
- High test coverage required (TCA with TestStore is unique).
- Team that has time for the learning curve.

### When **not** to use
- A simple app where MVVM covers everything.
- Team that has never used it and must ship in 2 weeks.

### Anti-patterns
- Side effect directly in `reduce`. Use `Effect.run`.
- Hand-written `Equatable` via `==` when the compiler can synthesize it.
- Actions that broadcast full state, instead tell the reducer "what happened", not "what to show".
