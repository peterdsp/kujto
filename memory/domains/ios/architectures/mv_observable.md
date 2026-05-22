# MV + @Observable (SwiftUI iOS 17+) / MV + @Observable (SwiftUI iOS 17+)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Per SwiftUI iOS 17+, Apple rekomandon nje model me te thjeshte sec ka qene MVVM. Quhet **MV** (Model-View), me macro-n `@Observable` qe heq nevojen per `ObservableObject`, `@Published`, dhe `@StateObject`.

### Premisa
SwiftUI eshte tashme system reaktiv me state observimi i ngjitur. Nje **ViewModel-class si shtrese e dyte** shpesh duplikon ate qe `@Observable` model bben vete.

### Forma minimale

```swift
import Observation

@Observable
final class UsersModel {
    var users: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let api: UsersAPI

    init(api: UsersAPI) { self.api = api }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await api.fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UsersView: View {
    @State private var model: UsersModel

    init(api: UsersAPI) {
        _model = State(initialValue: UsersModel(api: api))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else if let error = model.errorMessage {
                Text(error).foregroundStyle(.red)
            } else {
                List(model.users) { Text($0.name) }
            }
        }
        .task { await model.load() }
    }
}
```

### Rregulla
- **`@Observable`** ne vend te `ObservableObject`.
- **`@State`** ne View per ta mbajtur, jo `@StateObject` (qe punon vetem me `ObservableObject`).
- Model rri **i thjeshte**. Pa "ViewModel" patenta. Eshte vetem nje class qe SwiftUI e observion.
- **Inject API** ne constructor.

### Kur ta perdoresh
- App te reja iOS 17+.
- Ekip i vogel ose mesatar ku boilerplate-i MVVM nuk po sjell vlere.
- Apple-style code ne SwiftUI.

### Kur **mos** ta perdoresh
- Need to support iOS <17. Atehere kthehu te MVVM klasike.
- Aplikim kompleks ku duhet TCA per testueshmeri te plote.

### Anti-pattern
- Te shtosh `ObservableObject` mbi `@Observable`. Zgjidh nje.
- `@Bindable` ku nuk te duhet (per properties qe nuk lidhen me UI input).
- Modele qe importojne SwiftUI per shkaqe konfori (p.sh. `Color`). Mbaji modelet pa varesi UI.

### Si lidhet me MVVM
- MV eshte MVVM ku ViewModel = Model. Apple beri kete trans-emertim me qellim ne WWDC 2023.
- Nese kohet e fundit do kalosh nga MVVM ne MV, hap pas hapi: zevendeso `class Foo: ObservableObject` me `@Observable class Foo`, hiq `@Published`, ne View zevendeso `@StateObject` me `@State`.

---

## English

For SwiftUI iOS 17+, Apple recommends a simpler model than classical MVVM. It is called **MV** (Model-View), with the `@Observable` macro that removes the need for `ObservableObject`, `@Published`, and `@StateObject`.

### Premise
SwiftUI is already a reactive system with first-class state observation. A **ViewModel class as a second layer** often duplicates what the `@Observable` model can do itself.

### Minimal shape

```swift
import Observation

@Observable
final class UsersModel {
    var users: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let api: UsersAPI

    init(api: UsersAPI) { self.api = api }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await api.fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UsersView: View {
    @State private var model: UsersModel

    init(api: UsersAPI) {
        _model = State(initialValue: UsersModel(api: api))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else if let error = model.errorMessage {
                Text(error).foregroundStyle(.red)
            } else {
                List(model.users) { Text($0.name) }
            }
        }
        .task { await model.load() }
    }
}
```

### Rules
- **`@Observable`** instead of `ObservableObject`.
- **`@State`** in the View to hold it, not `@StateObject` (which only works with `ObservableObject`).
- Keep the model **simple**. No "ViewModel" badge. It is just a class SwiftUI observes.
- **Inject the API** in the initializer.

### When to use
- New iOS 17+ apps.
- Small or mid-size team where MVVM boilerplate is not paying off.
- Apple-style code in SwiftUI.

### When **not** to use
- You must support iOS <17. Fall back to classical MVVM.
- Complex application where you need TCA for full testability.

### Anti-patterns
- Adding `ObservableObject` on top of `@Observable`. Pick one.
- `@Bindable` where you do not need it (for properties that are not bound to UI input).
- Models that import SwiftUI for convenience (e.g. `Color`). Keep models free of UI dependencies.

### How it relates to MVVM
- MV is MVVM where ViewModel = Model. Apple did this rename intentionally at WWDC 2023.
- If you migrate from MVVM to MV, step by step: replace `class Foo: ObservableObject` with `@Observable class Foo`, drop `@Published`, in the View swap `@StateObject` for `@State`.
