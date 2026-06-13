# SQL Injection

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

SQL injection ndodh kur input i perdoruesit perfshihet ne query SQL pa trajtim te duhur.

### Metodat e parandalimit

**1. Parameterized queries (prepared statements). MBROJTJA KRYESORE.**

```sql
-- VULNERABLE
query = "SELECT * FROM users WHERE id = " + userId

-- SECURE
query = "SELECT * FROM users WHERE id = ?"
execute(query, [userId])
```

**2. ORM.**
- Perdor metoda ORM qe automatikisht parameterizojne.
- Kujdes me metoda raw query brenda ORM-it.
- Vezhgo per injection points specifike te ORM-it.

**3. Validim input.**
- Valido tipin (integer duhet te jete integer).
- Whitelist vlerat e lejuara ku mundet.
- Ky eshte defense-in-depth, jo mbrojtja kryesore.

### Pikat e injection per t'i vezhguar

- `WHERE` clauses.
- `ORDER BY` (i harruar shpesh, nuk merr parameter, perdor whitelist).
- `LIMIT` / `OFFSET`.
- Emrat e tabelave dhe kolonave (nuk parameterizohen, whitelist).
- `INSERT` values.
- `UPDATE SET`.
- `IN` me liste dinamike.
- `LIKE` patterns (escape wildcards: `%`, `_`).

### Mbrojtje shtese

- **Privilegj minimal.** Perdorues DB me lejet minimale.
- **C'aktivizo funksione te rrezikshme.** Si `xp_cmdshell` ne SQL Server.
- **Error handling.** Mos i ekspozo SQL errors perdoruesit.

---

## English

SQL injection occurs when user input is incorporated into SQL queries without proper handling.

### Prevention methods

**1. Parameterized queries (prepared statements). PRIMARY DEFENSE.**

```sql
-- VULNERABLE
query = "SELECT * FROM users WHERE id = " + userId

-- SECURE
query = "SELECT * FROM users WHERE id = ?"
execute(query, [userId])
```

**2. ORM usage.**
- Use ORM methods that automatically parameterize.
- Be cautious with raw query methods.
- Watch for ORM-specific injection points.

**3. Input validation.**
- Validate data types (integer should be integer).
- Whitelist allowed values where applicable.
- This is defense in depth, not the primary defense.

### Injection points to watch

- `WHERE` clauses.
- `ORDER BY` (often overlooked, cannot use parameters, must whitelist).
- `LIMIT` / `OFFSET` values.
- Table and column names (cannot parameterize, whitelist).
- `INSERT` values.
- `UPDATE SET` values.
- `IN` clauses with dynamic lists.
- `LIKE` patterns (escape wildcards: `%`, `_`).

### Additional defenses

- **Least privilege.** DB user should have minimum required permissions.
- **Disable dangerous functions.** Such as `xp_cmdshell` in SQL Server.
- **Error handling.** Never expose SQL errors to users.
