# MVVM-C / MVVM-C

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

MVVM-C eshte MVVM plus **Coordinator** qe heq navigimin nga View dhe ViewModel.

### Roli i secilit
- **Model, View, ViewModel**: si te MVVM (shih [mvvm.md](mvvm.md)).
- **Coordinator**: di si te kalosh nga nje ekran te tjetri, instalon `UINavigationController`-at, lidhin ViewModel-et me View.

### Forma minimale (UIKit)

```swift
protocol UsersCoordinatorDelegate: AnyObject {
    func usersCoordinatorDidSelect(user: User)
}

final class UsersCoordinator {
    private let navigationController: UINavigationController
    private let factory: UsersFactory
    weak var delegate: UsersCoordinatorDelegate?

    init(navigationController: UINavigationController, factory: UsersFactory) {
        self.navigationController = navigationController
        self.factory = factory
    }

    func start() {
        let viewModel = factory.makeUsersViewModel(onSelect: { [weak self] user in
            self?.showDetail(user: user)
        })
        let viewController = UsersViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: false)
    }

    private func showDetail(user: User) {
        let detailVC = factory.makeUserDetailViewController(user: user)
        navigationController.pushViewController(detailVC, animated: true)
    }
}
```

### Rregulla
- ViewModel **nuk e di** se cfare ndodh pas. E shpall me closure: `onSelect`, `onFinish`.
- Coordinator e di si funksionin `UINavigationController`, View jo.
- **Child coordinators** per flow te medha. Parent injekton child me factory.

### Kur ta perdoresh
- Kodbaze UIKit ekzistuese qe e perdor tashme.
- Flows komplekse navigimi (modal mbi push mbi modal).
- Ekipe qe duan ndarje strikte: nje person bben ViewModel, nje tjeter bben Coordinator.

### Anti-pattern
- Coordinator gjigant qe di gjithe app-in. Ndaje ne child coordinators.
- Reference te forta cikleore: Coordinator -> ViewModel -> Coordinator. Perdor `weak` ose closure capture me kujdes.
- Coordinator qe ben business logic. Ai vetem rrugezon.

### Testimi
- ViewModel: si MVVM.
- Coordinator: testet integrim me factory fake, asserto qe kerkesat e navigimit ndodhin.

---

## English

MVVM-C is MVVM plus a **Coordinator** that takes navigation out of the View and ViewModel.

### Roles
- **Model, View, ViewModel**: same as MVVM (see [mvvm.md](mvvm.md)).
- **Coordinator**: knows how to move from one screen to the next, installs `UINavigationController`s, wires ViewModels to Views.

### Minimal shape (UIKit)

```swift
protocol UsersCoordinatorDelegate: AnyObject {
    func usersCoordinatorDidSelect(user: User)
}

final class UsersCoordinator {
    private let navigationController: UINavigationController
    private let factory: UsersFactory
    weak var delegate: UsersCoordinatorDelegate?

    init(navigationController: UINavigationController, factory: UsersFactory) {
        self.navigationController = navigationController
        self.factory = factory
    }

    func start() {
        let viewModel = factory.makeUsersViewModel(onSelect: { [weak self] user in
            self?.showDetail(user: user)
        })
        let viewController = UsersViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: false)
    }

    private func showDetail(user: User) {
        let detailVC = factory.makeUserDetailViewController(user: user)
        navigationController.pushViewController(detailVC, animated: true)
    }
}
```

### Rules
- ViewModel **does not know** what comes next. It announces it through a closure: `onSelect`, `onFinish`.
- Coordinator knows `UINavigationController`, the View does not.
- **Child coordinators** for large flows. Parent injects the child via a factory.

### When to use
- Existing UIKit codebase that already uses it.
- Complex navigation flows (modal over push over modal).
- Teams that want strict separation: one person owns the ViewModel, another the Coordinator.

### Anti-patterns
- A giant Coordinator that knows the whole app. Split into child coordinators.
- Strong reference cycles: Coordinator -> ViewModel -> Coordinator. Use `weak` or careful closure capture.
- Coordinator doing business logic. It only routes.

### Testing
- ViewModel: same as MVVM.
- Coordinator: integration tests with a fake factory, assert that navigation calls happen.
