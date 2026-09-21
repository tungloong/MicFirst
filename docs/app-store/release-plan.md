# Dual-Channel Release Plan

MicFirst ships through two channels: a free Mac App Store release and an
open-source direct download from GitHub. This document records what is
verified, what is blocked, and the exact next actions for each channel.

## Channel independence

The two channels use different signing identities, so they are blocked on
different things.

| Channel | Signing identity | Blocked by |
| --- | --- | --- |
| Mac App Store | Apple Distribution (already installed) | App Store Connect app record |
| GitHub direct download | Developer ID Application (missing) | Certificate creation |

The Mac App Store path is not blocked by the missing Developer ID Application
certificate. The App Store identity is already present in the login keychain:
`Apple Distribution: TENGLONG LI (25U9Y73TKD)`.

## Verified on this machine

- `asc` 5.4.0 authenticates with the configured API key.
- Bundle ID `com.tungloong.AudioInputLocker` is registered as `RS58GWWQU2`.
- A `MAC_APP_STORE` provisioning profile was created and downloaded
  successfully (`MicFirst Mac App Store`).
- `asc xcode archive` produces a valid Release archive for the project.
- `asc xcode export-options generate` resolves the correct signing and
  installer certificates for manual signing with team `25U9Y73TKD`.
- App Sandbox does not block the core Core Audio behavior. A sandboxed probe
  app enumerated devices, read the default input, switched the default input
  device, read and wrote input volume, and received device-list and
  default-input change notifications. See the coverage limits below.

## Blocked: App Store Connect app record

`asc xcode export` and `asc publish appstore` both fail until an app record
exists for the bundle ID:

```
error: exportArchive Error Downloading App Information
  App record with bundle identifier "com.tungloong.AudioInputLocker"
  not found on App Store Connect.
```

The public App Store Connect API cannot create app records. Creating one needs
an Apple web session with the Apple ID password and two-factor code, so this
step is yours to run:

```sh
asc web auth login --apple-id "your@email.com"
asc web apps create \
  --name "MicFirst" \
  --bundle-id "com.tungloong.AudioInputLocker" \
  --sku "micfirst-macos-1" \
  --platform MAC_OS \
  --version "1.0"
```

After the record exists, check readiness with `asc status --app <APP_ID>` and
`asc validate --app <APP_ID>`.

## Next actions

### 1. Create the App Store Connect app record

Blocked on your Apple web session login. Everything downstream is scripted.

### 2. Fill the App Store listing

`docs/app-store/metadata.md` already has English and Simplified Chinese copy.
The privacy declaration needs a web session too:

```sh
asc web privacy plan --app <APP_ID>
asc web privacy set --app <APP_ID> --data-not-collected --confirm
```

Also required before submission:

- Age rating (no objectionable content).
- Pricing set to Free.
- Category Utilities.
- Screenshots. macOS uses the `APP_DESKTOP` slot at 1280x800, 1440x900,
  2560x1600, or 2880x1800. The existing `docs/assets/screenshots/` images are
  the source material.

### 3. Real-device validation

The sandbox probe only had the built-in microphone available, so the
external-device paths are untested. Before submitting, confirm on real
hardware that the sandboxed build can:

- Switch to and from a USB microphone.
- Handle AirPods auto-switching.
- Recover after unplugging the current input.

### 4. Decide the HUD's fate in the App Store build

The restoration HUD depends on an Accessibility snapshot delivered by a
Debug-only helper through `DistributedNotificationCenter`. App Sandbox blocks
that path, so a sandboxed release build cannot position the HUD and
suppresses it. The menu bar app, priority list, automatic switching, and
Settings all work without it.

The choice is a product decision, not a technical one:

- Ship the App Store build without the HUD and let the direct-download build
  keep it. This needs no code change and is the fastest path.
- Redesign HUD placement to avoid Accessibility entirely.
- Gate HUD support on an entitlement the App Store build does not request.

### 5. Publish the GitHub direct download

Blocked on the Developer ID Application certificate, which only you can
create. It cannot be created through the App Store Connect API:
`asc certificates create --certificate-type DEVELOPER_ID_APPLICATION` returns
403. Create it in the Apple Developer web portal, download the `.cer`, and
pair it with a private key generated on this machine.

Once the identity appears in `security find-identity -v -p codesigning`, run:

```sh
SIGNING_IDENTITY='Developer ID Application: TENGLONG LI (25U9Y73TKD)' \
NOTARY_PROFILE='MicFirst-notary' \
  ./scripts/package-signed-release.sh 1.0.0 1
```

The existing script builds a universal binary, notarizes, staples, and
produces the DMG and ZIP with checksums. It never falls back to ad hoc
signing. Notarization can also run through the configured API key with
`asc notarization submit --file <path> --wait` if you prefer not to store a
notarytool keychain profile.

## Sandbox probe coverage limits

The probe ran on this Mac with only the built-in microphone present. It
verified the Core Audio calls themselves, not device-family behavior. Treat
USB and Bluetooth results as unverified until step 3 is done.

## Notes

- The bundle ID `com.tungloong.AudioInputLocker` and preference key
  `inputPriorityPreferences.v1` are intentional compatibility identifiers.
- Keep `docs/app-store/metadata.md` and both README files in sync with the
  final download links after publishing.
