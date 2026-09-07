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
