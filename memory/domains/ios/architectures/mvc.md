# MVC / MVC

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

MVC eshte pattern-i klasik i Apple: **Model, View, Controller**.
Ne iOS tradicional, `UIViewController` shpesh lidh input-et, lifecycle,
navigimin dhe rendering-un.

### Roli i secilit

- **Model**: te dhena dhe rregulla domain-i, pa UIKit.
- **View**: `UIView`, `UITableViewCell`, SwiftUI `View`, pa business logic.
- **Controller**: lidh Model me View, menaxhon lifecycle dhe delegatet.

### Kur ta perdoresh

- Screen i vogel UIKit me pak state.
- Kodbaze ekzistuese Apple-style ku controller-at jane ende te vegjel.
- Prototype ose feature ku rreziku i kompleksitetit eshte i ulet.

### Kur mos ta perdoresh

- Controller po kalon 300-400 rreshta me networking, formatting dhe navigim.
- Kerkohet testim i forte i logjikes se ekranit.
- Ekipi duhet te punoje ne te njejtin feature ne role te ndara.

### Anti-pattern

- Massive View Controller.
- Networking direkt ne `UIViewController`.
- Formatting dhe business rules brenda cell configuration.
- Model qe importon UIKit.

### Rregull praktik

MVC eshte i pranueshem kur eshte i vogel. Sapo controller-i fillon te mbaje
state komplekse, kalo ne MVVM, MVP, MVVM-C ose Clean Swift.

---

## English

MVC is Apple's classic pattern: **Model, View, Controller**.
In traditional iOS, `UIViewController` often connects inputs, lifecycle,
navigation, and rendering.

### Roles

- **Model**: data and domain rules, no UIKit.
- **View**: `UIView`, `UITableViewCell`, SwiftUI `View`, no business logic.
- **Controller**: connects Model to View, manages lifecycle and delegates.

### When to use

- Small UIKit screen with little state.
- Existing Apple-style codebase where controllers are still small.
- Prototype or feature where complexity risk is low.

### When not to use

- The controller is crossing 300-400 lines with networking, formatting, and navigation.
- Strong testing of screen logic is required.
- The team needs to work on the same feature in separated roles.

### Anti-patterns

- Massive View Controller.
- Networking directly inside `UIViewController`.
- Formatting and business rules inside cell configuration.
- Model importing UIKit.

### Practical rule

MVC is acceptable when it is small. Once the controller starts holding complex
state, move to MVVM, MVP, MVVM-C, or Clean Swift.
