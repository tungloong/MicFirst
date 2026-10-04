# Product decisions

## 2026-09-07 — Separate products and repositories

AudioInputLocker is a complete utility centered on locking one input device.
Its existing interface, code, downloads, and history remain in
[tungloong/AudioInputLocker](https://github.com/tungloong/AudioInputLocker).
Development has concluded; its English and Chinese READMEs direct readers to
MicFirst for a priority-based workflow.

MicFirst is a separate product centered on a persistent microphone priority
list, automatic fallback, and a full Settings device list. Its repository is
[tungloong/MicFirst](https://github.com/tungloong/MicFirst). It starts from the
current MicFirst source snapshot with independent commit and release history.
AudioInputLocker's release tags and binaries are not MicFirst releases.

The 2026-09-07 split kept `com.tungloong.AudioInputLocker` so the local
configuration under test could keep running. That identifier belongs to
AudioInputLocker. MicFirst's bundle identifier is `com.tenglong.MicFirst`;
see the 2026-09-23 decision. Quit AudioInputLocker before running MicFirst so
the two apps do not both change the system input. See
[compatibility details](micfirst-rename.md).

The checkout directory name is independent of the app, project, and repository
names. A directory named `AudioInputLocker` still builds `MicFirst.app` because
the scripts resolve paths relative to the checkout. Renaming that directory is
optional; close active development sessions first and reopen the new path in
Codex, Xcode, and terminals afterward. No file-system rename is part of this
repository split.

## 2026-09-07 — Do not pursue multi-microphone mixing in the near term

Decision: the expected implementation and maintenance cost outweighs the likely
benefit. MicFirst will not pursue multi-microphone mixing/fusion or the follow-up
prototypes proposed by the research in the near term. Work remains focused on
user-controlled priorities and stable input selection.

The [research](multi-input-research.md) is retained as background, not as a task
list or committed roadmap. There is no scheduled restart; revisit only after
an explicit product decision.

## 2026-09-08 — HUD readability recipe accepted

Keep untinted `.clear` Liquid Glass over a capsule-clipped Popover background
material at 0.80 opacity. Retain presentation/app-switch appearance bursts and
omit the recurring one-second appearance timer. Retire the temporary tint and
background-material controls. This closes the material exploration; exact system
AirPods rendering is not a requirement for this accepted recipe. See
[current HUD behavior](input-priority.md) for implementation and integration limits.

## 2026-09-23 — Distribution identity

MicFirst ships as source on GitHub, with a notarized DMG in GitHub Releases for
direct install, and as a free Mac App Store download for people who install
from the store. Both binaries use bundle ID `com.tenglong.MicFirst`, the same
`com.tenglong.*` account prefix as BetterNotch.

`com.tungloong.AudioInputLocker` stays with the retired AudioInputLocker product.
MicFirst does not use it. The preference key inside the app stays
`inputPriorityPreferences.v1`. At the time no public MicFirst binary had shipped,
so there was no released preference domain to migrate.

## 2026-10-02 — The HUD avoids the system AirPods HUD live

MicFirst's HUD must not overlap Apple's AirPods HUD; this reopened the closed
September investigation. While visible, the HUD reads Apple's banner host from
public window metadata and moves to the nearest free side of the same row, never
to a lower row. It keeps the centered 290 pt of a host clear, because metadata
does not say which banner is showing. No private API, Accessibility, or Screen
Recording permission is used, so shipped sandboxed builds behave like Debug. See
[HUD behavior](input-priority.md) and the
[investigation](native-hud-investigation.md).

## 2026-10-03 — The HUD appears only for a real switch

The HUD appears only when MicFirst's own write changed the route. After a device
arrives or leaves, MicFirst gives the system a short wait to make its own route
change; an external takeover is still restored at once.

## 2026-10-03 — A Bluetooth microphone does not follow its output

Speaker output with an AirPods microphone is a legitimate setup, so moving the
output elsewhere does not make MicFirst give up a worn headset's microphone.
AirPods leave Core Audio when they are taken off, so no extra rule is needed for
headsets that are not worn.

## 2026-10-03 — Repository wording is separate from App Store copy

After the 1.0.1 review rejection (guideline 5.2.5), App Store metadata avoids
Apple product names such as AirPods. The GitHub READMEs and docs may name them.
