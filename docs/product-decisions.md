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

The app's existing bundle identifier and preference format remain unchanged in
this repository split to preserve the already-tested local configuration.
The two apps currently share an application identity and should not run at the
same time. See [compatibility details](micfirst-rename.md).

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
