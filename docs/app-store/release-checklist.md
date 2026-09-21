# App Store Release Checklist

The dual-channel plan, including the verified signing state and the two
remaining blockers, is in [release-plan.md](release-plan.md).

## App Store Connect

- Create a macOS app record for `MicFirst`.
- Keep the existing bundle ID `com.tungloong.AudioInputLocker` and use the
  matching explicit App ID in the Apple Developer account. The MicFirst rename
  preserves this identifier for continuity with existing installations.
- Price: Free.
- Fill English and Simplified Chinese metadata from `docs/app-store/metadata.md`.
- Validate a public MicFirst privacy-policy URL for submission. The current
  policy is `https://github.com/tungloong/MicFirst/blob/main/docs/privacy.md`;
  do not use AudioInputLocker's website as MicFirst's policy.
- Set app privacy details to data not collected.

## Build Validation

- Build Debug and Release.
- Confirm the app bundle contains:
  - `MicFirst.app`
  - App icon assets
  - `en.lproj/Localizable.strings`
  - `zh-Hans.lproj/Localizable.strings`
  - `PrivacyInfo.xcprivacy`
- Validate App Sandbox behavior on a real Mac:
  - Enumerate input devices.
  - Switch the default input device.
  - Read and write input volume when supported.
  - Restore the highest-priority available input after an external switch.
  - Reconnect a USB microphone.
  - Test AirPods auto-switching.

The Core Audio calls above were verified with a sandboxed probe app on this
Mac: enumeration, reading the default input, switching it, reading and writing
input volume, and both device-list and default-input listeners all work inside
App Sandbox. The probe had only the built-in microphone available, so the USB
and AirPods rows remain unverified.
