# Clean Architecture / Clean Architecture

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Clean Architecture (Uncle Bob) eshte nje **pakete shtresash koncentrike**, ku rregulli i varesise eshte: shtresat e jashtme i njohin ato te brendshme, kurre e kunderta.

### Shtresat (nga jashte brenda)
1. **UI / Frameworks** (SwiftUI, UIKit, Combine, URLSession).
2. **Interface adapters** (Presenter, ViewModel, ViewController, Repository implementations).
3. **Use Cases** (business rules specifike per app-in).
4. **Entities** (rregullat me te thella te biznesit, te pavarura nga app-i).

### Rregulli i varesise
```
UI -> Adapters -> Use Cases -> Entities
```

Brenda nuk di per jashte. `User` (Entity) nuk e di se ekziston `UsersViewModel`.

### Forma minimale (SPM modules)

```
App/
├── Domain/                  pa varesi te jashtme
│   ├── Entities/User.swift
│   └── UseCases/FetchUsersUseCase.swift
├── Data/                    varet vetem nga Domain
│   ├── Repositories/UsersRepositoryImpl.swift
│   └── Network/UsersAPI.swift
├── Presentation/            varet nga Domain
│   ├── UsersViewModel.swift
│   └── UsersView.swift
└── App/                     wires everything
    └── DIContainer.swift
```

```swift
// Domain
public struct User: Equatable {
    public let id: String
    public let name: String
}

public protocol UsersRepository {
    func fetch() async throws -> [User]
}

public struct FetchUsersUseCase {
    let repository: UsersRepository
    public init(repository: UsersRepository) { self.repository = repository }

    public func callAsFunction() async throws -> [User] {
        try await repository.fetch()
    }
}

// Data
public final class UsersRepositoryImpl: UsersRepository {
    private let api: UsersAPI
    public init(api: UsersAPI) { self.api = api }

    public func fetch() async throws -> [User] {
        let dtos = try await api.fetchUserDTOs()
        return dtos.map { User(id: $0.id, name: $0.fullName) }
    }
}

// Presentation
@MainActor
public final class UsersViewModel: ObservableObject {
    @Published public private(set) var users: [User] = []
    private let fetchUsers: FetchUsersUseCase

    public init(fetchUsers: FetchUsersUseCase) { self.fetchUsers = fetchUsers }

    public func onAppear() async {
        users = (try? await fetchUsers()) ?? []
    }
}
```

### Rregulla
- **Entities** jane value types, pa varesi.
- **Use Case** ka nje detyre. Nje "verb" per use case.
- **Repository** eshte interface (protokoll) ne Domain, **implementation** ne Data.
- **Mapping** ndodh ne Data (DTO -> Entity), jo ne Presentation.

### Kur ta perdoresh
- App me business logic kompleks (banka, e-commerce, fintech).
- Ekipe me dev qe i nderrojne layer-at e tyre.
- Kur app-i ka source-e te ndryshme (REST + GraphQL + Cache + Realm) per te njejtin tip te dhene.

### Kur **mos** ta perdoresh
- CRUD i thjeshte mbi REST. Shtresat sjellin kosto pa perfitim.
- Prototip. Bej me direkt; refactor me vone.

### Anti-pattern
- Use Case qe permban kerkesa rrjeti direkt. Use Case-i flet vetem me Repository.
- Mapping ne View. Nese ViewModel-i transformon DTO-te, Data-shtresa nuk po e ben punen e vet.
- Repository qe varet nga UIKit ose SwiftUI.

### Kombinime
- **Clean + MVVM**: e zakonshme ne SwiftUI moderne.
- **Clean + VIP**: ne UIKit.
- **Clean + TCA**: Use Cases injektuar si `@Dependency` ne reducer.

---

## English

Clean Architecture (Uncle Bob) is a **set of concentric layers** where the dependency rule is: outer layers know about inner layers, never the reverse.

### Layers (outside in)
1. **UI / Frameworks** (SwiftUI, UIKit, Combine, URLSession).
2. **Interface adapters** (Presenters, ViewModels, ViewControllers, Repository implementations).
3. **Use Cases** (app-specific business rules).
4. **Entities** (deepest business rules, app-independent).

### Dependency rule
```
UI -> Adapters -> Use Cases -> Entities
```

Inner does not know outer. `User` (Entity) has no idea `UsersViewModel` exists.

### Minimal shape (SPM modules)

```
App/
├── Domain/                  no external dependencies
│   ├── Entities/User.swift
│   └── UseCases/FetchUsersUseCase.swift
├── Data/                    depends only on Domain
│   ├── Repositories/UsersRepositoryImpl.swift
│   └── Network/UsersAPI.swift
├── Presentation/            depends on Domain
│   ├── UsersViewModel.swift
│   └── UsersView.swift
└── App/                     wires everything
    └── DIContainer.swift
```

```swift
// Domain
public struct User: Equatable {
    public let id: String
    public let name: String
}

public protocol UsersRepository {
    func fetch() async throws -> [User]
}

public struct FetchUsersUseCase {
    let repository: UsersRepository
    public init(repository: UsersRepository) { self.repository = repository }

    public func callAsFunction() async throws -> [User] {
        try await repository.fetch()
    }
}

// Data
public final class UsersRepositoryImpl: UsersRepository {
    private let api: UsersAPI
    public init(api: UsersAPI) { self.api = api }

    public func fetch() async throws -> [User] {
        let dtos = try await api.fetchUserDTOs()
        return dtos.map { User(id: $0.id, name: $0.fullName) }
    }
}

// Presentation
@MainActor
public final class UsersViewModel: ObservableObject {
    @Published public private(set) var users: [User] = []
    private let fetchUsers: FetchUsersUseCase

    public init(fetchUsers: FetchUsersUseCase) { self.fetchUsers = fetchUsers }

    public func onAppear() async {
        users = (try? await fetchUsers()) ?? []
    }
}
```

### Rules
- **Entities** are value types, no dependencies.
- **Use Case** has one job. One verb per use case.
- **Repository** is an interface (protocol) in Domain, with an **implementation** in Data.
- **Mapping** happens in Data (DTO -> Entity), not in Presentation.

### When to use
- Apps with complex business logic (banking, e-commerce, fintech).
- Teams where devs rotate across layers.
- When the app has multiple sources (REST + GraphQL + Cache + Realm) for the same data type.

### When **not** to use
- Simple REST CRUD. The layers cost without paying off.
- Prototype. Build it directly, refactor later.

### Anti-patterns
- A Use Case making network calls directly. Use Cases talk only to Repositories.
- Mapping in the View. If the ViewModel transforms DTOs, the Data layer is not doing its job.
- A Repository that depends on UIKit or SwiftUI.

### Combinations
- **Clean + MVVM**: common in modern SwiftUI.
- **Clean + VIP**: in UIKit.
- **Clean + TCA**: Use Cases injected as `@Dependency` into reducers.
