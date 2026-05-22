# Clean Swift (VIP) / Clean Swift (VIP)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Clean Swift (i njohur edhe si **VIP**) eshte si VIPER pa Router, me **rrymetrim unidireksional** te qarte: View -> Interactor -> Presenter -> View.

### Cikli
1. **View** krijon **Request**.
2. **Interactor** e merr, perpunon, krijon **Response**.
3. **Presenter** e merr Response, krijon **ViewModel** (lloj-View).
4. **View** e shfaq.

### Forma minimale

```swift
// 1. Models per kete scene
enum Users {
    enum Fetch {
        struct Request {}
        struct Response {
            let users: [User]
            let error: Error?
        }
        struct ViewModel {
            struct DisplayUser: Equatable {
                let id: String
                let displayName: String
            }
            let users: [DisplayUser]
            let errorMessage: String?
        }
    }
}

// 2. Interactor
protocol UsersBusinessLogic {
    func fetch(request: Users.Fetch.Request)
}

final class UsersInteractor: UsersBusinessLogic {
    var presenter: UsersPresentationLogic?
    var worker: UsersAPI = LiveUsersAPI()

    func fetch(request: Users.Fetch.Request) {
        Task {
            do {
                let users = try await worker.fetch()
                presenter?.present(response: .init(users: users, error: nil))
            } catch {
                presenter?.present(response: .init(users: [], error: error))
            }
        }
    }
}

// 3. Presenter
protocol UsersPresentationLogic {
    func present(response: Users.Fetch.Response)
}

final class UsersPresenter: UsersPresentationLogic {
    weak var viewController: UsersDisplayLogic?

    func present(response: Users.Fetch.Response) {
        let viewModel = Users.Fetch.ViewModel(
            users: response.users.map { .init(id: $0.id, displayName: $0.name.uppercased()) },
            errorMessage: response.error?.localizedDescription
        )
        viewController?.display(viewModel: viewModel)
    }
}

// 4. View
protocol UsersDisplayLogic: AnyObject {
    func display(viewModel: Users.Fetch.ViewModel)
}

final class UsersViewController: UIViewController, UsersDisplayLogic {
    var interactor: UsersBusinessLogic?

    override func viewDidLoad() {
        super.viewDidLoad()
        interactor?.fetch(request: .init())
    }

    func display(viewModel: Users.Fetch.ViewModel) {
        // render
    }
}
```

### Rregulla
- **Cdo "scene" ka modelet e veta**: `Request`, `Response`, `ViewModel`. Pa shtyre tipe domain te paformatuar te View.
- **Drejtimi i te dhenes eshte unidireksional**. Pa View qe lexon direkt nga Interactor.
- **Presenter NUK ka logjike biznesi**. Vetem mapping.

### Kur ta perdoresh
- Screen me hapa te qarte input -> output.
- Ekipe qe duan strukture VIPER por pa boilerplate-in e Router-it.
- Si baze e Clean Architecture-s ne shtresen e prezantimit.

### Anti-pattern
- ViewModel qe permban tipet origjinale domain. Mapping-u eshte qellim, jo dekorativ.
- View qe ben kerkesa rrjeti. Vetem Interactor.
- Presenter qe nuk transformon. Nese Response = ViewModel, atehere VIP nuk po sjell vlere.

### Krahasim me VIPER
- VIP = VIPER pa Router. Navigimi behet jashte ose ne nje sub-component (Worker per nje task te vogel, ose Coordinator nese duhet).
- Me pak boilerplate, me pak fleksibel.

---

## English

Clean Swift (also called **VIP**) is like VIPER without a Router, with a clear **unidirectional flow**: View -> Interactor -> Presenter -> View.

### Cycle
1. **View** creates a **Request**.
2. **Interactor** takes it, processes, creates a **Response**.
3. **Presenter** takes the Response, creates a **ViewModel** (View-friendly type).
4. **View** displays it.

### Minimal shape

```swift
// 1. Models for this scene
enum Users {
    enum Fetch {
        struct Request {}
        struct Response {
            let users: [User]
            let error: Error?
        }
        struct ViewModel {
            struct DisplayUser: Equatable {
                let id: String
                let displayName: String
            }
            let users: [DisplayUser]
            let errorMessage: String?
        }
    }
}

// 2. Interactor
protocol UsersBusinessLogic {
    func fetch(request: Users.Fetch.Request)
}

final class UsersInteractor: UsersBusinessLogic {
    var presenter: UsersPresentationLogic?
    var worker: UsersAPI = LiveUsersAPI()

    func fetch(request: Users.Fetch.Request) {
        Task {
            do {
                let users = try await worker.fetch()
                presenter?.present(response: .init(users: users, error: nil))
            } catch {
                presenter?.present(response: .init(users: [], error: error))
            }
        }
    }
}

// 3. Presenter
protocol UsersPresentationLogic {
    func present(response: Users.Fetch.Response)
}

final class UsersPresenter: UsersPresentationLogic {
    weak var viewController: UsersDisplayLogic?

    func present(response: Users.Fetch.Response) {
        let viewModel = Users.Fetch.ViewModel(
            users: response.users.map { .init(id: $0.id, displayName: $0.name.uppercased()) },
            errorMessage: response.error?.localizedDescription
        )
        viewController?.display(viewModel: viewModel)
    }
}

// 4. View
protocol UsersDisplayLogic: AnyObject {
    func display(viewModel: Users.Fetch.ViewModel)
}

final class UsersViewController: UIViewController, UsersDisplayLogic {
    var interactor: UsersBusinessLogic?

    override func viewDidLoad() {
        super.viewDidLoad()
        interactor?.fetch(request: .init())
    }

    func display(viewModel: Users.Fetch.ViewModel) {
        // render
    }
}
```

### Rules
- **Each "scene" has its own models**: `Request`, `Response`, `ViewModel`. No pushing raw domain types into the View.
- **Data flow is unidirectional**. No View reading directly from the Interactor.
- **Presenter has NO business logic**. Only mapping.

### When to use
- Screen with clear input -> output steps.
- Teams that want VIPER's structure without the Router boilerplate.
- As the base of Clean Architecture in the presentation layer.

### Anti-patterns
- A ViewModel that carries raw domain types. Mapping is a feature, not decoration.
- View doing network calls. Only the Interactor does.
- A Presenter that does no transformation. If Response = ViewModel, then VIP is not earning its weight.

### Comparison with VIPER
- VIP = VIPER without the Router. Navigation is handled outside or in a sub-component (a Worker for a small task, or a Coordinator if needed).
- Less boilerplate, less flexible.
