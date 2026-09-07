# Contributing

Thanks for helping improve MicFirst.

Please keep discussion respectful and practical. See `CODE_OF_CONDUCT.md` for
the short project conduct note.

## Development Setup

Requirements:

- macOS 13.0 or later for runtime testing.
- Xcode with the macOS 26 SDK for building the current source.

Use the local build helper:

```sh
./scripts/build-and-run.sh
```

Manual build:

```sh
xcodebuild \
  -project MicFirst.xcodeproj \
  -scheme MicFirst \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  build
```

Run the isolated regression tests (macOS 14+ with Xcode 27's XCTest runtime):

```sh
./scripts/test.sh
```

Review the real menu with simulated devices and isolated preferences:

```sh
./scripts/build-and-run.sh --preview
```

The preview never changes the Mac's audio route. Relaunch without `--preview`
to return to the regular menu bar app. See `docs/input-priority.md` for the rules.

For changes that affect input priority, please test at least one real input
device switching scenario, such as AirPods auto-switching, System Settings
changes, or USB microphone reconnects.

## Pull Requests

- Keep changes focused and easy to review.
- Preserve the native macOS feel of the menu and HUD.
- Update both English and Simplified Chinese user-facing strings when adding UI
  copy.
- Update README or docs when behavior, requirements, privacy notes, or release
  steps change.
- Mention any manual device-switching scenarios you tested.

## Localization

User-facing strings live in:

- `MicFirst/en.lproj/Localizable.strings`
- `MicFirst/zh-Hans.lproj/Localizable.strings`

Please keep the keys aligned between both files.

## Privacy And Networking

MicFirst is intended to stay local-first. Do not add analytics,
telemetry, accounts, or network calls without opening an issue first and
updating the privacy documentation.

## Git Hygiene

- Do not commit `build/`, DerivedData, archives, local Xcode user data, or
  personal environment files.
- Keep generated visual assets in `docs/assets` and app-shipped assets in
  `MicFirst/Assets.xcassets`.
