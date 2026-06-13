# Open redirect

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Cdo endpoint qe pranon nje URL per redirect duhet mbrojtur.

### Strategjite e mbrojtjes

**1. Allowlist validation.**

```
allowed_domains = ['yourdomain.com', 'app.yourdomain.com']

function isValidRedirect(url):
    parsed = parseUrl(url)
    return parsed.hostname in allowed_domains
```

**2. URL relative vetem.**
- Prano vetem path (psh `/dashboard`), jo URL te plota.
- Valido qe path fillon me `/` dhe nuk permban `//`.

**3. Reference indirekte.**
- Perdor nje mapping ne vend te URL te plote: `?redirect=dashboard` => lookup ne `/dashboard`.

### Teknika bypass per t'i bllokuar

| Teknika | Shembull | Pse funksionon |
|---------|----------|----------------|
| Simboli `@` | `https://legit.com@evil.com` | Browser shkon ne evil.com me legit.com si username |
| Subdomain abuse | `https://legit.com.evil.com` | evil.com zoteron subdomain-in |
| Protocol tricks | `javascript:alert(1)` | XSS via redirect |
| Double URL encoding | `%252f%252fevil.com` | Decode-on ne `//evil.com` pas dy decode |
| Backslash | `https://legit.com\@evil.com` | Disa parser normalize-ojne `\` ne `/` |
| Null byte | `https://legit.com%00.evil.com` | Disa parser ndahen ne null |
| Tab / newline | `https://legit.com%09.evil.com` | Konfuzion whitespace |
| Unicode normalization | `https://legіt.com` (`і` cirilike) | IDN homograph attack |
| Data URLs | `data:text/html,<script>...` | Ekzekutim direkt payload |
| Protocol-relative | `//evil.com` | Perdor protokollin e faqes aktuale |
| Fragment abuse | `https://legit.com#@evil.com` | Parsuar ndryshe nga biblioteka te ndryshme |

### Mbrojtje IDN homograph

- Konverto URL ne Punycode para validimit.
- Konsidero bllokimin e domain-eve jo-ASCII per redirect sensitiv.

---

## English

Any endpoint accepting a URL for redirect must be protected.

### Protection strategies

**1. Allowlist validation.**

```
allowed_domains = ['yourdomain.com', 'app.yourdomain.com']

function isValidRedirect(url):
    parsed = parseUrl(url)
    return parsed.hostname in allowed_domains
```

**2. Relative URLs only.**
- Only accept paths (e.g. `/dashboard`), not full URLs.
- Validate the path starts with `/` and does not contain `//`.

**3. Indirect references.**
- Use a mapping instead of raw URLs: `?redirect=dashboard` => lookup `/dashboard`.

### Bypass techniques to block

| Technique | Example | Why it works |
|-----------|---------|--------------|
| `@` symbol | `https://legit.com@evil.com` | Browser navigates to evil.com with legit.com as username |
| Subdomain abuse | `https://legit.com.evil.com` | evil.com owns the subdomain |
| Protocol tricks | `javascript:alert(1)` | XSS via redirect |
| Double URL encoding | `%252f%252fevil.com` | Decodes to `//evil.com` after double decode |
| Backslash | `https://legit.com\@evil.com` | Some parsers normalize `\` to `/` |
| Null byte | `https://legit.com%00.evil.com` | Some parsers truncate at null |
| Tab / newline | `https://legit.com%09.evil.com` | Whitespace confusion |
| Unicode normalization | `https://legіt.com` (Cyrillic `і`) | IDN homograph attack |
| Data URLs | `data:text/html,<script>...` | Direct payload execution |
| Protocol-relative | `//evil.com` | Uses current page's protocol |
| Fragment abuse | `https://legit.com#@evil.com` | Parsed differently by different libraries |

### IDN homograph protection

- Convert URLs to Punycode before validation.
- Consider blocking non-ASCII domains entirely for sensitive redirects.
