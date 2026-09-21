# Changelog

Changes to MicFirst are recorded here. AudioInputLocker is a separate product;
its release history remains in [its repository](https://github.com/tungloong/AudioInputLocker/releases).

## Unreleased

- Established MicFirst as an independent product and source repository.
- Added persistent microphone priorities with draggable online and offline devices.
- Automatically select the highest-priority available input, fall back on disconnect,
  and restore the route after external changes.
- Manual input selection disables automatic mode while preserving priority order.
- Added native Settings with a complete numbered device list, visibility controls,
  and offline-device deletion. Hidden devices do not participate in automatic selection.
- Collapse offline devices from the menu after five minutes and reveal drag handles
  together when hovering over the list.
- Refined the restoration HUD with clear Liquid Glass over Popover material at
  0.80 opacity, system-accent controls, and a persistent Settings visibility switch.
- Added horizontal HUD avoidance using Sound/Control Center menu-button snapshots;
  the sandboxed development helper acquires a startup snapshot with bounded retries
  and acknowledgement, so slow launch or incomplete geometry cannot silently consume
  the only delivery. Standalone
  HUD integration remains pending.
- Preserve the system MenuBarExtra window and event-triggered glass appearance
  refreshes without recurring one-second appearance maintenance.
- Included English and Simplified Chinese, isolated UI previews, and HUD/route regressions.
- Retired one-off native-HUD probes and tint/material experiments after recording
  their outcomes.
- Preserved existing local configuration compatibility identifiers.
- Recorded the 2026-09-07 decision not to pursue multi-microphone mixing/fusion
  in the near term; see [product decisions](docs/product-decisions.md).

## Unreleased — Dual-channel release preparation

- Verified that App Sandbox does not block MicFirst's Core Audio behavior.
  A sandboxed probe app enumerated devices, read and switched the default input
  device, read and wrote input volume, and received device and default-input
  change notifications. Only the built-in microphone was available, so USB and
  AirPods paths remain unverified.
- Registered the App Store bundle ID `com.tungloong.AudioInputLocker` and
  created a Mac App Store provisioning profile with the existing Apple
  Distribution identity.
- Confirmed `asc xcode archive` and `asc xcode export-options generate` produce
  a valid App Store export configuration for this project.
- Documented the dual-channel release plan and the two remaining blockers: the
  App Store Connect app record and the Developer ID Application certificate.
  See [release-plan.md](docs/app-store/release-plan.md).

No MicFirst binary release has been published yet.
