# Upload skedaresh / Insecure file upload

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

File uploads duhet te validojne tip, permbajtje, dhe madhesi per te parandaluar sulme.

### Kerkesat e validimit

**1. Tipi i skedarit.**
- Kontrollo extension kunder allowlist.
- Valido magic bytes / file signature qe perputhen me tipin e pritur.
- Mos u mbeshtet vetem ne nje kontroll.

**2. Permbajtja.**
- Lexo dhe verifiko magic bytes.
- Per images: prov te procesosh me image library (kap files te keqformuara).
- Per dokumente: scan per makro, embedded objects.
- Kontrollo per polyglot files (valide si me shume tipe).

**3. Madhesia.**
- Vendos maksimum server-side.
- Konfiguro limitin edhe te web server / proxy.
- Konsidero limit per-tip (images me te vegjel se videos).

### Bypass-e dhe sulme te zakonshme

| Sulmi | Pershkrim | Parandalimi |
|-------|-----------|-------------|
| Extension bypass | `shell.php.jpg` | Kontrollo extension te plote, perdor allowlist |
| Null byte | `shell.php%00.jpg` | Sanitize filename, kontrollo null bytes |
| Double extension | `shell.jpg.php` | Lejo vetem nje extension |
| MIME spoofing | Set Content-Type to image/jpeg | Valido magic bytes |
| Magic byte injection | Prepend magic bytes te vlefshme | Parse strukturen e plote, jo vetem header |
| Polyglot files | File valide si JPEG dhe JS | Parse si tipi i pritur, refuzo nese invalide |
| SVG me JavaScript | `<svg onload="alert(1)">` | Sanitize SVG ose mos e lejo fare |
| XXE via upload | DOCX, XLSX malicious (XML) | C'aktivizo external entities |
| ZIP slip | `../../../etc/passwd` ne archive | Valido path-et e ekstraktuara |
| ImageMagick exploits | Images te keqformuara | Update ImageMagick, perdor policy.xml |
| Filename injection | `; rm -rf /` ne filename | Sanitize filename, perdor emra random |
| Content-type confusion | MIME sniffing nga browser | `X-Content-Type-Options: nosniff` |

### Magic bytes reference

| Tipi | Magic bytes (hex) |
|------|-------------------|
| JPEG | `FF D8 FF` |
| PNG | `89 50 4E 47 0D 0A 1A 0A` |
| GIF | `47 49 46 38` |
| PDF | `25 50 44 46` |
| ZIP | `50 4B 03 04` |
| DOCX / XLSX | `50 4B 03 04` (ZIP-based) |

### Trajtim i sigurt i upload

1. **Riemertim.** Perdor UUID random, hidh emrin origjinal.
2. **Storage jashte webroot.** Ose perdor domain te ndare per uploads.
3. **Serve me headers korrekt:**
   - `Content-Disposition: attachment` (force download).
   - `X-Content-Type-Options: nosniff`.
   - `Content-Type` qe perputhet me file aktual.
4. **CDN / domain te ndare.** Izolo permbajtjen e ngarkuar nga app kryesor.
5. **Permissions restriktive.** File-t e ngarkuara s'duhet te jene executable.

---

## English

File uploads must validate type, content, and size to prevent attacks.

### Validation requirements

**1. File type.**
- Check extension against allowlist.
- Validate magic bytes / file signature match expected type.
- Never rely on a single check.

**2. Content.**
- Read and verify magic bytes.
- For images: attempt to process with image library (catches malformed files).
- For documents: scan for macros, embedded objects.
- Check for polyglot files (files valid as multiple types).

**3. Size.**
- Set max size server-side.
- Configure web server / proxy limits too.
- Consider per-type limits (images smaller than videos).

### Common bypasses and attacks

| Attack | Description | Prevention |
|--------|-------------|------------|
| Extension bypass | `shell.php.jpg` | Check full extension, allowlist |
| Null byte | `shell.php%00.jpg` | Sanitize filename, check null bytes |
| Double extension | `shell.jpg.php` | Allow only single extension |
| MIME spoofing | Content-Type set to image/jpeg | Validate magic bytes |
| Magic byte injection | Prepend valid magic bytes to malicious file | Parse entire file, not just header |
| Polyglot files | File valid as JPEG and JavaScript | Parse as expected type, reject if invalid |
| SVG with JavaScript | `<svg onload="alert(1)">` | Sanitize SVG or disallow entirely |
| XXE via upload | Malicious DOCX, XLSX (XML) | Disable external entities |
| ZIP slip | `../../../etc/passwd` in archive | Validate extracted paths |
| ImageMagick exploits | Specially crafted images | Update ImageMagick, use policy.xml |
| Filename injection | `; rm -rf /` in filename | Sanitize filenames, use random names |
| Content-type confusion | Browser MIME sniffing | `X-Content-Type-Options: nosniff` |

### Magic bytes reference

| Type | Magic bytes (hex) |
|------|-------------------|
| JPEG | `FF D8 FF` |
| PNG | `89 50 4E 47 0D 0A 1A 0A` |
| GIF | `47 49 46 38` |
| PDF | `25 50 44 46` |
| ZIP | `50 4B 03 04` |
| DOCX / XLSX | `50 4B 03 04` (ZIP-based) |

### Secure upload handling

1. **Rename files.** Use random UUID names, discard original.
2. **Store outside webroot.** Or use a separate domain for uploads.
3. **Serve with correct headers:**
   - `Content-Disposition: attachment` (forces download).
   - `X-Content-Type-Options: nosniff`.
   - `Content-Type` matching actual file type.
4. **CDN / separate domain.** Isolate uploaded content from main app.
5. **Restrictive permissions.** Uploaded files should not be executable.
