# Shembull: projekt iOS me Kujto / Example: iOS project with Kujto

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Ky folder dokumenton si te ndizet Kujto ne nje projekt te zakonshem iOS. Pa kod, vetem hapa.

### 1. Klono Kujto-n globalisht

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

### 2. Lidh memorien me repo-n tend

```bash
cd ~/code/MyApp
~/kujto/wire.sh
```

Tani ne `MyApp` ke:
- `AGENTS.md` -> `~/kujto/AGENTS.md`
- `CLAUDE.md` -> `~/kujto/AGENTS.md`
- `CODEX.md` -> `~/kujto/AGENTS.md`
- `GEMINI.md` -> `~/kujto/AGENTS.md`

### 3. Ndez app-in pa konfigurim

```bash
cd ~/code/MyApp
~/kujto/simulator.sh
```

### 4. Shto Copilot dhe Cursor nese i perdor

Shih [integrations/copilot/README.md](../../integrations/copilot/README.md) dhe [integrations/cursor/README.md](../../integrations/cursor/README.md).

### 5. Personalizo memorien
Bej fork te Kujto-s. Edito `memory/domains/ios/` me konventat e ekipit tend.

---

## English

This folder documents how to bring Kujto into a typical iOS project. No code, only steps.

### 1. Clone Kujto globally

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

### 2. Wire memory into your repo

```bash
cd ~/code/MyApp
~/kujto/wire.sh
```

Now in `MyApp` you have:
- `AGENTS.md` -> `~/kujto/AGENTS.md`
- `CLAUDE.md` -> `~/kujto/AGENTS.md`
- `CODEX.md` -> `~/kujto/AGENTS.md`
- `GEMINI.md` -> `~/kujto/AGENTS.md`

### 3. Boot the app with zero config

```bash
cd ~/code/MyApp
~/kujto/simulator.sh
```

### 4. Add Copilot and Cursor if you use them

See [integrations/copilot/README.md](../../integrations/copilot/README.md) and [integrations/cursor/README.md](../../integrations/cursor/README.md).

### 5. Customise memory
Fork Kujto. Edit `memory/domains/ios/` with your team's conventions.
