# Server-Side Request Forgery (SSRF)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Cdo funksionalitet ku server-i ben kerkesa drejt URL-ve te kontrolluara ose te ndikuara nga perdoruesi duhet mbrojtur.

### Feature te mundshme te prekshme

- Webhooks (perdoruesi jep callback URL).
- URL previews.
- PDF generators nga URL.
- Image / file fetching nga URL.
- Import from URL.
- RSS / feed readers.
- Integrime API me endpoint te perdoruesit.
- Proxy.
- HTML to PDF / image converters.

### Strategjite e mbrojtjes

**1. Allowlist (i preferuar).**
- Lejo vetem domain-e te miratuara.
- Mbaj nje allowlist strikte per integrime.

**2. Network segmentation.**
- Ekzekuto sherbimet fetch ne rrjet te izoluar.
- Bllo akses ne rrjetin e brendshem dhe cloud metadata.

### Teknika bypass IP / DNS per t'i bllokuar

| Teknika | Shembull | Pershkrim |
|---------|----------|-----------|
| Decimal IP | `http://2130706433` | 127.0.0.1 si decimal |
| Octal IP | `http://0177.0.0.1` | Octal |
| Hex IP | `http://0x7f.0x0.0x0.0x1` | Hex |
| IPv6 localhost | `http://[::1]` | Loopback IPv6 |
| IPv6 mapped IPv4 | `http://[::ffff:127.0.0.1]` | IPv4 mapped |
| Short IPv6 | `http://[::]` | Te gjitha zerot |
| DNS rebinding | DNS i sulmuesit kthen IP brendshme | Kerkesa e pare external, e dyta internal |
| CNAME internal | Domain i sulmuesit CNAME ne internal | DNS pikon ne internal hostname |
| URL parser confusion | `http://attacker.com#@internal` | Sjellje te ndryshme parsimi |
| Redirect chains | URL external redirekton ne internal | Ndjek redirect-et me kujdes |
| IPv6 scope ID | `http://[fe80::1%25eth0]` | IPv6 i scope-uar |
| Format te rralle IP | `http://127.1` | IP notation i shkurtuar |

### Mbrojtje nga DNS rebinding

1. Resolve DNS para kerkeses.
2. Valido qe IP e zgjidhur nuk eshte internal.
3. Pin IP e zgjidhur per kerkesen (mos ri-resolve).
4. Ose: resolve dy here me vonese, sigurohu qe te dyja shkojne ne te njejten IP external.

### Mbrojtje cloud metadata

Bllo akses ne endpoint metadata:
- AWS: `169.254.169.254`.
- GCP: `metadata.google.internal`, `169.254.169.254`, `http://metadata`.
- Azure: `169.254.169.254`.
- DigitalOcean: `169.254.169.254`.

### Lista e zbatimit

- [ ] Valido schema URL eshte vetem HTTP / HTTPS.
- [ ] Resolve DNS dhe valido qe IP nuk eshte private / internal.
- [ ] Bllo explicit cloud metadata IPs.
- [ ] Kufizo ose c'aktivizo ndjekjen e redirect-eve.
- [ ] Nese ndiqen redirect, valido cdo hop.
- [ ] Vendos timeout.
- [ ] Kufizo madhesine e pergjigjes.
- [ ] Perdor network isolation ku mundet.

---

## English

Any functionality where the server makes requests to user-controlled or user-influenced URLs must be protected.

### Potentially vulnerable features

- Webhooks (user provides callback URL).
- URL previews.
- PDF generators from URLs.
- Image / file fetching from URLs.
- Import from URL.
- RSS / feed readers.
- API integrations with user-provided endpoints.
- Proxy functionality.
- HTML to PDF / image converters.

### Protection strategies

**1. Allowlist (preferred).**
- Only allow pre-approved domains.
- Maintain a strict allowlist for integrations.

**2. Network segmentation.**
- Run URL-fetching services in an isolated network.
- Block access to internal network and cloud metadata.

### IP and DNS bypasses to block

| Technique | Example | Description |
|-----------|---------|-------------|
| Decimal IP | `http://2130706433` | 127.0.0.1 as decimal |
| Octal IP | `http://0177.0.0.1` | Octal representation |
| Hex IP | `http://0x7f.0x0.0x0.0x1` | Hexadecimal |
| IPv6 localhost | `http://[::1]` | IPv6 loopback |
| IPv6 mapped IPv4 | `http://[::ffff:127.0.0.1]` | IPv4-mapped IPv6 |
| Short IPv6 | `http://[::]` | All zeros |
| DNS rebinding | Attacker DNS returns internal IP | First request external, second internal |
| CNAME to internal | Attacker domain CNAMEs to internal | DNS points to internal hostname |
| URL parser confusion | `http://attacker.com#@internal` | Different parsing behaviours |
| Redirect chains | External URL redirects to internal | Follow redirects carefully |
| IPv6 scope ID | `http://[fe80::1%25eth0]` | Interface-scoped IPv6 |
| Rare IP formats | `http://127.1` | Shortened IP notation |

### DNS rebinding prevention

1. Resolve DNS before making the request.
2. Validate that the resolved IP is not internal.
3. Pin the resolved IP for the request (do not re-resolve).
4. Or: resolve twice with delay, ensure both resolve to the same external IP.

### Cloud metadata protection

Block access to cloud metadata endpoints:
- AWS: `169.254.169.254`.
- GCP: `metadata.google.internal`, `169.254.169.254`, `http://metadata`.
- Azure: `169.254.169.254`.
- DigitalOcean: `169.254.169.254`.

### Implementation checklist

- [ ] Validate URL scheme is HTTP / HTTPS only.
- [ ] Resolve DNS and validate IP is not private / internal.
- [ ] Block cloud metadata IPs explicitly.
- [ ] Limit or disable redirect following.
- [ ] If following redirects, validate each hop.
- [ ] Set timeout on requests.
- [ ] Limit response size.
- [ ] Use network isolation where possible.
