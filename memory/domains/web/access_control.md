# Kontroll aksesi / Access control

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Kerkesa kryesore

Per cdo pike te dhenash dhe veprim qe kerkon autentikim:

1. **Autorizim ne nivel perdoruesi.**
   - Cdo perdorues hyn vetem ne te dhenat e veta.
   - Asnje perdorues nuk shikon te dhena te perdoruesve te tjere apo organizatave.
   - Verifiko pronesine ne shtresen e te dhenave, jo vetem ne route.

2. **UUID ne vend te ID sekuenciale.**
   - Perdor UUIDv4 ose identifikues te paparashikueshem.
   - Perjashtim: vetem nese perdoruesi e kerkon shprehimisht.

3. **Cikli i jetes se llogarise.**
   - Kur perdoruesi hiqet nga organizata: revoko menjehere tokens dhe sessions.
   - Kur llogaria fshihet ose c-aktivizohet: invalido sessions dhe API keys.
   - Perdor token revocation lists ose token me jete te shkurter me refresh.

### Lista e kontrolleve

- [ ] Verifiko pronesine ne cdo kerkese (mos i beso te dhenave nga klienti).
- [ ] Kontrollo membership ne organizaten per app multi-tenant.
- [ ] Valido lejet e rolit per veprime role-based.
- [ ] Ri-valido pas cdo ndryshimi privilegji.
- [ ] Kontrollo pronesine e burimit prind (psh per nje koment, verifiko pronesine e post-it).

### Te zakonshmet per t'i shmangur

- **IDOR.** Verifiko gjithmone qe perdoruesi ka leje per resource ID te kerkuar.
- **Privilege escalation.** Valido ndryshime rolesh ne server, mos i beso klientit.
- **Horizontal access.** Perdoruesi A qe akseson burimet e Perdoruesit B me te njejtin nivel.
- **Vertical access.** Perdoruesi normal qe akseson funksionalitet admin.
- **Mass assignment.** Filtro fushat qe perdoruesi mund te update-oje.

### Model implementimi (pseudokod)

```
function getResource(resourceId, currentUser):
    resource = database.find(resourceId)

    if resource is null:
        return 404  # mos zbulo nese burimi ekziston

    if resource.ownerId != currentUser.id:
        if not currentUser.hasOrgAccess(resource.orgId):
            return 404  # 404 jo 403, per te shmangur enumerimin

    return resource
```

---

## English

### Core requirements

For every data point and action that requires authentication:

1. **User-level authorization.**
   - Each user must only access their own data.
   - No user accesses data from other users or organizations.
   - Verify ownership at the data layer, not just the route.

2. **UUIDs instead of sequential IDs.**
   - Use UUIDv4 or non-guessable identifiers.
   - Exception: only when the user explicitly requests sequential IDs.

3. **Account lifecycle.**
   - When a user is removed from an org: revoke tokens and sessions immediately.
   - When an account is deleted or deactivated: invalidate sessions and API keys.
   - Use token revocation lists or short-lived tokens with refresh.

### Checks checklist

- [ ] Verify user owns the resource on every request (do not trust client data).
- [ ] Check org membership for multi-tenant apps.
- [ ] Validate role permissions for role-based actions.
- [ ] Re-validate after any privilege change.
- [ ] Check parent resource ownership (e.g. for a comment, verify the post's owner).

### Common pitfalls

- **IDOR (Insecure Direct Object Reference).** Always verify the requesting user has permission for the requested resource ID.
- **Privilege escalation.** Validate role changes server-side, never trust the client.
- **Horizontal access.** User A reaching User B's resources at the same privilege level.
- **Vertical access.** Regular user reaching admin functionality.
- **Mass assignment.** Filter which fields users can update.

### Implementation pattern (pseudocode)

```
function getResource(resourceId, currentUser):
    resource = database.find(resourceId)

    if resource is null:
        return 404  # do not reveal whether the resource exists

    if resource.ownerId != currentUser.id:
        if not currentUser.hasOrgAccess(resource.orgId):
            return 404  # return 404 not 403 to prevent enumeration

    return resource
```
