# MicFirst rename

Historical implementation note: this records the local rename before the
2026-09-07 decision to maintain MicFirst and AudioInputLocker as separate
products. The current repository arrangement is documented in
[product decisions](product-decisions.md).

## Names and compatibility

| Item | Value after the rename |
| --- | --- |
| App / executable | `MicFirst.app` / `MicFirst` |
| Project / shared scheme | `MicFirst.xcodeproj` / `MicFirst` |
| App source / tests | `MicFirst/` / `MicFirstTests/` |
| App bundle identifier | `com.tungloong.AudioInputLocker` (preserved) |
| Saved priority key | `inputPriorityPreferences.v1` (preserved) |
| Debug preview preference suite | `com.tungloong.AudioInputLocker.PriorityPreview` (isolated, preserved) |
| Debug HUD notification | `MicFirst.ShowPreferredInputHUD` |

Keeping the bundle identifier and preference format preserves the existing
preference domain, including remembered devices, priority order, automatic mode,
menu visibility, and legacy lock migration. Do not replace the bundle identifier
as a cosmetic cleanup. No preference copy or reset is needed for this rename.

`./scripts/build-and-run.sh` builds MicFirst and stops both the previous
`AudioInputLocker` process and any existing `MicFirst` process before launching
the new app. The working checkout directory can retain its existing name.

## Repository split and distribution

MicFirst has its own repository at https://github.com/tungloong/MicFirst.
AudioInputLocker retains its original repository, website, and published
`0.1.0-preview` downloads. Original license attribution is preserved.
The local working directory can still be named `AudioInputLocker`; all build
scripts locate the project relative to their own directory.

The repository split does not change the compatibility identifiers listed above.
The apps currently share an application identifier and should not run together.
A fully independent installation identity would require a separate preference
migration and distribution decision; it is not implied by a repository rename.

No MicFirst binary release or website deployment is part of the repository split.
Quit AudioInputLocker before running MicFirst, so two guards do not compete for
the same system input.

## Local validation — 2026-09-07

- Baseline before the rename: `548f272`.
- All 33 isolated priority/route tests passed with the renamed project and scheme.
- Debug and universal Release (`arm64` + `x86_64`) built without warnings.
- The built bundle reports `MicFirst` for its name and executable, with the
  original bundle identifier and `LSUIElement` behavior intact.
- Launching through the helper stopped the running AudioInputLocker instance
  and left one MicFirst process. The real saved priority JSON was semantically
  identical before and after launch; all remembered devices and the
  automatic-mode value were retained. Legacy preference values also matched.
- The isolated native preview displayed `MicFirst Settings…` and `Quit MicFirst`;
  the Settings action opened the full list, and Command-Q terminated the preview.
  The normal MicFirst app was then relaunched.
- English and Simplified Chinese localization files, app metadata, entitlements,
  shell syntax, and whitespace checks passed.

This validates the local development upgrade. It is not a signed or notarized
distribution upgrade test, and no new public release was produced.
