# Security headers

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Perfshi keto headers ne te gjitha pergjigjet:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Content-Security-Policy: [shih seksionin XSS]
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Cache-Control: no-store (per faqe sensitive)
```

---

## English

Include these headers in all responses:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Content-Security-Policy: [see XSS section]
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Cache-Control: no-store (for sensitive pages)
```
