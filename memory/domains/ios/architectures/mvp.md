# MVP / MVP

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

MVP ndan ekranin ne **Model, View, Presenter**. View eshte pasive dhe i
delegon input-et Presenter-it. Presenter merr te dhena, vendos cfare duhet
shfaqur, dhe therrret metoda te thjeshta ne View.

### Roli i secilit

- **Model**: entity, service ose repository pa UI.
- **View**: `UIViewController` ose `UIView`, sa me pasive.
- **Presenter**: logjika e prezantimit, formatimi, state-i i ekranit dhe
  komandat per View.

### Forma minimale

```swift
protocol UsersView: AnyObject {
    func showLoading()
    func show(users: [UserRow])
    func showError(_ message: String)
}

final class UsersPresenter {
    private weak var view: UsersView?
    private let api: UsersAPI

    init(view: UsersView, api: UsersAPI) {
        self.view = view
        self.api = api
    }

    func viewDidLoad() {
        view?.showLoading()
        Task {
            do {
                let users = try await api.fetch()
                await MainActor.run {
                    view?.show(users: users.map(UserRow.init))
                }
            } catch {
                await MainActor.run {
                    view?.showError(error.localizedDescription)
                }
            }
        }
    }
}
```

### Kur ta perdoresh

- UIKit ku do testim te Presenter-it pa UI.
- Kodbaze legacy ku MVVM do ishte ndryshim me i madh.
- Screen me shume formatting dhe pak state te ndare.

### Anti-pattern

- View qe merr vendime biznesi.
- Presenter qe di per `UILabel`, `UITableView` ose layout.
- Presenter shume i madh qe duhet te ndahet ne sub-presenters ose use cases.

---

## English

MVP splits the screen into **Model, View, Presenter**. The View is passive and
delegates inputs to the Presenter. The Presenter fetches data, decides what
should be displayed, and calls simple methods on the View.

### Roles

- **Model**: entity, service, or repository without UI.
- **View**: `UIViewController` or `UIView`, as passive as possible.
- **Presenter**: presentation logic, formatting, screen state, and commands for
  the View.

### Minimal shape

```swift
protocol UsersView: AnyObject {
    func showLoading()
    func show(users: [UserRow])
    func showError(_ message: String)
}

final class UsersPresenter {
    private weak var view: UsersView?
    private let api: UsersAPI

    init(view: UsersView, api: UsersAPI) {
        self.view = view
        self.api = api
    }

    func viewDidLoad() {
        view?.showLoading()
        Task {
            do {
                let users = try await api.fetch()
                await MainActor.run {
                    view?.show(users: users.map(UserRow.init))
                }
            } catch {
                await MainActor.run {
                    view?.showError(error.localizedDescription)
                }
            }
        }
    }
}
```

### When to use

- UIKit where you want Presenter tests without UI.
- Legacy codebase where MVVM would be a larger change.
- Screen with lots of formatting and little shared state.

### Anti-patterns

- View making business decisions.
- Presenter knowing about `UILabel`, `UITableView`, or layout.
- Presenter too large and needing sub-presenters or use cases.
