# Workflow Xcode / Xcode workflow

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Ndertim nga rreshti i komandes
Perdor `simulator.sh` ne root te Kujto-s. Pa shkruar `xcodebuild` me dore vec nese debugon Kujto-n vete.

```bash
./simulator.sh                     # auto-detekto cdo gje
./simulator.sh --clean             # rindertim nga zero
./simulator.sh --release           # konfigurim Release
./simulator.sh --device "iPhone 15"
```

### Worktrees
Per task paralele perdor `git worktree`, jo `git stash`. Kjo i mban Xcode index-et e ndara dhe shmang konfliktet e schema-ve.

```bash
git worktree add ../myapp-feature feature/x
cd ../myapp-feature
~/kujto/simulator.sh
```

### DerivedData
`simulator.sh` perdor `~/Library/Developer/Xcode/DerivedData/Kujto-<projekt>`, e ndare nga Xcode IDE. Per ndertimin e zakonshem ne IDE, lere DerivedData default.

### Skripte build phases
Mos lej skripte qe te ndryshojne file-a te commitueshem gjate ndertimit. Output i gjeneruar duhet te jete (a) jashte VCS ose (b) ne folder te dedikuar `Generated/`.

---

## English

### Build from the command line
Use `simulator.sh` at the Kujto root. Do not type `xcodebuild` by hand unless you are debugging Kujto itself.

```bash
./simulator.sh                     # auto-detect everything
./simulator.sh --clean             # rebuild from scratch
./simulator.sh --release           # Release configuration
./simulator.sh --device "iPhone 15"
```

### Worktrees
For parallel tasks use `git worktree`, not `git stash`. This keeps Xcode indexes separate and avoids scheme conflicts.

```bash
git worktree add ../myapp-feature feature/x
cd ../myapp-feature
~/kujto/simulator.sh
```

### DerivedData
`simulator.sh` uses `~/Library/Developer/Xcode/DerivedData/Kujto-<project>`, separate from Xcode IDE. For normal IDE builds, leave DerivedData at the default.

### Build-phase scripts
Do not allow scripts to mutate committed files during build. Generated output must be (a) outside VCS or (b) in a dedicated `Generated/` folder.
