# MicFirst

MicFirst is a native macOS menu bar utility that keeps the highest-priority
available microphone selected. Use SwiftUI, AppKit, and Core Audio.

## Run and verify

- `./scripts/build-and-run.sh`: build and run the real app.
- `./scripts/build-and-run.sh --preview`: isolated UI with simulated devices.
- `./scripts/test.sh`: hostless priority and route regression tests.
- HUD placement against real banners: `docs/hud-anchor-diagnostics.md`
  (watch script, and unified-log checks for MicFirst's route writes).
- Project/scheme: `MicFirst.xcodeproj` / `MicFirst`.
- Runtime target: macOS 13+. Build with the macOS 26 SDK or newer.
- Prefer the isolated preview for UI checks that do not need real audio routing.

## Boundaries

- Source: `MicFirst/`; tests: `MicFirstTests/`; current behavior: `docs/input-priority.md`.
- Update both `en.lproj` and `zh-Hans.lproj` for user-facing strings.
- Keep menus and Settings close to native macOS controls and concise wording.
- Bundle ID is `com.tenglong.MicFirst`. The preference key
  `inputPriorityPreferences.v1` stays. `com.tungloong.AudioInputLocker` belongs
  to the retired AudioInputLocker product.
- MicFirst currently does not capture, process, or transmit audio samples.
- HUD banner avoidance reads public window metadata only. Keep private APIs,
  Accessibility, and Screen Recording out of the app.
- Do not commit build products, local preferences, credentials, or user data.

## Product and repository state

- MicFirst: `https://github.com/tungloong/MicFirst` (`origin`).
- AudioInputLocker is a separate completed product; do not send MicFirst code
  to its repository. Its original source and release history stay there.
- Product decisions: `docs/product-decisions.md`.
- As of 2026-09-07, do not pursue multi-microphone mixing/fusion or the research
  prototypes unless the user explicitly revisits that decision.
- MicFirst 1.0.0 is published as a Developer ID signed and notarized DMG/ZIP on
  GitHub Releases; see `docs/github-release.md` for the packaging steps.
- Historical AudioInputLocker material is labelled as history, not current behavior.

## Web research

Prefer the available `web.run` / `web__run` tool. Use the `web-search` or
`firecrawl` skill only if that tool is unavailable or cannot continue searching.
