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

No MicFirst binary release has been published yet.
