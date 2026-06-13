# JWT Security

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Konfigurime te gabuara JWT cojne ne bypass te plote autentikimi dhe forge token.

### Vulnerabilitete

| Vulnerabiliteti | Parandalimi |
|-----------------|-------------|
| `alg: none` attack | Verifiko algorithm gjithmone server-side, refuzo `none` |
| Algorithm confusion | Specifiko explicit algorithm e pritur, mos e nxirr nga token |
| HMAC secrets te dobet | Perdor secrets 256+ bit kriptografikisht random |
| Pa expiration | Vendos gjithmone `exp` claim |
| Token ne localStorage | Ruaj ne httpOnly, Secure, SameSite=Strict cookies |

### Implementim i sigurt

```javascript
// 1. SIGNING
// Gjithmone perdor env vars per secrets
const secret = process.env.JWT_SECRET;

const token = jwt.sign({
  sub: userId,
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (15 * 60), // 15 min (jete e shkurter)
  jti: crypto.randomUUID() // unik per revocation / blacklist
}, secret, {
  algorithm: 'HS256'
});

// 2. SENDING (cookie best practices)
// Mbron nga XSS dhe CSRF
res.cookie('token', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict'
});

// 3. VERIFYING
// KRITIKE: whitelist algorithm e lejuar
jwt.verify(token, secret, { algorithms: ['HS256'] }, (err, decoded) => {
  if (err) {
    // trajto token invalid
  }
  // beso payload
});
```

### Lista JWT

- [ ] Algorithm specifikuar explicit ne verifikim (mos i beso header te token).
- [ ] `alg: none` refuzohet.
- [ ] Secret 256+ bit random (jo password ose frase).
- [ ] `exp` claim gjithmone vendoset dhe validohet.
- [ ] Tokens ne httpOnly cookies (jo localStorage / sessionStorage).
- [ ] Refresh token rotation (refresh i vjeter invalidohet ne perdorim).

---

## English

JWT misconfigurations can lead to full authentication bypass and token forgery.

### Vulnerabilities

| Vulnerability | Prevention |
|---------------|------------|
| `alg: none` attack | Always verify algorithm server-side, reject `none` |
| Algorithm confusion | Explicitly specify expected algorithm, never derive from token |
| Weak HMAC secrets | Use 256+ bit cryptographically random secrets |
| Missing expiration | Always set `exp` claim |
| Token in localStorage | Store in httpOnly, Secure, SameSite=Strict cookies |

### Secure implementation

```javascript
// 1. SIGNING
// Always use environment variables for secrets
const secret = process.env.JWT_SECRET;

const token = jwt.sign({
  sub: userId,
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (15 * 60), // 15 mins (short-lived)
  jti: crypto.randomUUID() // unique for revocation / blacklist
}, secret, {
  algorithm: 'HS256'
});

// 2. SENDING (cookie best practices)
// Protects against XSS and CSRF
res.cookie('token', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict'
});

// 3. VERIFYING
// CRITICAL: whitelist allowed algorithm
jwt.verify(token, secret, { algorithms: ['HS256'] }, (err, decoded) => {
  if (err) {
    // handle invalid token
  }
  // trust payload
});
```

### JWT checklist

- [ ] Algorithm explicitly specified on verification (never trust the token header).
- [ ] `alg: none` rejected.
- [ ] Secret is 256+ bits random (not a password or phrase).
- [ ] `exp` claim always set and validated.
- [ ] Tokens stored in httpOnly cookies (not localStorage / sessionStorage).
- [ ] Refresh token rotation (old refresh token invalidated on use).
