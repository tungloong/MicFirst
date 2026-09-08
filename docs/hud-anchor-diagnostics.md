# HUD startup anchors and read-only diagnostics

Current behavior is defined in [input-priority.md](input-priority.md). The HUD
uses untinted clear Liquid Glass over Popover material at 0.80, appears immediately
after a verified restoration, and moves horizontally only when its normal position
would overlap the predicted system-banner region. No native visibility or dismissal
signal is assumed.

## Startup geometry

SwiftUI owns the system `MenuBarExtra(.window)`. `StatusItemController` creates
neither a status item nor a menu panel; it adapts a startup button snapshot for HUD
placement. The earlier direct NSStatusItem/NSPopover experiment and the custom
panel were replaced by the system menu.

In a Debug development run, `scripts/build-and-run.sh`:

1. Builds the app and the retained `scripts/diagnostics/read-system-menu-anchors.swift` helper.
2. Restarts MicFirst and waits up to 10 seconds for its process to appear.
3. Runs one helper process, which waits for application launch and retries public
   Accessibility geometry for Sound, Control Center and MicFirst's own menu button.
4. Retries delivery at 250 ms intervals, within a 10-second deadline, until the app
   acknowledges a snapshot containing a usable own-button anchor. Empty, invalid,
   or temporarily unusable snapshots do not consume the receiver.
5. Confirms receipt of that acknowledgement, then exits. The app removes its
   receiver after this confirmation, or after a 30-second startup deadline if
   the helper disappears. Repeated deliveries are acknowledged without replacing
   the accepted snapshot.

The helper needs an already-authorized Accessibility execution context. It never
prompts, changes settings, reads popup contents, or polls after startup delivery.
Missing authorization, an exited app, or a delivery timeout produces a nonzero
helper/script result with an explanation instead of reporting successful delivery.
The app keeps the snapshot until it exits. Move/hide a relevant menu icon or change
displays, then relaunch through the script to refresh the coordinates.

A direct app launch without the helper and the Release target currently lack the
own-button snapshot, so the HUD is suppressed. Automatic microphone priority works
independently. Production helper/permission integration remains pending; successful
Release compilation does not establish standalone HUD functionality.

For a persistent menu bar, the capsule's top is 9 pt below the work-area top.
For an auto-hidden bar, the captured button bottom supplies the boundary; physical
auto-hide transitions have not been validated. The visible capsule is 235×52 pt
inside a 360×136 pt transparent host. Screen clamping applies to the capsule with
a 6 pt inset; transparent hosting margins may extend offscreen.

Sound is preferred to Control Center on the same display. The predicted native
capsule is clamped to the screen before testing horizontal overlap. MicFirst keeps
its own X if there is already a 12 pt gap, otherwise uses the right side if it fits,
or the left side. If neither side fits, the HUD is skipped without a lower row.
If only the system anchor is unavailable, the own anchor is used without a guarantee
of separation. These are app layout policies, not measurements of Apple's banner.

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
seconds they sample public window metadata every 100 ms, writing changes plus a
one-second heartbeat to a unique JSONL file under:

```text
~/Library/Containers/com.tungloong.AudioInputLocker/Data/Library/Application Support/MicFirst/HUDDiagnostics/
```

This sampler is separate from startup button acquisition and appearance support;
it runs only with the explicit diagnostic argument. After the bounded startup
handshake, ordinary runs do not poll windows or refresh button coordinates. Appearance support retains
only bounded presentation/app-switch bursts, with no recurring one-second timer.

The log records no screenshots, window-title contents, audio samples or audio-device
UIDs. It makes no private service calls and requests no additional permission.

| Field | Meaning |
| --- | --- |
| `anchor.buttonFrame` | MicFirst button rectangle from the startup public-AX snapshot |
| `anchor.statusWindowFrame` | Menu-region rectangle derived from the snapshot and current screen work area; not a foreign NSWindow frame |
| `systemMenuAnchors` | Validated startup menu-button snapshots |
| `hud.hostFrame` / `hud.capsuleFrame` | Actual own-window geometry and visible capsule |
| `capsuleCenterDeltaFromButton` | Horizontal displacement including intentional avoidance; assess while visible |
| `native.presence` | Always `unknown` with the retained public probe |
| `native.windows[].matchesLegacyFilter` | Whether public metadata matches the old Control Center predicates |
| `native.windows[].legacyAssumedCapsuleFrame` | Historical centered 235×52 assumption, explicitly unverified |
| `native.windows[].rawCGFrame` | Raw top-left WindowServer coordinates |

Other rectangles use AppKit bottom-left screen points. `backingScale` is recorded
separately; window coordinates are not multiplied by it. Title availability is
classified as missing/empty/nonempty, without saving the title. Records distinguish
simulated from real devices and include restoration confirmation, preview requests,
anchor delivery, presentation, skipped requests and dismissal events.

## Evidence and limits

An empty native query does not prove absence, and a matching window does not prove
that the AirPods capsule is visible. The probe therefore never emits `visible` or
`absent`. Metadata cannot drive placement or extend the HUD lifetime.

The prior native-HUD investigation is closed. Its standalone private probes and
old metadata watcher were removed at closeout; sanitized findings remain in
[native-hud-investigation.md](native-hud-investigation.md). Do not repeat native-HUD
trigger tests merely because the diagnostic result is unknown.

Current tests cover fixed-height/horizontal geometry, screen edges, Sound-first
selection, snapshot validation, incomplete-snapshot retries, duplicate delivery
acknowledgements, receiver cleanup, uncertain diagnostic evidence, HUD preference
migration, event-only appearance bursts, and microphone route regressions. Real
multi-display, auto-hide and future OS behavior still require device validation.
