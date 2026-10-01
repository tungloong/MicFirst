# Changelog

Changes to MicFirst are recorded here. AudioInputLocker is a separate product;
its release history remains in [its repository](https://github.com/tungloong/AudioInputLocker/releases).

## 1.0.0 - 2026-10-01

- First public release: universal Developer ID signed and notarized DMG and ZIP.

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
- Anchor the restoration HUD to MicFirst's own menu-bar window so Debug, Release,
  and sandboxed launches can present it without an Accessibility helper. The Debug
  helper still supplies Sound and Control Center positions for horizontal avoidance.
- Preserve the system MenuBarExtra window and event-triggered glass appearance
  refreshes without recurring one-second appearance maintenance.
- Included English and Simplified Chinese, isolated UI previews, and HUD/route regressions.
- Retired one-off native-HUD probes and tint/material experiments after recording
  their outcomes.
- Use bundle ID `com.tenglong.MicFirst` for GitHub and Mac App Store packages.
  Ignore retired AudioInputLocker lock preferences. Keep the preference key
  `inputPriorityPreferences.v1`.
- Recorded the 2026-09-07 decision not to pursue multi-microphone mixing/fusion
  in the near term; see [product decisions](docs/product-decisions.md).

No MicFirst binary release has been published yet.
