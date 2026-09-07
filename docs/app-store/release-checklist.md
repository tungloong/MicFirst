# App Store Release Checklist

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

If sandboxing prevents the core input-switching behavior, use GitHub notarized
direct distribution instead of Mac App Store distribution.
