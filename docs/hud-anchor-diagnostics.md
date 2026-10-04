# HUD anchor, live banner hosts, and read-only diagnostics

Current behavior is defined in [input-priority.md](input-priority.md). The HUD
uses untinted clear Liquid Glass over Popover material at 0.80, appears immediately
after a verified restoration, and moves horizontally only while a system banner
host is on screen in its row.

## Own anchor

SwiftUI owns the system `MenuBarExtra(.window)`. `StatusItemController` creates
neither a status item nor a menu panel. It reads MicFirst's own button from this
process's status-bar window when the HUD is presented and when the display
configuration changes; a visible HUD keeps that anchor otherwise. The read works
in Debug, Release, and a sandboxed launch.

For a persistent menu bar, the capsule's top is 9 pt below the work-area top.
For an auto-hidden bar, the captured button bottom supplies the boundary; physical
auto-hide transitions have not been validated. The visible capsule is 235×52 pt
inside a 360×136 pt transparent host. Screen clamping applies to the capsule with
a 6 pt inset; transparent hosting margins may extend offscreen.

## Live banner hosts

`NativeHUDProbe` reads `CGWindowListCopyWindowInfo` for on-screen windows and
keeps Apple's banner hosts. The call is public, needs no permission, and works
inside App Sandbox. MicFirst polls it every 50 ms only while its HUD is visible
and not hovered, and skips its own HUD window, which has a banner host's shape.

| Predicate | Value |
| --- | --- |
| Owner bundle ID | `com.apple.MenuBarAgent`, or `com.apple.controlcenter` at level 2000+ |
| Level | Above the main-menu level (24) |
| Size | 260–560 × 70–190 pt |
| State | On screen, alpha above 0.02 |

Measured on macOS 27.0 (26A428), 1710×1112 pt display, 38 pt menu bar:

| Banner | Host, top-left points | Anchored under | Capsule |
| --- | --- | --- | --- |
| AirPods routing | (1305, 38, 352, 157) | Sound, center 1481 | 235×52, 9 pt below host top |
| Volume | (1305, 38, 352, 157) | Sound, center 1481 | 290×62, 11 pt below host top |
| Display brightness | (1378, 38, 352, 157) | Control Center, center 1563 | 290×62 |
| Keyboard brightness | (1378, 38, 352, 157) | Control Center, center 1563 | 290×62 |

Every host was a MenuBarAgent window at level 101 with an empty title. The
capsule is centered in the host. Under Control Center the capsule stops 11 pt
from the display edge, so the host is not centered on the button and ends 20 pt
beyond the display. Volume and brightness hosts lasted about 1.5 seconds. A
banner that replaces another one reuses the window and moves it.

The Control Center predicate is the query the May 2026 AudioInputLocker code
used on macOS 26. It has not been re-verified. These are observations of one OS
build, not an Apple contract; a future system can move the host again, as
macOS 27 did. When no host matches, the HUD stays at its own anchor.

Public metadata does not identify the banner. MicFirst therefore reserves the
centered 290 pt of the host, which leaves 39.5 pt beside an AirPods capsule and
12 pt beside a volume or brightness capsule.

To re-check the signature, for example on macOS 26 or after a system update:

```sh
swift scripts/diagnostics/watch-system-banner-hosts.swift
```

It prints MenuBarAgent and Control Center windows above the menu bar as they come
and go. Press a volume or brightness key, or connect AirPods, while it runs.

## Opt-in diagnostic commands

```sh
# Simulated devices; initial HUD lifetime extended to 60 seconds.
./scripts/build-and-run.sh --hud-preview --diagnostics

# Real device model and ordinary HUD triggers/lifetime.
./scripts/build-and-run.sh --diagnostics

# Return to ordinary real-device mode.
./scripts/build-and-run.sh
```

Diagnostics require Debug and do not change placement or timing. For up to 120
seconds they sample every 100 ms, writing changes plus a one-second heartbeat to
a unique JSONL file under:

```text
~/Library/Containers/com.tenglong.MicFirst/Data/Library/Application Support/MicFirst/HUDDiagnostics/
```

This sampler is separate from the HUD's own polling; it runs only with the
explicit diagnostic argument and also records hosts while the HUD is hidden.
Appearance support retains only bounded presentation/app-switch bursts, with no
recurring one-second timer.

The log records no screenshots, window titles, audio samples or audio-device
UIDs. It makes no private service calls and requests no additional permission.

| Field | Meaning |
| --- | --- |
| `anchor.buttonFrame` | MicFirst button rectangle from its own status-bar window |
| `anchor.statusWindowFrame` | Menu-region rectangle derived from that button and the current screen work area; not a foreign NSWindow frame |
| `hud.hostFrame` / `hud.capsuleFrame` | Actual own-window geometry and visible capsule |
| `capsuleCenterDeltaFromButton` | Horizontal displacement including intentional avoidance; assess while visible |
| `nativeHosts[].frame` | A matching banner host, in AppKit points |
| `nativeHosts[].ownerBundleID` / `level` | Which predicate matched |

Rectangles use AppKit bottom-left screen points. `backingScale` is recorded
separately; window coordinates are not multiplied by it. Records distinguish
simulated from real devices and include restoration confirmation, preview requests,
presentation, host changes, skipped requests and dismissal events.

To show the HUD on demand in a Debug run, post `MicFirst.ShowPreferredInputHUD`
as described under Validation in [input-priority.md](input-priority.md).

## Checking against real banners and routes

Banners on demand: press a volume key (at volume 0, volume down sets the mute
flag, so restore it afterwards), press a brightness key down then up, or put
AirPods in and take them out. Show the HUD on demand in a Debug run as described
above, and watch hosts with `scripts/diagnostics/watch-system-banner-hosts.swift`.
MicFirst's own HUD is the MicFirst window at level 102, 360×136 pt.

Whether MicFirst wrote the route, or the system did, is in the unified log. In
zsh, `log` is a builtin, so call `/usr/bin/log`:

```sh
/usr/bin/log show --last 10m --info --debug --style compact --predicate \
  '(process == "MicFirst" AND eventMessage CONTAINS "DefaultInputDevice")
   OR (process == "audioaccessoryd" AND eventMessage CONTAINS "route")
   OR (process == "coreaudiod" AND eventMessage CONTAINS "SetDefaultDevice")'
```

Each `MicFirst ... SetData:kAudioHardwarePropertyDefaultInputDevice` line is a
write by MicFirst. `audioaccessoryd` lines show Smart Routing and manual Sound
menu choices; `coreaudiod` `SetDefaultDevice 'dIn '` lines show every default
input change. Adding `process == "bluetoothd" AND eventMessage CONTAINS "in-ear"`
shows AirPods ear states. macOS may block other apps from reading the JSONL
container; the window list and the unified log need no container access.

## Evidence and limits

A matching host means a banner window is on screen. It does not identify the
banner, its capsule width, or how long it will stay. An empty result means no
window matched the predicates, which is also what an unknown future host looks
like.

The September 2026 investigation recorded this host but did not confirm it. The
October 2 measurements in [native-hud-investigation.md](native-hud-investigation.md)
supersede that closure.

Current tests cover fixed-height/horizontal geometry, screen edges, nearest-side
selection, staying aside after a banner leaves, host predicates and coordinate
conversion, own-button selection, HUD preference migration, event-only
appearance bursts, and microphone route regressions. The HUD window lifecycle
(presenting again in place, hover pausing the read, a slide finishing during a
fade) has no hostless test and needs a check on a real Mac after changes. Real
multi-display, auto-hide, macOS 26 and future OS behavior still require device
validation.
