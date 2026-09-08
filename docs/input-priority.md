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

In the current sandboxed development build, the startup public-AX helper also
reads MicFirst's `micfirst-status-item` rectangle. `StatusItemController` now
only provides this snapshot to the HUD; it creates no menu window or status item.
All button positions refresh on launch, so rearranging MicFirst's icon also
requires a relaunch. An unavailable own anchor suppresses HUD presentation.

The HUD prefers the center of MicFirst's own menu-bar button, with its capsule
9 pt below the menu bar. Horizontal avoidance reserves a predicted 235×52 pt
native capsule under Sound, falling back to Control Center on the same display.
The native region is reserved regardless of whether Apple's HUD is currently
visible. Both capsules are clamped inside the screen before testing overlap.

If the own capsule is already separated by at least 12 pt, it stays at its own
anchor. Otherwise it moves to the native region's right if the entire capsule
fits, or to its left if that fits. If neither side fits, skip the notification;
never move it to a lower row. Missing/invalid system coordinates fall back to the
own anchor without claiming collision protection. No five-second delay remains:
confirmed restoration notifications appear immediately. Route verification and
the normal 4.2-second visible duration/hover behavior remain unchanged.

Settings includes **Show HUD Notifications**, enabled by default for both new and
existing installations. It persists in `inputPriorityPreferences.v1` independently
of automatic input. Turning it off dismisses visible HUDs; turning it back on does
not replay old events.

**Current integration is a Debug startup snapshot.** `build-and-run.sh` invokes
an external public-Accessibility helper once per launch/relaunch. It reads
Sound/Control Center and MicFirst menu geometry once after launch, delivers
validated JSON through a one-shot notification, and exits. The app retains that snapshot for the process lifetime;
there is no background coordinate helper, periodic refresh, notification feed,
or expiration timer. Move/hide a system button or change displays, then relaunch
through the script to refresh the snapshot. The own icon also uses the startup snapshot. No entitlement, private API, or permission prompt was added;
the helper needs an already-authorized Accessibility execution context.

A standalone app launch without the helper, and the Release target, currently
lack the own-button snapshot and therefore suppress HUD presentation. A supported production helper/permission architecture
is still an explicit follow-up decision; don't represent the development bridge
as production AX access from a sandboxed app. See [native HUD investigation](native-hud-investigation.md)
for the closed native-visibility experiments.

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

An existing preferred UID is migrated to the first position even when offline.
Its previous enabled state is preserved. A previously unlocked installation stays
manual. Fresh installations start enabled, with the current system input first.
Subsequent discoveries append without changing existing positions. Legacy keys
are left intact for compatibility but ignored after migration.

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
- `StatusItemController.swift` / `HUDAnchor.swift`: startup menu-button anchor validation and HUD geometry.
- `NativeHUDProbe.swift` / `HUDDiagnostics.swift`: read-only candidate evidence and
  opt-in, time-bounded Debug logging; no verified native visibility channel yet.
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
