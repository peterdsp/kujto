# Path traversal

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Path traversal ndodh kur input i perdoruesit kontrollon path skedari, duke lejuar akses ne file jashte direktorive te synuara.

### Pattern-a te prekshem

```python
# VULNERABLE
file_path = "/uploads/" + user_input
file_path = base_dir + request.params['file']
template = "templates/" + user_provided_template
```

### Strategjite e parandalimit

**1. Shmang input perdoruesi ne path.**

```python
# Ne vend te perdorimit direkt te input-it
# Perdor reference indirekte
files = {'report': '/reports/q1.pdf', 'invoice': '/invoices/2024.pdf'}
file_path = files.get(user_input)  # None nese invalide
```

**2. Canonicalization dhe validim.**

```python
import os

def safe_join(base_directory, user_path):
    base = os.path.abspath(os.path.realpath(base_directory))
    target = os.path.abspath(os.path.realpath(os.path.join(base, user_path)))

    if os.path.commonpath([base, target]) != base:
        raise ValueError("Error!")

    return target
```

**3. Sanitizim input.**
- Hiq ose refuzo `..`.
- Hiq ose refuzo indikatore absolute path (`/`, `C:`).
- Whitelist karaktere (alphanumeric, dash, underscore).
- Valido extension nese aplikohet.

### Lista per path traversal

- [ ] Asnjehere mos perdor input direkt ne path.
- [ ] Canonicalize path dhe valido kunder base directory.
- [ ] Kufizo extension nese aplikohet.
- [ ] Testo me teknika te ndryshme encoding dhe bypass.

---

## English

Path traversal occurs when user input controls a file path, allowing access to files outside intended directories.

### Vulnerable patterns

```python
# VULNERABLE
file_path = "/uploads/" + user_input
file_path = base_dir + request.params['file']
template = "templates/" + user_provided_template
```

### Prevention strategies

**1. Avoid user input in paths.**

```python
# Instead of using user input directly
# Use indirect references
files = {'report': '/reports/q1.pdf', 'invoice': '/invoices/2024.pdf'}
file_path = files.get(user_input)  # Returns None if invalid
```

**2. Canonicalization and validation.**

```python
import os

def safe_join(base_directory, user_path):
    base = os.path.abspath(os.path.realpath(base_directory))
    target = os.path.abspath(os.path.realpath(os.path.join(base, user_path)))

    if os.path.commonpath([base, target]) != base:
        raise ValueError("Error!")

    return target
```

**3. Input sanitization.**
- Remove or reject `..`.
- Remove or reject absolute path indicators (`/`, `C:`).
- Whitelist allowed characters (alphanumeric, dash, underscore).
- Validate file extension if applicable.

### Path traversal checklist

- [ ] Never use user input directly in file paths.
- [ ] Canonicalize paths and validate against base directory.
- [ ] Restrict file extensions if applicable.
- [ ] Test with various encoding and bypass techniques.
