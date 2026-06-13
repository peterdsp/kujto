# Mburoja, siguria e aplikacioneve web / Mburoja, web application security

**Mburoja** (shqip per "shield") eshte playbook-u i sigurise se Kujto-s per aplikacionet web. Perdore kete seksion kur shkruan, rishikon, ose auditon kod web (frontend ose backend), kur perdoruesi kerkon "scan" ose "audit" sigurie, ose para se te dergosh nje feature drejt produksionit.

**Mburoja** (Albanian for "the shield") is Kujto's security playbook for web applications. Use this section when writing, reviewing, or auditing web code (frontend or backend), when the user asks for a security "scan" or "audit", or before shipping a feature to production.

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Kur ta perdoresh

- Shkrim ose rishikim kodi te frontend ose backend.
- Kerkesa eksplicite per audit, "mburoja", "secure review", "scan".
- Para merge per PR qe prekin auth, upload, redirect, query string, ose te dhena perdoruesi.
- Para deploy ne produksion per cdo endpoint te ri.

### Parimet kryesore

- **Mbrojtje ne thellesi.** Asnje kontroll i vetem siguria, kombino disa shtresa.
- **Deshto i mbyllur.** Kur dicka thyhet, refuzo aksesin, mos ler portat hapur.
- **Privilegj minimal.** Cdo komponent, perdorues, dhe token merr vetem ate qe i duhet.
- **Validim input.** Mos i beso asnje input, validimi behet ne server.
- **Encoding output.** Encode te dhenat sipas kontekstit ku do te render-ohen.

### Indeksi i temave

#### Bug-e ne anen e klientit
- [Kontroll aksesi](access_control.md): IDOR, escalation, multi-tenancy.
- [XSS](xss.md): cross-site scripting, encoding, CSP.
- [CSRF](csrf.md): token, SameSite, double-submit.
- [Sekrete ne klient](secrets_exposure.md): API keys, PII, info leakage.
- [Open redirect](open_redirect.md): allowlist, bypass-e, IDN homograph.
- [Password](password_security.md): hashing, gjatesi, storage.

#### Bug-e ne anen e serverit
- [SSRF](ssrf.md): bypass, DNS rebinding, cloud metadata.
- [Upload skedaresh](file_upload.md): MIME, magic bytes, polyglots.
- [SQL Injection](sql_injection.md): parameterized queries, ORM, ORDER BY.
- [XXE](xxe.md): entity disabling per parser-a.
- [Path traversal](path_traversal.md): canonicalization, allowlist.

#### Tokens dhe API
- [JWT](jwt.md): algorithm confusion, storage, exp.
- [API security](api_security.md): mass assignment, GraphQL.
- [Security headers](security_headers.md): HSTS, CSP, X-Frame-Options.

### Rregull i arte

Kur jane ne dyshim, zgjidh opsionin me te kufizuar ose me te sigurt dhe shkruaj nje koment qe shpjegon pse.

---

## English

### When to use

- Writing or reviewing frontend or backend code.
- Explicit request for an audit, "mburoja", "secure review", "scan".
- Before merging PRs that touch auth, upload, redirect, query strings, or user data.
- Before deploying any new endpoint to production.

### Core principles

- **Defense in depth.** Never rely on a single security control, layer them.
- **Fail closed.** When something breaks, deny access, do not leave doors open.
- **Least privilege.** Every component, user, and token gets only what it needs.
- **Input validation.** Trust no input, validate everything server-side.
- **Output encoding.** Encode data for the context it renders in.

### Topic index

#### Client-side bugs
- [Access control](access_control.md): IDOR, escalation, multi-tenancy.
- [XSS](xss.md): cross-site scripting, encoding, CSP.
- [CSRF](csrf.md): tokens, SameSite, double-submit.
- [Client-side secrets](secrets_exposure.md): API keys, PII, info leakage.
- [Open redirect](open_redirect.md): allowlist, bypasses, IDN homograph.
- [Password](password_security.md): hashing, length, storage.

#### Server-side bugs
- [SSRF](ssrf.md): bypasses, DNS rebinding, cloud metadata.
- [File upload](file_upload.md): MIME, magic bytes, polyglots.
- [SQL injection](sql_injection.md): parameterized queries, ORM, ORDER BY.
- [XXE](xxe.md): entity disabling per parser.
- [Path traversal](path_traversal.md): canonicalization, allowlist.

#### Tokens and APIs
- [JWT](jwt.md): algorithm confusion, storage, exp.
- [API security](api_security.md): mass assignment, GraphQL.
- [Security headers](security_headers.md): HSTS, CSP, X-Frame-Options.

### Golden rule

When in doubt, pick the more restrictive or more secure option and add a short comment explaining why.
