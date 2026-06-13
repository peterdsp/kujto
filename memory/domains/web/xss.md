# Cross-Site Scripting (XSS)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Cdo input qe kontrollohet nga perdoruesi, drejtperdrejt apo terthorazi, duhet sanituar kunder XSS.

### Burime input qe duhen mbrojtur

**Direkte:**
- Form fields (email, name, bio, comments).
- Search queries.
- File names ne upload.
- Editor rich text / WYSIWYG.

**Indirekte:**
- URL parameters dhe query strings.
- URL fragments (hash).
- HTTP headers te perdorur ne app (Referer, User-Agent nese shfaqen).
- Te dhena nga API te treta qe shfaqen perdoruesit.
- WebSocket messages.
- `postMessage` data nga iframes.
- LocalStorage / SessionStorage nese render-ohen.

**Te harruara shpesh:**
- Error messages qe reflektojne input.
- PDF / document generators qe pranojne HTML.
- Email templates me te dhena perdoruesi.
- Log viewers ne admin panels.
- JSON responses te render-uara si HTML.
- SVG uploads (mund te permbajne JavaScript).
- Markdown rendering (nese lejojme HTML).

### Strategjite e mbrojtjes

**1. Output encoding sipas kontekstit.**
- HTML: HTML entity encode (`<` => `&lt;`).
- JavaScript: JavaScript escape.
- URL: URL encode.
- CSS: CSS escape.
- Perdor escaping-un e framework-ut (React JSX, Vue `{{ }}`).

**2. Content Security Policy (CSP).**

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  font-src 'self';
  connect-src 'self' https://api.yourdomain.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
```

- Shmang `'unsafe-inline'` dhe `'unsafe-eval'` per script.
- Perdor nonces ose hashes per inline scripts kur duhet.
- Report-uri per shkelje: `report-uri /csp-report`.

**3. Input sanitization.**
- Perdor biblioteka te njohura (DOMPurify per HTML).
- Whitelist tags / attributes per rich text.
- Strip ose encode pattern-a te rrezikshem.

**4. Headers shtese.**
- `X-Content-Type-Options: nosniff`.
- `X-Frame-Options: DENY` (ose CSP `frame-ancestors`).

---

## English

Every input controllable by the user, directly or indirectly, must be sanitized against XSS.

### Input sources to protect

**Direct:**
- Form fields (email, name, bio, comments).
- Search queries.
- File names on upload.
- Rich text / WYSIWYG editors.

**Indirect:**
- URL parameters and query strings.
- URL fragments (hash).
- HTTP headers consumed by the app (Referer, User-Agent if displayed).
- Data from third-party APIs displayed to users.
- WebSocket messages.
- `postMessage` data from iframes.
- LocalStorage / SessionStorage if rendered.

**Often overlooked:**
- Error messages that reflect input.
- PDF / document generators that accept HTML.
- Email templates with user data.
- Log viewers in admin panels.
- JSON responses rendered as HTML.
- SVG uploads (can contain JavaScript).
- Markdown rendering (if HTML allowed).

### Protection strategies

**1. Context-specific output encoding.**
- HTML: HTML entity encode (`<` => `&lt;`).
- JavaScript: JavaScript escape.
- URL: URL encode.
- CSS: CSS escape.
- Use the framework's built-in escaping (React JSX, Vue `{{ }}`).

**2. Content Security Policy (CSP).**

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  font-src 'self';
  connect-src 'self' https://api.yourdomain.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
```

- Avoid `'unsafe-inline'` and `'unsafe-eval'` for scripts.
- Use nonces or hashes for inline scripts when necessary.
- Report violations: `report-uri /csp-report`.

**3. Input sanitization.**
- Use established libraries (DOMPurify for HTML).
- Whitelist allowed tags / attributes for rich text.
- Strip or encode dangerous patterns.

**4. Additional headers.**
- `X-Content-Type-Options: nosniff`.
- `X-Frame-Options: DENY` (or CSP `frame-ancestors`).
