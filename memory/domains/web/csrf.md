# Cross-Site Request Forgery (CSRF)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Cdo endpoint qe ndryshon gjendje duhet mbrojtur kunder CSRF.

### Endpoint-e qe kerkojne mbrojtje CSRF

**Veprime te autentikuara:**
- Te gjitha kerkesat POST, PUT, PATCH, DELETE.
- Cdo GET qe ndryshon gjendje (rregulloji ne metoden e duhur).
- File uploads.
- Ndryshime settings.
- Endpoint pagese / transaksioni.

**Para autentikimit:**
- Login (per te shmangur login CSRF).
- Signup.
- Kerkese password reset.
- Ndryshim password.
- Verifikim email / telefoni.
- OAuth callback.

### Mekanizmat e mbrojtjes

**1. CSRF tokens.**
- Token kriptografikisht random.
- Lidh token me sesionin e perdoruesit.
- Valido ne cdo kerkese qe ndryshon gjendje.
- Rigjenero pas login (per te shmangur session fixation).

**2. SameSite cookies.**

```
Set-Cookie: session=abc123; SameSite=Strict; Secure; HttpOnly
```

- `Strict`: cookie nuk dergohet kurre cross-site (siguri maksimale).
- `Lax`: dergohet ne top-level navigations (balance i mire).
- Kombinoji gjithmone me CSRF tokens per defense in depth.

**3. Double Submit Cookie.**
- Dergo token-in ne cookie dhe ne body / header.
- Server-i verifikon qe perputhen.

### Skajet kritike dhe gabimet e zakonshme

- **Token presence check.** CSRF validimi NUK varet nese token-i eshte i pranishem, kerkoje gjithmone.
- **Token per form.** Konsidero token unik per veprime sensitive.
- **JSON APIs.** Mos supozo qe content-type JSON parandalon CSRF, valido Origin / Referer DHE perdor tokens.
- **CORS gabim.** CORS i lirshem mund te anashkaloje SameSite cookies.
- **Subdomain.** Token duhet te jete i scope-uar, sepse subdomain takeover ben CSRF te mundur.
- **Flash / PDF uploads.** Plugin-et legacy mund te bypass-onin SameSite.
- **GET me side effects.** Kurre mos ndrysho gjendje me GET.
- **Token leakage.** Mos i fut tokens ne URL.
- **Header vs URL.** Prefero custom header (`X-CSRF-Token`) mbi URL parameter.

### Lista e verifikimit

- [ ] Token kriptografikisht random.
- [ ] Token i lidhur me sesionin.
- [ ] Token validuar ne server per cdo kerkese state-changing.
- [ ] Token mungon => kerkesa refuzohet.
- [ ] Token rigjenerohet ne ndryshim auth state.
- [ ] SameSite cookie attribute set.
- [ ] `Secure` dhe `HttpOnly` ne session cookies.

---

## English

Every state-changing endpoint must be protected against CSRF.

### Endpoints requiring CSRF protection

**Authenticated actions:**
- All POST, PUT, PATCH, DELETE requests.
- Any GET that changes state (fix these to use proper HTTP methods).
- File uploads.
- Settings changes.
- Payment / transaction endpoints.

**Pre-authentication actions:**
- Login (prevent login CSRF).
- Signup.
- Password reset request.
- Password change.
- Email / phone verification.
- OAuth callback.

### Protection mechanisms

**1. CSRF tokens.**
- Generate cryptographically random tokens.
- Tie the token to the user session.
- Validate on every state-changing request.
- Regenerate after login (prevent session fixation combo).

**2. SameSite cookies.**

```
Set-Cookie: session=abc123; SameSite=Strict; Secure; HttpOnly
```

- `Strict`: cookie never sent cross-site (best security).
- `Lax`: sent on top-level navigations (good balance).
- Always combine with CSRF tokens for defense in depth.

**3. Double Submit Cookie.**
- Send the token in both cookie and body / header.
- Server verifies they match.

### Edge cases and common mistakes

- **Token presence check.** CSRF validation must NOT depend on whether the token is present, always require it.
- **Token per form.** Consider unique tokens per form for sensitive operations.
- **JSON APIs.** Do not assume JSON content-type prevents CSRF, validate Origin / Referer AND use tokens.
- **CORS misconfiguration.** Permissive CORS can bypass SameSite cookies.
- **Subdomains.** Tokens should be scoped because subdomain takeover enables CSRF.
- **Flash / PDF uploads.** Legacy browser plugins could bypass SameSite.
- **GET requests with side effects.** Never perform state changes on GET.
- **Token leakage.** Do not include tokens in URLs.
- **Header vs URL.** Prefer a custom header (`X-CSRF-Token`) over URL parameters.

### Verification checklist

- [ ] Token cryptographically random.
- [ ] Token tied to user session.
- [ ] Token validated server-side on all state-changing requests.
- [ ] Missing token => rejected request.
- [ ] Token regenerated on auth state change.
- [ ] SameSite cookie attribute set.
- [ ] `Secure` and `HttpOnly` on session cookies.
