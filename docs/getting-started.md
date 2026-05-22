# Fillimi / Getting started

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### 1. Instalimi

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

Ose me nje rresht:

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

### 2. Cfare ndodh gjate instalimit
- `~/.claude/CLAUDE.md` ben symlink te `~/kujto/AGENTS.md` (nese ekziston `~/.claude`).
- E njejta gje per `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/AGENTS.md`.
- Skriptet `simulator.sh`, `install.sh`, `wire.sh` behen ekzekutuese.

### 3. Provo simulator-in

```bash
cd path/to/your/ios/project
~/kujto/simulator.sh
```

Pa konfigurim. Auto-detekton workspace, scheme, simulator, bundle id, dhe e nxjerr app-in ne ekran.

### 4. Lidh memory-në te projekti

```bash
cd path/to/your/repo
~/kujto/wire.sh
```

Krijon `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md` ne repo, te gjitha symlink drejt Kujto-s.

### 5. Personalizo
Bej fork. Edito `memory/` me konventat e tua. Bej commit ne fork-un tend. `auto-pull.sh` mund te perdoret per t'i mbajtur ndryshimet ne sinkron midis makinave.

---

## English

### 1. Install

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

Or in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

### 2. What happens during install
- `~/.claude/CLAUDE.md` becomes a symlink to `~/kujto/AGENTS.md` (if `~/.claude` exists).
- Same for `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/AGENTS.md`.
- `simulator.sh`, `install.sh`, `wire.sh` become executable.

### 3. Try the simulator

```bash
cd path/to/your/ios/project
~/kujto/simulator.sh
```

No config. Auto-detects workspace, scheme, simulator, bundle id, and brings the app to the foreground.

### 4. Wire memory into a project

```bash
cd path/to/your/repo
~/kujto/wire.sh
```

Creates `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md` in the repo, all symlinked to Kujto.

### 5. Customise
Fork it. Edit `memory/` with your conventions. Commit to your fork. `auto-pull.sh` can keep changes in sync across machines.
