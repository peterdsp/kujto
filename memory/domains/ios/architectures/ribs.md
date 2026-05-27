# RIBs / RIBs

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

RIBs (Router, Interactor, Builder) eshte arkitekture per app shume te medha,
e krijuar nga Uber. Ajo e ndan app-in ne nje peme business logic ku cdo node
ka ownership te qarte dhe lifecycle te vet.

### Roli i secilit

- **Router**: attach dhe detach te child RIBs, navigim dhe lifecycle.
- **Interactor**: business logic aktive per ate node.
- **Builder**: nderton RIB-in dhe injekton varesite.
- **View**: opsionale per RIBs pa UI, pasive kur ekziston.

### Kur ta perdoresh

- App shume e madhe me shume ekipe dhe flows te pavarura.
- Kur ownership-i i features dhe lifecycle-i jane burim bug-esh.
- Kur navigimi duhet te ndjeke nje peme te qarte parent-child.

### Kur mos ta perdoresh

- App e vogel ose e mesme.
- Ekip qe nuk ka nevoje per ceremony te larte.
- SwiftUI app ku NavigationStack dhe state i tipizuar e zgjidh problemin me
  pak kosto.

### Anti-pattern

- Ta perdoresh vetem per navigim. Vlera e RIBs eshte ownership + business
  logic tree.
- Child RIB qe flet direkt me sibling RIB.
- Builder qe ben business logic.
- RIBs per cdo view te vogel pa arsye lifecycle.

### Rregull praktik

RIBs eshte per shkalle shume te madhe. Nese nuk mund te shpjegosh pemen e
ownership-it, mos e shto.

---

## English

RIBs (Router, Interactor, Builder) is an architecture for very large apps,
created by Uber. It splits the app into a business-logic tree where each node
has clear ownership and its own lifecycle.

### Roles

- **Router**: attaches and detaches child RIBs, navigation, and lifecycle.
- **Interactor**: active business logic for that node.
- **Builder**: builds the RIB and injects dependencies.
- **View**: optional for RIBs without UI, passive when present.

### When to use

- Very large app with many teams and independent flows.
- Feature ownership and lifecycle are a source of bugs.
- Navigation needs to follow a clear parent-child tree.

### When not to use

- Small or mid-size app.
- Team that does not need high ceremony.
- SwiftUI app where NavigationStack and typed state solve the problem at lower cost.

### Anti-patterns

- Using it only for navigation. RIBs value is ownership + business-logic tree.
- Child RIB talking directly to a sibling RIB.
- Builder doing business logic.
- RIBs for every tiny view without a lifecycle reason.

### Practical rule

RIBs is for very large scale. If you cannot explain the ownership tree, do not
add it.
