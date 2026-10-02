# Input Priority

MicFirst manages an ordered input list. AudioInputLocker remains a separate
single-device locking product; see [product decisions](product-decisions.md).
Initial approved design: [AudioInputLocker — Input Priority](https://www.figma.com/design/fHeuW39q1nTrezZCtfAK7c/AudioInputLocker-%E2%80%94-Input-Priority?node-id=1-1410).

## Behavior

| Action or event | Result |
| --- | --- |
| Enable Input Priority | Immediately select the first available remembered device. |
| External input change | Restore the highest available device while enabled. |
| Device disconnects | Use the next eligible device. Keep the gray menu row for five minutes, then collapse it; retain the full Settings entry. |
| Higher device reconnects | Return to the menu and switch to it while enabled, unless manually hidden. |
| Click a different online device | Disable automatic mode, keep order, and select that device. |
| Click current or offline device | No change to mode or order. |
| Drag online or offline device | Commit order on drop; recalculate the route if enabled. Settings always includes the complete list. |
| Uncheck Show in Menu | Hide the online device and exclude it from automatic selection. Keep its priority. |
| Check Show in Menu | Restore the device and recalculate the route if automatic mode is enabled. |
| Delete an offline device in Settings | Forget its entry; a future reconnect appends it at the bottom. |
| No eligible devices available | Keep the switch on, leave the current system route alone, and wait. |

Manual hiding persists across disconnects and relaunches. Automatic offline collapse
does not change that preference. The Settings visibility checkbox reflects the
current menu state and is read-only while offline. All devices can still be sorted
in Settings, and only offline devices have a delete button.

The menu uses a single list-wide hover state for its drag handles. Reordering a
filtered menu permutes only its visible slots; omitted devices retain their full-list
positions. A change to the displayed UIDs cancels an in-progress drag.

Automatic input has no pause, countdown, or timed resume. The HUD's lock-shaped
button now controls the same global mode and never changes priority order.

On macOS 26+, the HUD capsule is a clear-filled SwiftUI shape with
`glassEffect(.clear.interactive(false), in:)` inside one `GlassEffectContainer`.
Behind the SwiftUI glass, the hosting container adds an `NSVisualEffectView`
with `.popover` material, `.behindWindow` blending, `.active` state, and
`alphaValue = 0.80`, clipped to the 235×52 pt capsule. This is the user-approved
readability recipe from September 8. Text and controls sit above both effects.
The glass has no tint, extra rim strokes, or custom capsule shadows; the system
renders its edges and refraction. macOS 13–15 retains the existing fallback.
The enabled priority button uses the system accent color. The hover-only close
button uses an opaque system window background and primary label color so its
contrast does not depend on the content behind the glass.

The menu uses the system SwiftUI `MenuBarExtra` with `.window` style again.
The intermediary `NSPopover` and attempted custom `NSPanel` were removed.
SwiftUI owns the native menu chrome and outside-click dismissal; existing menu
controls and Settings continue using their native SwiftUI environment. Opening
the menu dismisses the HUD via the menu content's appearance callback.

The HUD prefers the center of MicFirst's own menu-bar button, with its capsule
9 pt below the menu bar. `StatusItemController` only provides that anchor; it
creates no menu window or status item. An unavailable own anchor suppresses HUD
presentation.

**System banners are avoided live.** Apple draws its AirPods routing, volume,
display-brightness and keyboard-brightness banners inside a transparent host
window. Public window metadata (`CGWindowListCopyWindowInfo`) lists that host
without any permission, also inside App Sandbox, so shipped builds avoid the
banners too. While the HUD is visible, MicFirst reads the on-screen list every
50 ms (about 0.2 ms per read) and keeps windows that are 260–560 × 70–190 pt,
above the menu-bar level, not transparent, and owned by MenuBarAgent (macOS 27)
or by Control Center at level 2000+ (the macOS 26 query). It reads owner, level,
alpha and bounds only. No title, image or content is read, nothing is stored, and
nothing is polled while the HUD is hidden.

The banner's capsule is centered in its host. Metadata does not say which banner
is showing, so MicFirst keeps the widest measured capsule clear: the centered
290 pt of the host (volume and brightness; AirPods routing is 235 pt).

- No banner in the HUD's row: the HUD uses its own anchor.
- A banner is already showing: the HUD appears beside it.
- A banner appears under a visible HUD: the HUD slides aside in 0.3 seconds, or
  jumps with Reduce Motion. A banner that moves or is replaced is followed.
- The HUD takes the nearest free position in the same row, 12 pt from the
  reserved region and inside the display. If neither side fits, skip the
  notification; never move it to a lower row.
- A HUD that moved aside stays there after the banner leaves. The next
  presentation starts from the own anchor again.
- A hovered HUD does not move; pointer exit re-evaluates its placement.

No five-second delay remains: confirmed restoration notifications appear
immediately. Route verification and the normal 4.2-second visible
duration/hover behavior remain unchanged.

Settings includes **Show HUD Notifications**, enabled by default for both new and
existing installations. It persists in `inputPriorityPreferences.v1` independently
of automatic input. Turning it off dismisses visible HUDs; turning it back on does
not replay old events.

**Own icon.** The HUD reads MicFirst's menu-bar button from this process's
status-bar window at presentation time. Debug, Release, and a sandboxed launch
all use that frame, so the HUD no longer depends on an external helper to appear.
Moving the menu icon is picked up on the next presentation. No entitlement,
private API, or permission prompt is used.

**The Debug startup snapshot is diagnostic.** `build-and-run.sh` still invokes
an external public-Accessibility helper once per Debug launch. Within a
10-second deadline it reads Sound and Control Center geometry, plus MicFirst's
own button as a fallback, and retries until the app acknowledges a usable
own-button anchor. Invalid or incomplete snapshots leave the receiver open.
Retries share a delivery ID so a lost acknowledgement can be repeated without
applying the snapshot again. The helper confirms acknowledgement and exits; the
app removes its receiver on confirmation, with a 30-second startup cleanup
deadline for abandoned handshakes. The helper needs an already-authorized
Accessibility execution context. If it cannot deliver, the launch script warns
and nothing about placement changes.

The snapshot no longer drives placement. Its Sound and Control Center positions
are recorded in opt-in diagnostics, and its own-button rectangle is a fallback
only while the status-bar window is not available yet. A banner can anchor to
either button and its host can extend past the display, so a button position
does not predict the banner. Debug and shipped builds place the HUD the same way.
See [native HUD investigation](native-hud-investigation.md) for the measurements.

The HUD uses a borderless `NSWindow` at `NSWindow.Level.popUpMenu + 1`, above
ordinary pop-up menus, and refuses actual key/main status. On macOS 26+, each
presentation/hosting-view replacement and each foreground-app activation or
deactivation triggers a bounded appearance burst: 18 refreshes spaced 20 ms
apart (approximately 360 ms). Each refresh calls `becomeKey()` and posts
`didBecomeKeyNotification` as a process-local glass appearance hint. These are
public symbols used outside Apple's recommended calling pattern; the HUD never
calls `makeKeyWindow()` or activates the app.

Only the recurring one-second appearance timer has been removed. The visible-only
app-change observers, bounded bursts, and `HUDGlassAppearanceSession` remain.
An idle HUD does no appearance maintenance after its burst finishes. Hiding or
closing the HUD cancels the burst and removes observers; releasing the session
also cleans up its work. The ordinary dismiss/hover timers still control duration.

## Persistence and migration

`InputPriorityStore` saves versioned JSON under `inputPriorityPreferences.v1` in
`UserDefaults`. Entries contain Core Audio UID, last known name, icon, transport,
manual hiding, and a disconnect timestamp. Missing new fields decode with defaults
so existing priority preferences retain their order and mode. Availability and the
active input are always read from Core Audio.

The disconnect deadline survives restarts and is not extended by device events.
An already-offline historical device with no known disconnect time starts collapsed.
Reconnection clears the timestamp. One scheduled refresh updates open views at the
next expiry even when Core Audio sends no new event.

Fresh installations start enabled, with the current system input first.
Subsequent discoveries append without changing existing positions. MicFirst
reads only `inputPriorityPreferences.v1`. AudioInputLocker lock keys are ignored.

USB and Bluetooth connections have independent UIDs and positions. Identical
names receive a USB/Bluetooth suffix in the menu; original device names are retained.

## Source boundaries

- `InputPriorityStore.swift`: persistence, migration, order, discovery, and target selection.
- `AudioInputViewModel.swift`: Core Audio events, manual intent, route verification, bounded retries, and volume.
- `SoundMenuView.swift`: the compact 308 pt menu, native controls, and system/app/quit actions.
- `InputPrioritySettingsView.swift`: native Settings scene content, device controls, and Settings entry point.
- `ReorderableInputList.swift`: shared UID-based drag behavior, scroll handling, and hover visibility.
- `PreferredInputHUD.swift`: the existing glass HUD and its presentation lifecycle.
- `HUDPlacement.swift`: horizontal collision avoidance and visible-capsule screen clamping.
- `StatusItemController.swift` / `HUDAnchor.swift`: own menu-button geometry and HUD placement.
- `NativeHUDProbe.swift`: live system banner hosts from public window metadata.
- `HUDDiagnostics.swift`: opt-in, time-bounded Debug logging.
- `InputPriorityPreview.swift`: Debug-only simulated UI; no system audio writes.

Volume echo suppression only affects the slider; it never discards route or
hot-plug events. A restoration HUD appears only after the actual default input
matches the selected priority target. A transient route failure receives three
short retries; disabling automatic mode cancels pending work.

## Validation

Run `./scripts/test.sh`. The hostless XCTest target compiles production model and
coordinator sources against fake audio and HUD adapters. Tests cover migration,
persistence, discovery, fallback, reconnection, manual intent beyond five seconds,
offline sorting/removal, reconnect races, volume events, HUD actions, and failures.
It does not launch the app or change real audio devices.

Use `./scripts/build-and-run.sh --preview` for the real menu with four simulated
devices, including an offline Bluetooth mic. Check drag/drop, click selection,
the global switch, Settings, and offline deletion. Preview preferences are isolated.
For an already-expired offline device, launch the Debug app with
`--priority-preview --expired-offline`; add `--many-inputs` to exercise scrolling.
`./scripts/build-and-run.sh` returns to the regular menu bar utility.

Use `./scripts/build-and-run.sh --hud-preview` to show the finalized real HUD
with simulated devices and isolated preferences. Its initial timeout is extended
to 60 seconds; close, buttons, and hover exit retain their usual behavior. This
preview requires Debug and uses the same clear + Popover 0.80 recipe as normal
presentation. The tint/material lab, its sliders and A–E comparison, the glass
layer toggle, and the `--tint-preview` / `--flat-glass` launch options are retired.

To review the actual HUD while using the isolated preview, run:

```sh
swift -e 'import Foundation; DistributedNotificationCenter.default().postNotificationName(Notification.Name("MicFirst.ShowPreferredInputHUD"), object: nil, userInfo: nil, deliverImmediately: true); RunLoop.current.run(until: Date().addingTimeInterval(0.2))'
```

This Debug-only trigger uses the preview's simulated current device. The HUD
keeps its normal lifetime and hover behavior; its priority button operates on
the isolated preview model.

Validated on 2026-10-02 for live banner avoidance (macOS 27.0, build 26A428,
sandboxed Debug app launched through LaunchServices; simulated devices unless
noted):

- The running app reported no Screen Recording and no Accessibility permission,
  and still moved its HUD for the AirPods, volume and display-brightness banners.
- AirPods routing, volume, display-brightness and keyboard-brightness banners
  each appeared as one MenuBarAgent window, level 101, 352×157 pt. A synchronized
  screenshot of the AirPods banner showed its 235×52 capsule centered in the host.
- Two user-triggered AirPods banners appeared under a visible HUD. The HUD was
  moving within 50 ms and in place within 0.3 seconds, 39.5 pt from the AirPods
  capsule. Those banners stayed for about 21 seconds, longer than the HUD's
  normal 4.2 seconds.
- A volume banner under a visible HUD moved it the same way, ending 12 pt from
  the volume capsule. The HUD stayed there after the banner left.
- A HUD presented while a banner was showing appeared beside it without sliding.
- In a real-device run, AirPods moving to iPhone showed the AirPods banner. The
  AirPods devices left Core Audio 2.0 seconds later, the default input fell back
  to the MacBook microphone, and the restoration HUD appeared beside the banner
  within 50 ms of that change. It never overlapped the banner.
- A display-brightness banner anchored under Control Center, with its host ending
  20 pt beyond the display, was avoided from its measured frame.
- A banner replaced during a slide reused its window at a new position; the HUD
  followed to the new free position.
- All 73 hostless tests and Debug / universal Release (arm64 + x86_64) builds
  passed without warnings.

Hover deferral, Reduce Motion, multiple displays, an auto-hidden menu bar,
macOS 26, the keyboard-brightness banner with a visible HUD, and a restoration
caused by AirPods connecting (rather than leaving) were not exercised in this run. Use
`swift scripts/diagnostics/watch-system-banner-hosts.swift` to re-check the host
signature on another macOS version.

Validated on 2026-09-07 for the HUD material/window update:

- The comparison with identically configured `.clear` windows returned to a gray/frosted appearance with
  `--flat-glass` and reduced that wash with appearance maintenance enabled.
- A pointer click on the HUD's priority button disabled the simulated mode.
- Timed observations in a separate Sublime Text document accepted input and kept
  a context menu open across the one-second maintenance interval. Each observation
  was kept in a single UI-control call to avoid intervening foreground changes.
- A debugger snapshot while the HUD was visible reported `NSApp.keyWindow == nil`.
- Historical hostless appearance-session tests covered stopping work after dismissal, reuse,
  and releasing a session with pending work. These do not prove rendering or
  cross-application focus behavior on other macOS versions.
- All 35 hostless tests and Debug / universal Release (arm64 + x86_64) builds
  passed without warnings.

The material comparison used captured window images, not a frame-by-frame
desktop recording. Exact parity with Apple's AirPods HUD and physical
multi-display/wake behavior have not been established by this check.

Real-device testing remains necessary for firmware-specific USB/Bluetooth routing
and physical reconnect timing. The app continues to target macOS 13; the test
target uses macOS 14 to match Xcode 27's XCTest runtime.

Validated locally on 2026-09-06 with Xcode 27 / macOS 27:

- All 33 regression tests passed, including migration, expiry without audio events,
  persisted hiding, reconnect recovery, and filtered-menu sorting.
- Debug and universal Release (arm64 + x86_64) builds passed without warnings.
- The initial menu passed offline drag, current/offline click, manual selection,
  re-enable, and scrolling/reordering in a 16-device list.
- The new Settings window passed opening/reopening, offline drag and deletion,
  and hiding the active device with immediate automatic fallback.
- English and Chinese Settings layouts were inspected. A 16-device fixture passed
  scrolling and pointer reordering after scroll; an expired offline entry was
  absent from the menu and retained at its original full-list position in Settings.
- The normal running app restored a Continuity microphone after an external
  Core Audio switch to the built-in microphone.
- Physical DJI USB/Bluetooth and AirPods reconnects were not available for this run.
