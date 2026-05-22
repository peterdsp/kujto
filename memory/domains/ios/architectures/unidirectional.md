# Unidirectional / Redux / Unidirectional / Redux

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Unidirectional / Redux eshte familja e arkitekturave ku state-i eshte **i palevizshem dhe i centralizuar**, dhe ndryshohet vetem permes **action-eve** te kaluara nepermjet **reducer-ave**. TCA eshte nje implementim specifik. ReSwift eshte nje tjeter. Edhe ne kode VanillaSwift mund te beje nje implementim.

### Kontratat themelore
- **State**: nje vlere e palevizshme.
- **Action**: nje deklarate "kjo ndodhi". Pa "kjo te beje".
- **Reducer**: `(State, Action) -> State`. Pure.
- **Store**: koordinator qe mban state-in dhe send-on Action-e.
- **Side Effects**: trajtohen jashte reducer-it (middleware, Effect, Saga).

### Forma minimale "vanilla"

```swift
struct AppState: Equatable {
    var users: [User] = []
    var isLoading = false
}

enum AppAction: Equatable {
    case fetchUsersStarted
    case fetchUsersSucceeded([User])
    case fetchUsersFailed
}

func reduce(_ state: AppState, _ action: AppAction) -> AppState {
    var state = state
    switch action {
    case .fetchUsersStarted: state.isLoading = true
    case .fetchUsersSucceeded(let users):
        state.isLoading = false
        state.users = users
    case .fetchUsersFailed:
        state.isLoading = false
    }
    return state
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var state = AppState()
    private let api: UsersAPI

    init(api: UsersAPI) { self.api = api }

    func send(_ action: AppAction) {
        state = reduce(state, action)
        if case .fetchUsersStarted = action {
            Task {
                if let users = try? await api.fetch() {
                    self.send(.fetchUsersSucceeded(users))
                } else {
                    self.send(.fetchUsersFailed)
                }
            }
        }
    }
}
```

### Avantazhet
- **Time travel debugging**: kursehet historia e action-eve, mund ta zhvendosesh state-in.
- **Testueshmeri**: cdo reducer eshte pure.
- **Modeli mendor i thjeshte**: te dhenat rrjedhin nje drejtim.

### Kostot
- **Boilerplate**: shume kod per nje rast te thjeshte.
- **Side effects** behen te perziera kur s'ke mire-orkestrim (middleware, Effect, Combine).
- **Kurba e nxenies**: ekipi e ka me te veshtire ne fillim.

### Kur ta perdoresh
- App me state global ku shume komponente shohin te njejten gjendje.
- Kerkohet shfaqje konsistente e te dhenave neper ekrane.
- Test coverage shume e larte.

### Kur **mos** ta perdoresh
- Screen i izoluar pa state global. MVVM eshte i mjaftueshem.

### Krahasim me TCA
- TCA = Unidirectional + Composition + DI + Navigation + Test ergonomics. Eshte mbledhja e plote.
- ReSwift eshte mbeshtjellja klasike Redux per Swift, me me pak ergonomi.

### Anti-pattern
- Reducer qe ben asgje, gjithcka ne middleware.
- Action-e me payload gjigant qe pasqyrojne kombinime UI.
- "Global state" qe mban edhe state efemer te UI-se (`isSheetShown` per cdo ekran).

---

## English

Unidirectional / Redux is the family of architectures where state is **immutable and centralized**, mutated only through **actions** passed through **reducers**. TCA is one specific implementation. ReSwift is another. Even vanilla Swift can implement one.

### Core contracts
- **State**: an immutable value.
- **Action**: a "this happened" declaration. Not "do this".
- **Reducer**: `(State, Action) -> State`. Pure.
- **Store**: coordinator that holds the state and sends Actions.
- **Side Effects**: handled outside the reducer (middleware, Effect, Saga).

### Minimal "vanilla" shape

```swift
struct AppState: Equatable {
    var users: [User] = []
    var isLoading = false
}

enum AppAction: Equatable {
    case fetchUsersStarted
    case fetchUsersSucceeded([User])
    case fetchUsersFailed
}

func reduce(_ state: AppState, _ action: AppAction) -> AppState {
    var state = state
    switch action {
    case .fetchUsersStarted: state.isLoading = true
    case .fetchUsersSucceeded(let users):
        state.isLoading = false
        state.users = users
    case .fetchUsersFailed:
        state.isLoading = false
    }
    return state
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var state = AppState()
    private let api: UsersAPI

    init(api: UsersAPI) { self.api = api }

    func send(_ action: AppAction) {
        state = reduce(state, action)
        if case .fetchUsersStarted = action {
            Task {
                if let users = try? await api.fetch() {
                    self.send(.fetchUsersSucceeded(users))
                } else {
                    self.send(.fetchUsersFailed)
                }
            }
        }
    }
}
```

### Benefits
- **Time travel debugging**: action history is preserved, state can be replayed.
- **Testability**: every reducer is pure.
- **Simple mental model**: data flows one way.

### Costs
- **Boilerplate**: lots of code for simple cases.
- **Side effects** get messy without good orchestration (middleware, Effect, Combine).
- **Learning curve**: harder for the team at first.

### When to use
- App with global state where many components see the same data.
- Consistent rendering across screens is required.
- Very high test coverage is needed.

### When **not** to use
- Isolated screen with no global state. MVVM is enough.

### Comparison with TCA
- TCA = Unidirectional + Composition + DI + Navigation + Test ergonomics. The full package.
- ReSwift is the classic Redux wrapper for Swift, less ergonomic.

### Anti-patterns
- A reducer that does nothing, all work in middleware.
- Huge-payload actions that mirror UI combinations.
- "Global state" that also holds ephemeral UI state (`isSheetShown` for every screen).
