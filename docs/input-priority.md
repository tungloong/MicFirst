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

There is no pause, five-second countdown, or timed resume. The HUD's lock-shaped
button now controls the same global mode and never changes priority order.

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
