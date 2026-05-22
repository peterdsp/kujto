# MVVM / MVVM

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Roli i secilit
- **Model**: vlere e paster, pa varesi UI ose framework.
- **View**: SwiftUI ose UIKit, render i state-it nga ViewModel.
- **ViewModel**: gjendja e ekranit + funksione qe transformojne input ne state. Pa varesi UIKit/SwiftUI direkte.

### Forma minimale SwiftUI

```swift
@MainActor
final class UsersViewModel: ObservableObject {
    @Published private(set) var state: State = .loading
    private let api: UsersAPI

    init(api: UsersAPI) { self.api = api }

    enum State: Equatable {
        case loading
        case loaded([User])
        case failed(String)
    }

    func onAppear() async {
        do {
            state = .loaded(try await api.fetch())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct UsersView: View {
    @StateObject var viewModel: UsersViewModel

    var body: some View {
        switch viewModel.state {
        case .loading: ProgressView()
        case .loaded(let users): List(users) { Text($0.name) }
        case .failed(let message): Text(message).foregroundStyle(.red)
        }
    }
    .task { await viewModel.onAppear() }
}
```

### Rregulla
- **State i tipi enum** per ekrane me me shume se nje gjendje. `loading/loaded/failed` lexohet shume me mire se 3 boolean te ndryshem.
- **ViewModel injekton API**, jo e krijon vete.
- **Pa logjike biznesi ne View**. Nese duhet `if/else` me shume se 1 nivel, levize ne ViewModel.

### Anti-pattern
- ViewModel qe importon SwiftUI.
- `@Published var isLoading: Bool` + `@Published var error: Error?` + `@Published var users: [User]` ne nje vend. Perdor enum.
- ViewModel singleton.
- ViewModel qe ben navigim direkt. Le View te beje navigim, le ViewModel te thote "u perfundua".

### Testimi
- Inject `UsersAPI` fake.
- Asserto tranzicione state: `loading -> loaded` ose `loading -> failed`.
- Pa testuar UI. Testimi i UI eshte pune e snapshot-eve.

---

## English

### Roles
- **Model**: pure value, no UI or framework dependency.
- **View**: SwiftUI or UIKit, renders state from ViewModel.
- **ViewModel**: screen state + functions that transform input into state. No direct UIKit/SwiftUI dependency.

### Minimal SwiftUI shape

```swift
@MainActor
final class UsersViewModel: ObservableObject {
    @Published private(set) var state: State = .loading
    private let api: UsersAPI

    init(api: UsersAPI) { self.api = api }

    enum State: Equatable {
        case loading
        case loaded([User])
        case failed(String)
    }

    func onAppear() async {
        do {
            state = .loaded(try await api.fetch())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct UsersView: View {
    @StateObject var viewModel: UsersViewModel

    var body: some View {
        switch viewModel.state {
        case .loading: ProgressView()
        case .loaded(let users): List(users) { Text($0.name) }
        case .failed(let message): Text(message).foregroundStyle(.red)
        }
    }
    .task { await viewModel.onAppear() }
}
```

### Rules
- **Enum-typed state** for screens with more than one state. `loading/loaded/failed` reads far better than 3 separate booleans.
- **ViewModel takes the API by injection**, it does not create it.
- **No business logic in the View**. If you need `if/else` more than 1 level deep, move it to the ViewModel.

### Anti-patterns
- ViewModel importing SwiftUI.
- `@Published var isLoading: Bool` + `@Published var error: Error?` + `@Published var users: [User]` in one place. Use an enum.
- Singleton ViewModel.
- ViewModel doing navigation directly. Let the View navigate, let the ViewModel say "done".

### Testing
- Inject a fake `UsersAPI`.
- Assert state transitions: `loading -> loaded` or `loading -> failed`.
- Do not test UI. UI is the job of snapshots.
