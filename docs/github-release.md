# MicFirst Repository and Release Preparation

- Repository: [tungloong/MicFirst](https://github.com/tungloong/MicFirst)
- Product: microphone priorities with automatic fallback and route restoration.
- License: MIT; original AudioInputLocker contributor attribution is retained.
- Distribution: source-only until the first MicFirst binary is published.
- Privacy policy: [docs/privacy.md](privacy.md).
- No MicFirst website has been deployed. The AudioInputLocker website belongs to that product.

## Repository boundary

MicFirst starts from its own initial source snapshot. AudioInputLocker's code,
release tags, and downloads stay in its original repository. See
[product decisions](product-decisions.md). The existing local checkout can keep
its directory name; `origin` is MicFirst, and the old repository can be retained
as an explicitly named `audioinputlocker` remote.

## First binary release

- Confirm `main` builds and its GitHub Actions build/tests pass.
- Test relevant real USB/Bluetooth switching scenarios.
- Capture current MicFirst screenshots; historical AudioInputLocker screenshots
  must not be presented as MicFirst UI.
- Choose a MicFirst version and pass it explicitly to
  `./scripts/package-preview-release.sh VERSION`.
- New archives use `MicFirst-$VERSION-macos-arm64.zip` and contain `MicFirst.app`.
- Validate signing, notarization, and installation before publishing binaries.
- Update both READMEs with the actual MicFirst download and version.
- App Store preparation is separate; confirm the installation identity,
  compatibility strategy, privacy URL, and sandbox behavior before submission.

Creating and uploading this repository does not itself publish an app binary.

## Developer ID distribution

The first public installer is waiting for a **Developer ID Application**
certificate with its private key and an Apple notarization credential profile.
Apple Development and Apple Distribution certificates do not replace this
identity for downloads outside the Mac App Store. Do not publish an unsigned
preview as a substitute for the requested signed release.

1. Install the Developer ID Application certificate and its private key in the
   local login keychain. Confirm it appears in `security find-identity -v -p codesigning`.
2. Store notarization credentials locally using the interactive command
   `xcrun notarytool store-credentials MicFirst-notary`. Use an Apple account
   authorized for the developer team and an app-specific password, or an
   authorized App Store Connect API key. Never commit credentials or paste
   passwords/private keys into issue or chat messages.
3. Run from the repository (substitute the actual identity):

   ```sh
   SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
   NOTARY_PROFILE='MicFirst-notary' \
   ./scripts/package-signed-release.sh 1.0.0 1
   ```

The script builds arm64 + x86_64 with hardened runtime, verifies the signature,
notarizes and staples the app, creates a drag-to-Applications DMG, then signs,
notarizes, staples and checks that DMG. It also provides a ZIP containing the
stapled app and `SHA256SUMS` in `dist/1.0.0/`. Credential validation and signing
must pass; output is never silently downgraded to ad hoc signing. Existing
version output is not overwritten. The script does not upload artifacts.

Before publication, validate the mounted DMG and copied app, confirm GitHub CI
passes for the release commit, and record any remaining runtime limitations.
Standalone Release currently suppresses the HUD because its startup anchor
source is not integrated; signing does not change that behavior. Do not describe
that notification feature as working in a downloadable build until verified.
The signing and notarization stages have not yet been exercised with a Developer
ID identity on this machine.
