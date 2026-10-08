# Changelog

Changes to MicFirst are recorded here. AudioInputLocker is a separate product;
its release history remains in [its repository](https://github.com/tungloong/AudioInputLocker/releases).

## 1.0.2 - 2026-10-08

- The menu bar microphone now has nine states driven by the input volume
  setting and automatic priority: an unknown volume shows a plain microphone
  (locked when automatic priority is on); a confirmed zero shares one muted
  microphone; low, medium, and high volumes show one, two, and three sound
  waves, each with unlocked and locked variants. An unreadable volume no
  longer appears as muted. These reflect the input volume setting, not live
  audio levels.
- On macOS 26 and later, sound-wave changes animate with the native Draw
  on/off and replacement symbol effects; earlier systems and Reduce Motion
  show static updates.
- The restoration HUD now uses the two-state mascot at 34 pt: running with
  the No. 1 baton while Input Priority is on, resting with folded arms while
  it is off. Layout, wording, and timing are unchanged.
- Covered the nine menu-bar states and unknown-volume handling with hostless
  regression tests.

## 1.0.1 - 2026-10-04 (Mac App Store only; no GitHub release)

- The restoration HUD now moves aside while a system AirPods, volume, or
  brightness banner is on screen, in shipped sandboxed builds as well as Debug.
  It finds the banner's host window in public window metadata while the HUD is
  visible; no permission, window title, or image is involved.
- A HUD presented while a banner is showing appears beside it. A banner that
  appears under a visible HUD makes it slide to the nearest free side of the same
  row, where it stays until it is dismissed.
- Retired the Debug-only Accessibility startup helper. Placement no longer used
  its Sound and Control Center positions, and the HUD reads MicFirst's own icon
  from its status-bar window, so Debug launches skip the helper's compile step
  and 10-second handshake and no longer need an Accessibility-authorized terminal.
- Added `scripts/diagnostics/watch-system-banner-hosts.swift` to re-check the
  banner host on another macOS version.
- The HUD now appears only when MicFirst itself changes the input. When a device
  arrives or leaves, MicFirst waits 0.3 seconds for the system's own route change.
  If macOS lands on the priority device, MicFirst writes nothing and stays silent,
  so connecting or putting away top-priority AirPods no longer shows the HUD.
  An external takeover is still restored immediately.
- Fixed a HUD that could vanish right after appearing when it was dismissed and
  presented again in quick succession, as when the system repeats a route change.

## 1.0.0 - 2026-10-01

- First public release: universal Developer ID signed and notarized DMG and ZIP,
  and the [Mac App Store](https://apps.apple.com/us/app/micfirst/id6814898645?mt=12) version.

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
