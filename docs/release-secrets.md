# Release secrets and one-time setup

Kujto Studio ships through two channels. Each channel has its own GitHub Actions workflow and its own set of required secrets. Everything below is a one-time setup, done by the maintainer, before the first release.

## Channel 1: Mac App Store

Workflow: [`.github/workflows/release-app-store.yml`](../.github/workflows/release-app-store.yml)
Tag pattern: `v1.0.0-appstore`

### Certificates

1. In [Apple Developer > Certificates](https://developer.apple.com/account/resources/certificates/list), create:
   - **3rd Party Mac Developer Application** (for signing the .app)
   - **3rd Party Mac Developer Installer** (for signing the .pkg)
2. Export each from Keychain Access as a .p12 with a strong password.
3. `base64 -i mac_app.p12 -o mac_app.p12.b64` and copy the contents.

### App Store Connect API key

1. In [App Store Connect > Users and Access > Integrations](https://appstoreconnect.apple.com/access/api), create an API key with **App Manager** role.
2. Download the `.p8` file (only shown once).
3. Note the Issuer ID and the Key ID.

### GitHub secrets to add

| Name | Value |
| --- | --- |
| `APP_STORE_TEAM_ID` | Your 10-character Apple Team ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from App Store Connect |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of the .p8 file |
| `MAC_APP_STORE_CERTIFICATE` | Base64 of the App .p12 |
| `MAC_APP_STORE_CERTIFICATE_PWD` | Password for the App .p12 |
| `MAC_INSTALLER_CERTIFICATE` | Base64 of the Installer .p12 |
| `MAC_INSTALLER_CERTIFICATE_PWD` | Password for the Installer .p12 |
| `KEYCHAIN_PASSWORD` | Any strong password, used only inside the runner |

## Channel 2: Ko-fi (Direct)

Workflow: [`.github/workflows/release-kofi.yml`](../.github/workflows/release-kofi.yml)
Tag pattern: `v1.0.0-direct`

### Certificates

Create **two** Developer ID certificates in Apple Developer:

- **Developer ID Application** (signs the .app)
- **Developer ID Installer** (signs the .pkg)

Export each as a .p12 with a strong password. Note the identity strings; they look like `Developer ID Application: Petros Dhespollari (TEAMID)` and `Developer ID Installer: Petros Dhespollari (TEAMID)`.

### Notarization

Create an app-specific password at [appleid.apple.com](https://appleid.apple.com) under Sign-In and Security > App-Specific Passwords.

### Sparkle EdDSA key pair

Sparkle signs each appcast entry with an ed25519 key. Generate the pair once, keep the private key in secrets, and paste the public key into `project.yml` (`INFOPLIST_KEY_SUPublicEDKey` under the `Release-Direct` config).

```
brew install sparkle-project/homebrew-sparkle/sparkle-bin
generate_keys       # writes to ~/Library/Application Support/Signing Keys/
generate_keys -p    # prints the public key you paste into project.yml
```

Then export the private key as base64:

```
base64 < ~/Library/Application\ Support/Signing\ Keys/ed_priv | pbcopy
```

### GitHub secrets to add

| Name | Value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_CERT` | Base64 of the Application .p12 |
| `DEVELOPER_ID_APPLICATION_CERT_PWD` | Password for the Application .p12 |
| `DEVELOPER_ID_APPLICATION_NAME` | Application identity string |
| `DEVELOPER_ID_INSTALLER_CERT` | Base64 of the Installer .p12 |
| `DEVELOPER_ID_INSTALLER_CERT_PWD` | Password for the Installer .p12 |
| `DEVELOPER_ID_INSTALLER_NAME` | Installer identity string |
| `APPLE_ID` | The Apple ID email |
| `APPLE_ID_APP_PASSWORD` | The app-specific password |
| `APPLE_TEAM_ID` | Your 10-character Apple Team ID |
| `SPARKLE_ED_PRIVATE_KEY` | Base64 of the ed25519 private key |
| `KEYCHAIN_PASSWORD` | Any strong password, used only inside the runner |

## Tagging a release

```
git tag v1.0.0-appstore && git push --tags   # ships to App Store Connect
git tag v1.0.0-direct   && git push --tags   # ships to Ko-fi via GitHub Release + Sparkle
```

Both workflows can also be dispatched manually from the Actions tab with a version input.

## What the Direct workflow does after a build

1. Archives and signs the app with Developer ID Application
2. Notarizes the app via `notarytool submit --wait` and staples the ticket
3. Wraps it into a signed installer PKG (`pkgbuild` + `productsign` with Developer ID Installer)
4. Notarizes the PKG and staples the ticket
5. Signs the PKG bytes with the Sparkle EdDSA key
6. Appends a new `<item>` to `site/appcast.xml` with `sparkle:installationType="package"`
7. Commits the appcast update back to `main` so `kujto.peterdsp.dev/appcast.xml` picks it up
8. Publishes a GitHub Release with the PKG attached

Sparkle in the shipped app reads `SUFeedURL` (`https://kujto.peterdsp.dev/appcast.xml`), sees the new item, downloads the PKG, verifies the ed25519 signature, then hands it to `installer(8)` to overwrite `/Applications/Kujto Studio.app`.
