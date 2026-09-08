# Native AirPods HUD: interfaces, placement, and visual comparison

Observed on 2026-09-07, macOS 27.0 (26A5416b), Xcode 27.
These are observations of this OS build, not an Apple API contract.

Current behavior: [horizontal avoidance from startup menu-button snapshots](input-priority.md).
The experiments below are historical. Lower-row reservations and delayed display
have been removed. Diagnostic window candidates never drive placement. The retired
standalone probe scripts and their local research artifacts were removed at closeout;
the public menu-button helper remains part of the development startup workflow.

## Final private-API attempt — September 8, closed

At the user's request, an independent diagnostic used SkyLight's private
`SLSMainConnectionID`, `SLSGetWindowCount`, `SLSGetWindowList`,
`SLSGetWindowBounds`, `SLSGetWindowOwner`, `SLSConnectionGetPID`,
`SLSGetWindowLevel`, and `SLSGetWindowAlpha`. Calls succeeded. Sampling every
100 ms compared private enumeration against public `CGWindowListCopyWindowInfo`
and retained changes to system-host windows and private-only windows. It did not
capture images/titles, send banner requests, inject code, or alter system settings.

The baseline listed 834 private entries and 828 public entries, with five
successfully resolved private-only windows. These belonged to WindowManager,
Siri, Dock, and Notification Center; their bounds were 1×1 or full-display size.
They did not change during the user's confirmed AirPods trigger.

The observed MenuBarAgent popups at elapsed 44.98–65.54 s and 118.73–123.95 s
were `(1260, 38, 352, 157)` in top-left screen points, level 101. Both were also
present in the public enumeration. The user confirmed triggering during this
capture, but no synchronized screenshot established that either popup was the
visible AirPods capsule. They remain unvalidated host bounds. Private alpha is
not proof of on-screen visibility.

A fresh Objective-C runtime inspection of SystemBanner/SystemBannerUI exposed
presentation/removal commands but no remote frame/visibility getter in the
enumerated service protocol. This does not exhaust Swift internals or prove no
private implementation could ever expose the information. Loading a presenter
class in a separate process does not access the running system presenter's state.

**Outcome: no usable new native-HUD position or visibility channel.** There is
therefore no successful private observation to translate into a public API.
Per the user's last-attempt boundary, stop this investigation; do not repeat
AirPods-trigger capture or pursue injection/protection changes. No private call
was added to MicFirst, and its running anchor trial was left unchanged.

The standalone private probe was removed after this investigation closed.
Its reference signatures were checked against the relevant declarations in
[yabai's private API header](https://github.com/asmvik/yabai/blob/master/src/misc/extern.h).

## Native interfaces

### September 8: public menu-button anchors

A read-only standalone Accessibility probe successfully read the system menu
buttons on macOS 27 beta, without querying HUD windows or calling private APIs.
The current owner is `com.apple.MenuBarAgent`; its `AXExtrasMenuBar` contains
`AXGroup` wrappers whose immediate children are `AXMenuBarItem` elements.

| User setting | AXIdentifier | AX position / size (pt) | Center X |
| --- | --- | --- | --- |
| Sound hidden | `com.apple.menuextra.controlcenter` | (1549, 8), 26×22 | 1562 |
| Sound shown | `com.apple.menuextra.sound` | (1425, 8), 22×22 | 1436 |

The Control Center button remained available when Sound was shown. These are
live measurements, not coordinates extracted from the user's cropped screenshots.
The identifiers and ownership are observed OS details, not promised stable Apple
contracts. The APIs (`AXUIElementCreateApplication`,
`AXUIElementCopyAttributeValue`, `AXValueGetValue`) are public. Coordinates use
top-left screen points; use position.x + size.width / 2 for horizontal anchoring.

Reproduce with `swift scripts/diagnostics/read-system-menu-anchors.swift`.
The retained script now reports Sound, Control Center and MicFirst
menu-button geometry, without walking their popup/app children. It neither prompts for permissions nor changes menu settings.

The diagnostic execution context reported `AXIsProcessTrusted() == true`.
MicFirst itself remains App Sandboxed and was not tested as an AX client here.
Apple lists assistive Accessibility API use among App Sandbox incompatibilities;
the standalone result must not be presented as proof that the existing app target
can use it unchanged. No entitlement or app behavior was changed in this research.

The screenshots support Sound-first / Control-Center-fallback as a potential
native anchor policy. A button coordinate predicts an anchor, not native HUD
visibility, duration, exact bounds, or screen-edge adjustment. The former
unconditional 60 pt reservation at MicFirst's own X explained the user's
left/lower floating presentation; current placement instead uses horizontal
separation without waiting for a native banner.

Control Center links both `SystemBanner.framework` and `SystemBannerUI.framework`.
Its binary contains `ControlCenterApp.SystemBannerWindow`, `SystemBannerService`,
and the connected / reverse-route / low-battery headphone presentations.

Runtime inspection of SystemBanner exposes `SystemBannerServiceConnection.service`
and `SystemBannerServiceProtocol`. The Mach service name is
`com.apple.SystemBannerService`. Relevant selectors and verified argument types:

| Selector | Arguments after the receiver and selector |
| --- | --- |
| `showSmartRoutingConnectedWithUserInfo:` | object / user-info dictionary |
| `showSmartRoutingReverseRouteWithUserInfo:text:completion:` | dictionary, text object, completion block |
| `showSmartRoutingLowBattery:productID:forCase:imageBundleIdentifier:imageName:batteryLevel:` | name object, UInt32 product ID, Bool, bundle identifier object, image name object, Double battery level |
| `showAccessoryWithUserInfo:` | object / user-info dictionary |
| `showAccessory:text:batteryLevel:` | accessory object, text object, Double battery level |

The complete dictionary schema was not recovered; field names found in reflection
metadata must not be mistaken for confirmed dictionary keys. A standalone unsigned
test client requested a clearly labelled `MicFirst HUD Test` banner, without a
Bluetooth or audio-route operation. The connection was interrupted; a live log
showed Control Center cancelling the peer connection. No test banner was observed.
Control Center also contains the entitlement name
`com.apple.private.system-banner-client`. The cancellation is consistent with an
authorization check, but the trace did not provide a specific entitlement error.
There is no verified working third-party trigger from this experiment.

SystemBannerUI's symbols expose `SmartRoutingSystemBannerContent`,
`SystemBannerBatteryLevel`, `SystemBannerWindowPresenter`,
`SystemBannerAssertionPresenter`, `XMarkDismissButton`, `ReverseRouteButton`, and
`ShadowBackground`. Its native `SystemBannerWindow` overrides
`_hasActiveAppearance`, `_hasActiveControls`, and `hasKeyAppearance`. This supports
the importance of active window appearance found in the earlier BetterNotch work.
These symbols are private implementation details, not public SwiftUI components.

Layout reflection fields include `size`, `leadingIndent`, `leadingPadding`,
`trailingTitlePadding`, `trailingViewPadding`, `cornerRadius`, `glass`, and `recipe`.
Their numeric defaults and complete glass recipe have **not** been recovered.
Finding the field names does not justify claiming an exact native blur, tint,
refraction, shadow, or font configuration.

The standalone interface-inspection tool has been retired. No private framework
or selector from this investigation is linked or called by MicFirst.

## What the live window capture established

The user triggered several real AirPods connections. Control Center's logs confirmed
the connected requests and `Directly showing banner for Sound` presentations.
The initial collector, like the old app code, assumed a Control Center window with
a high layer and a particular size. It collected no matching banner.

Broader captures included all layers and hidden windows, with screen-capture
preflight already granted. They recorded MenuBarAgent popovers at 352×157 pt,
layer 101, and a Control Center panel at 522×1045 pt. **Those popovers have not been
identified as the AirPods capsule and their size must not be used as its size.**
The capture did not establish a separately enumerated CGWindow for the visible
AirPods banner. The framework also has an assertion presenter, so a different
hosted presentation path is plausible; its exact compositor ownership is unproven.

An initial candidate combined audio-event reservations with broad window
filtering. The user's 17:49:44 and 17:50:09 screenshots rejected that policy:

- In the first case, MicFirst's visible top was about 203 pt. This matches the
  observed menu canvas's top 38 + height 157 + gap 8, rather than the native
  capsule's bottom plus a small gap. Using that canvas as a HUD obstacle pushed
  MicFirst too far down and re-anchored it horizontally to the menu.
- In the second case, MicFirst stayed on the lower row with no native banner in
  the image. The old sticky row flag did not respond to reservation expiry and
  could be inherited by a new presentation while the old window remained visible.

The broad window classification and cumulative placement algorithm were removed.
The subsequent bounded-reservation experiment (also since removed) used:

- Apple/Continuity availability changes, relevant input changes, and an explicit
  native-HUD hint reserve the top row for 4.2 seconds.
- There are exactly two positions: the normal MicFirst menu-bar anchor, and the
  same anchor shifted down by 52 + 8 = 60 pt. Repeated events extend the deadline
  but cannot push the HUD farther down or change its horizontal anchor.
- Expiry restores the normal row. If the pointer is inside, restoration waits
  until pointer exit. A new presentation independently evaluates the deadline.
- A single cancellable expiry callback replaces window-list polling. WindowServer
  metadata remains available through the diagnostic script, not as a production
  source of guessed native capsule geometry.

That was an event-based compatibility strategy. It does not observe the exact
instant that a native banner disappears, or its hover duration. The 4.2-second
reservation is a bounded application policy, not a recovered system duration.
An unrelated native banner with no relevant audio event is outside this policy.

## Visual findings

The user's 16:53:52 screenshot is a 2× reference. Its native AirPods title and
subtitle have approximately the same horizontal center (542.5 and 541.5 image
pixels in a Vision text measurement). MicFirst's centered two-line structure is
therefore appropriate; the partially covered subtitle is not evidence of different
alignment.

The visible native capsule is approximately 235×52 pt, matching MicFirst's current
size. The native top edge is about 9 pt below the menu bar; MicFirst previously used
12 pt and now uses 9 pt. This is screenshot calibration, not a recovered constant
from the private framework. Font boxes depend on the text, so the measurement does
not establish a precise font-size difference.

The microphone artwork and native AirPods artwork have different silhouettes and
visual weights. The 75% battery ring is a different control from MicFirst's priority
button; it is not a size reference for that button. Comparing subtle glass outlines
or shadows in the overlapping region would also compare two different backdrops,
including double glass. No extra rim or shadow has been added from that image.

## Current checks and historical validation

Use `./scripts/test.sh` for current regressions and
`./scripts/build-and-run.sh --hud-preview --diagnostics` for opt-in public
metadata diagnostics. The old lower-row simulation and standalone metadata
watcher have been removed; neither is a supported command.

The following measurements describe superseded implementations:

The first candidate passed 43 hostless tests and a simulated move from Y=6 to Y=65;
that did not establish correct classification or expiry in the user's two cases.
That revised suite had 45 passing tests covering exactly one row
of movement, repeated reservations without drift, expiry, hover deferral, a fresh
presentation after an expired reservation, and screen clamping. Audio-event and
glass-lifecycle regressions remain covered.

The revised isolated preview was verified through public metadata: the visible
360×136 pt hosting window moved from top-left Y=5 to Y=65, then back to Y=5 after
the reservation expired, with X unchanged. Debug and universal Release
(arm64 + x86_64) builds passed without warnings.

Readability was evaluated afterward and the user accepted clear glass over
Popover material at 0.80; see current behavior for the final recipe. The local
research directory and standalone probes were removed at closeout. Only the
sanitized observations in this document are retained.
