# ReactorKit / ReactorKit

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

ReactorKit eshte arkitekture reaktive per iOS, e ndertuar zakonisht mbi
RxSwift. Cdo ekran ka nje **Reactor** qe merr `Action`, prodhon `Mutation`,
dhe ekspozon `State`.

### Roli i secilit

- **View**: lidh UI events me `Action` dhe renderon `State`.
- **Reactor**: transformon `Action -> Observable<Mutation> -> State`.
- **State**: burimi i vetem per gjendjen e ekranit.

### Forma minimale

```swift
final class UsersReactor: Reactor {
    enum Action {
        case refresh
    }

    enum Mutation {
        case setLoading(Bool)
        case setUsers([User])
    }

    struct State {
        var isLoading = false
        var users: [User] = []
    }

    let initialState = State()
    private let api: UsersAPI

    init(api: UsersAPI) {
        self.api = api
    }

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .refresh:
            return Observable.concat([
                .just(.setLoading(true)),
                api.fetchUsers().map(Mutation.setUsers),
                .just(.setLoading(false))
            ])
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setUsers(let users):
            state.users = users
        }
        return state
    }
}
```

### Kur ta perdoresh

- Kodbaze RxSwift ku unidirectional state eshte standardi i ekipit.
- Screen-e me shume input-e reaktive.
- Ekip qe e kupton mire Rx dhe testimin me scheduler.

### Kur mos ta perdoresh

- App Swift Concurrency-first pa RxSwift.
- Ekip qe nuk ka ekspertize Rx.
- Feature i vogel ku MV ose MVVM eshte me i qarte.

### Anti-pattern

- Side effects ne `reduce`.
- State i ndare ne disa burime jashtë Reactor-it.
- Lidhje UI qe modifikon state direkt.

---

## English

ReactorKit is a reactive architecture for iOS, usually built on RxSwift. Each
screen has a **Reactor** that receives `Action`, produces `Mutation`, and
exposes `State`.

### Roles

- **View**: binds UI events to `Action` and renders `State`.
- **Reactor**: transforms `Action -> Observable<Mutation> -> State`.
- **State**: the single source for screen state.

### Minimal shape

```swift
final class UsersReactor: Reactor {
    enum Action {
        case refresh
    }

    enum Mutation {
        case setLoading(Bool)
        case setUsers([User])
    }

    struct State {
        var isLoading = false
        var users: [User] = []
    }

    let initialState = State()
    private let api: UsersAPI

    init(api: UsersAPI) {
        self.api = api
    }

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .refresh:
            return Observable.concat([
                .just(.setLoading(true)),
                api.fetchUsers().map(Mutation.setUsers),
                .just(.setLoading(false))
            ])
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setUsers(let users):
            state.users = users
        }
        return state
    }
}
```

### When to use

- RxSwift codebase where unidirectional state is the team standard.
- Screens with many reactive inputs.
- Team that understands Rx and scheduler-based testing well.

### When not to use

- Swift Concurrency-first app without RxSwift.
- Team without Rx expertise.
- Small feature where MV or MVVM is clearer.

### Anti-patterns

- Side effects in `reduce`.
- State split across sources outside the Reactor.
- UI binding that mutates state directly.
