# VIPER / VIPER

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

VIPER ndan nje feature ne pese role me ndarje strikte: **View, Interactor, Presenter, Entity, Router**.

### Roli i secilit
- **View**: UIViewController ose UIView, dummy. I delegon gjithcka Presenter-it.
- **Interactor**: business logic. Flet me Entity dhe shervimet (API, DB). Pa varesi UI.
- **Presenter**: dirigjent. Merr input nga View, kerkon te Interactor, formaton output per View.
- **Entity**: modeli i te dhenave. Pa logjike.
- **Router** (Wireframe): navigimi.

### Forma minimale (UIKit)

```swift
// Protocols (kontratat)
protocol UsersViewInput: AnyObject {
    func show(users: [UserViewModel])
    func showError(_ message: String)
}

protocol UsersViewOutput: AnyObject {
    func viewDidLoad()
    func didSelect(user: UserViewModel)
}

protocol UsersInteractorInput: AnyObject {
    func fetchUsers()
}

protocol UsersInteractorOutput: AnyObject {
    func didFetch(users: [User])
    func didFail(error: Error)
}

protocol UsersRouterInput: AnyObject {
    func showDetail(for user: User)
}

// View
final class UsersViewController: UIViewController, UsersViewInput {
    var presenter: UsersViewOutput!

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }

    func show(users: [UserViewModel]) { /* ... */ }
    func showError(_ message: String) { /* ... */ }
}

// Presenter
final class UsersPresenter: UsersViewOutput, UsersInteractorOutput {
    weak var view: UsersViewInput?
    var interactor: UsersInteractorInput!
    var router: UsersRouterInput!

    func viewDidLoad() {
        interactor.fetchUsers()
    }

    func didFetch(users: [User]) {
        view?.show(users: users.map(UserViewModel.init))
    }

    func didFail(error: Error) {
        view?.showError(error.localizedDescription)
    }

    func didSelect(user: UserViewModel) {
        router.showDetail(for: User(id: user.id, name: user.name))
    }
}
```

### Rregulla
- **Cdo flete e kupton komunikimin vetem permes protokolleve**. Pa kunder-varesi.
- View ka **referenca te forte** Presenter, Presenter ka **referenca te dobet** ne View.
- Router e merr `UIViewController` injektuar, instalon flow.

### Kur ta perdoresh
- Ekipe te medha (>10 dev iOS) ku ndarja strikte e roleve sjell qartesi.
- Kodbaze ku Code Review-ja kerkon kufij te qarte.
- Aplikacione me cikel jete te gjate ku rotacioni i ekipit eshte i larte.

### Kur **mos** ta perdoresh
- Ekip i vogel. Boilerplate-i te ngadhensohet me shume sec te ndihmon.
- App SwiftUI moderne. VIPER eshte UIKit-native; ne SwiftUI dukshmeria e tij eshte e debatueshme.
- Feature qe nuk ka kompleksitet biznes-logjik. Per nje screen 'show list', VIPER eshte over-engineered.

### Anti-pattern
- View qe importon Interactor direkt.
- Presenter qe ben rrjete (kjo eshte pune e Interactor).
- Router qe ben business logic.
- "Massive Presenter" me 1000 rreshta. Ndaje feature-n ne nen-feature.

### Testimi
- Cdo modul testohet ne izolim me dyfishe (mocks) per protokollet hyrese.
- Presenter eshte zona ku ndodh testimi me shume.

---

## English

VIPER splits a feature into five roles with strict separation: **View, Interactor, Presenter, Entity, Router**.

### Roles
- **View**: UIViewController or UIView, dumb. Delegates everything to the Presenter.
- **Interactor**: business logic. Talks to Entities and services (API, DB). No UI dependency.
- **Presenter**: conductor. Takes input from the View, asks the Interactor, formats output for the View.
- **Entity**: data model. No logic.
- **Router** (Wireframe): navigation.

### Minimal shape (UIKit)

```swift
// Protocols (contracts)
protocol UsersViewInput: AnyObject {
    func show(users: [UserViewModel])
    func showError(_ message: String)
}

protocol UsersViewOutput: AnyObject {
    func viewDidLoad()
    func didSelect(user: UserViewModel)
}

protocol UsersInteractorInput: AnyObject {
    func fetchUsers()
}

protocol UsersInteractorOutput: AnyObject {
    func didFetch(users: [User])
    func didFail(error: Error)
}

protocol UsersRouterInput: AnyObject {
    func showDetail(for user: User)
}

// View
final class UsersViewController: UIViewController, UsersViewInput {
    var presenter: UsersViewOutput!

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }

    func show(users: [UserViewModel]) { /* ... */ }
    func showError(_ message: String) { /* ... */ }
}

// Presenter
final class UsersPresenter: UsersViewOutput, UsersInteractorOutput {
    weak var view: UsersViewInput?
    var interactor: UsersInteractorInput!
    var router: UsersRouterInput!

    func viewDidLoad() {
        interactor.fetchUsers()
    }

    func didFetch(users: [User]) {
        view?.show(users: users.map(UserViewModel.init))
    }

    func didFail(error: Error) {
        view?.showError(error.localizedDescription)
    }

    func didSelect(user: UserViewModel) {
        router.showDetail(for: User(id: user.id, name: user.name))
    }
}
```

### Rules
- **Each layer talks only through protocols**. No back-dependencies.
- View has a **strong reference** to Presenter, Presenter has a **weak reference** to View.
- Router receives the `UIViewController` injected, installs the flow.

### When to use
- Large teams (10+ iOS devs) where strict role separation brings clarity.
- Codebases where Code Review demands clear boundaries.
- Long-lived applications with high team rotation.

### When **not** to use
- Small team. The boilerplate slows you down more than it helps.
- Modern SwiftUI app. VIPER is UIKit-native; in SwiftUI its value is debatable.
- Feature with no real business complexity. For a "show list" screen, VIPER is over-engineered.

### Anti-patterns
- View importing the Interactor directly.
- Presenter doing network calls (that is the Interactor's job).
- Router doing business logic.
- "Massive Presenter" with 1000 lines. Split the feature into sub-features.

### Testing
- Each module is tested in isolation with doubles (mocks) for inbound protocols.
- Presenter is where most tests live.
