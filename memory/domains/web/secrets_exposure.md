# Sekrete ne klient / Client-side secrets exposure

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Asnje sekret ose informacion sensitiv nuk duhet te jete i aksesueshem nga kodi i klientit.

### Mos i ekspozo kurre ne kod klienti

**API keys dhe secrets:**
- API keys te paleve te treta (Stripe, AWS).
- Connection strings te database.
- JWT signing secrets.
- Encryption keys.
- OAuth client secrets.
- URL / kredencialet e sherbimeve te brendshme.

**Te dhena perdoruesi sensitiv:**
- Numra te plote karte krediti.
- Social Security Numbers.
- Passwords (edhe te hash-uara).
- Pyetje / pergjigje sigurie.
- Numra te plote telefoni (maskoji: `***-***-1234`).
- PII sensitiv qe nuk duhet per shfaqje.

**Detaje infrastrukture:**
- IP te brendshme.
- Database schemas.
- Debug info.
- Stack traces ne produksion.
- Versionet e software te server-it.

### Ku fshihen sekretet (kontrolloji)

- JavaScript bundles (perfshire source maps).
- HTML comments.
- Hidden form fields.
- Data attributes.
- LocalStorage / SessionStorage.
- Initial state / hydration data ne SSR.
- Variabla mjedisi te ekspozuara nga build (`NEXT_PUBLIC_*`, `REACT_APP_*`).

### Praktikat me te mira

1. **Environment variables.** Ruaj sekretet ne `.env`.
2. **Vetem ne server.** Bej API calls qe kerkojne sekrete vetem nga backend.

---

## English

No secrets or sensitive information should be accessible to client-side code.

### Never expose in client-side code

**API keys and secrets:**
- Third-party API keys (Stripe, AWS).
- Database connection strings.
- JWT signing secrets.
- Encryption keys.
- OAuth client secrets.
- Internal service URLs / credentials.

**Sensitive user data:**
- Full credit card numbers.
- Social Security Numbers.
- Passwords (even hashed).
- Security questions / answers.
- Full phone numbers (mask them: `***-***-1234`).
- Sensitive PII not needed for display.

**Infrastructure details:**
- Internal IP addresses.
- Database schemas.
- Debug information.
- Production stack traces.
- Server software versions.

### Where secrets hide (check these)

- JavaScript bundles (including source maps).
- HTML comments.
- Hidden form fields.
- Data attributes.
- LocalStorage / SessionStorage.
- Initial state / hydration data in SSR apps.
- Environment variables exposed via build tools (`NEXT_PUBLIC_*`, `REACT_APP_*`).

### Best practices

1. **Environment variables.** Store secrets in `.env` files.
2. **Server-side only.** Make API calls requiring secrets from backend only.
