# API security

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Mass assignment

Pranimi i request body pa filter mund te coje ne privilege escalation.

```javascript
// VULNERABLE: perdoruesi mund te dergoje { role: "admin" } ne body
User.update(req.body)

// SECURE: whitelist fushat e lejuara
const allowed = ['name', 'email', 'avatar']
const updates = pick(req.body, allowed)
User.update(updates)
```

Vlen per cdo ORM / framework: gjithmone definicio explicit cilat fusha mund te modifikoje nje kerkese.

### GraphQL

| Vulnerabiliteti | Parandalimi |
|-----------------|-------------|
| Introspection ne produksion | C'aktivizo introspection ne produksion |
| Query depth attack | Limit depth (psh maksimum 10 nivele) |
| Query complexity attack | Llogarit dhe zbato cost limits strikt |
| Batching attack | Limit numrin e operacioneve per kerkese |

```javascript
const server = new ApolloServer({
  introspection: process.env.NODE_ENV !== 'production',
  validationRules: [
    depthLimit(10),
    costAnalysis({ maximumCost: 1000 })
  ]
})
```

### Parime te pergjithshme

Kur gjeneron kod, gjithmone:

1. **Valido cdo input server-side.** Mos i beso validimit client-side.
2. **Perdor parameterized queries.** Asnjehere mos concat input ne query.
3. **Encode output sipas kontekstit.** HTML, JS, URL, CSS kane encoding te ndryshme.
4. **Kontrolle autentikimi.** Ne cdo endpoint, jo vetem ne routing.
5. **Kontrolle autorizimi.** Verifiko qe perdoruesi mund te aksesoje burimin specifik.
6. **Default te sigurt.**
7. **Trajtim error te sigurt.** Mos leako stack traces ose detaje te brendshme.
8. **Mbaj dependencies te perditesuara.** Perdor tools per dependencies te prekshme.

Kur ne dyshim, zgjidh opsionin me restriktiv ose me te sigurt, dhe dokumentoje me nje koment te shkurter.

---

## English

### Mass assignment

Accepting unfiltered request bodies can lead to privilege escalation.

```javascript
// VULNERABLE: user can set { role: "admin" } in request body
User.update(req.body)

// SECURE: whitelist allowed fields
const allowed = ['name', 'email', 'avatar']
const updates = pick(req.body, allowed)
User.update(updates)
```

This applies to any ORM / framework: always explicitly define which fields a request can modify.

### GraphQL

| Vulnerability | Prevention |
|---------------|------------|
| Introspection in production | Disable introspection in production |
| Query depth attack | Implement query depth limiting (e.g. max 10 levels) |
| Query complexity attack | Calculate and enforce strict query cost limits |
| Batching attack | Limit the number of operations per single request |

```javascript
const server = new ApolloServer({
  introspection: process.env.NODE_ENV !== 'production',
  validationRules: [
    depthLimit(10),
    costAnalysis({ maximumCost: 1000 })
  ]
})
```

### General principles

When generating code, always:

1. **Validate all input server-side.** Never trust client-side validation alone.
2. **Use parameterized queries.** Never concatenate user input into queries.
3. **Encode output contextually.** HTML, JS, URL, CSS contexts need different encoding.
4. **Apply authentication checks.** On every endpoint, not just at routing.
5. **Apply authorization checks.** Verify the user can access the specific resource.
6. **Use secure defaults.**
7. **Handle errors securely.** Do not leak stack traces or internal details.
8. **Keep dependencies updated.** Use tools to track vulnerable dependencies.

When in doubt, choose the more restrictive / more secure option and document it with a short comment.
