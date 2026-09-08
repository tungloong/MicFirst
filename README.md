# MicFirst

<p align="center">
  <img src="docs/assets/audio-input-locker-app-icon-256.png" width="112" alt="MicFirst app icon">
</p>

<p align="center">
  <a href="https://github.com/tungloong/MicFirst/actions/workflows/build.yml"><img src="https://github.com/tungloong/MicFirst/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/tungloong/MicFirst" alt="MIT License"></a>
</p>

[English](README.md) | [简体中文](README_CN.md)

MicFirst is a small macOS menu bar app for keeping the
best available microphone selected using an ordered input priority list.

MicFirst is an independent product built around microphone priorities. It grew
out of [AudioInputLocker](https://github.com/tungloong/AudioInputLocker), the
completed single-device locking app. The two products have separate interaction
models, repositories, and release histories.

macOS has a native-looking Sound menu for output devices, but not a matching
menu for microphones and other input devices. MicFirst fills that gap
with a Sound-style input menu. Put your microphones in priority order; the app
uses the first available device and restores it after external route changes.

## Status and Installation

The current MicFirst source is available under the MIT License and implements
the priority workflow described below. Build and run it using the instructions
in this README. No MicFirst binary release has been published yet.

Future downloads will appear in [MicFirst Releases](https://github.com/tungloong/MicFirst/releases).
AudioInputLocker's existing downloads belong to that separate product.
Signed and notarized distribution and Mac App Store validation remain future work.

## Features

- Menu bar extra with a native macOS Sound-style popover.
- Lists Core Audio input devices.
- Switches the system default input device from the menu.
- Shows and controls input volume when the device exposes a writable volume.
- Automatically selects the highest-priority available input and restores it after external changes.
- Remembers every discovered device and its priority across restarts.
- Supports dragging online and offline devices into priority order.
- Collapses offline devices in the menu after five minutes; drag handles appear together on list hover.
- Provides Settings with the full numbered priority list, menu visibility controls, and offline deletion.
- Excludes manually hidden devices from automatic selection.
- Turns automatic mode off for manual selections while preserving the order.
- Shows a configurable transient HUD after confirming an automatic restoration.
- Supports English and Simplified Chinese, following the system language.

## Requirements

- macOS 13.0 or later at runtime.
- Xcode with the macOS 26 SDK to build the current source.

The app targets macOS 13.0. The HUD uses public macOS 26 Liquid Glass APIs when
available and falls back on older systems.

## Build And Run

Clone the repository:

```sh
git clone https://github.com/tungloong/MicFirst.git
cd MicFirst
```

Then use the local helper script:

```sh
./scripts/build-and-run.sh
```

The script builds the Debug app, stops any running `MicFirst` and
`AudioInputLocker` processes, and opens the freshly built MicFirst app from
`build/DerivedData`.

The current Debug script also reads menu-button coordinates once through a public
Accessibility helper in an already-authorized execution context. HUD presentation
currently depends on this startup snapshot; standalone/Release launch integration
remains unfinished. Automatic microphone priority works independently. See
[HUD behavior and limits](docs/input-priority.md).

Manual build:

```sh
xcodebuild \
  -project MicFirst.xcodeproj \
  -scheme MicFirst \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  build
```

For a non-Apple-Silicon destination, override `DESTINATION` when running the
script.

## Usage

1. Open the microphone icon in the menu bar.
2. Drag devices into your preferred order, for example DJI USB → DJI Bluetooth → AirPods → built-in mic.
3. Turn on **Input Priority** to use the first available device in that order.

Devices must be seen by the app once before they can be remembered. Newly discovered
devices go to the bottom. Hover over the list to reveal its drag handles. Offline
devices stay gray for five minutes, then leave the menu until they reconnect.

Open **MicFirst Settings…** (⌘,) for the complete numbered list, including offline devices.
Drag to reorder, uncheck **Show in Menu** for an online device to hide it and exclude
it from automatic selection, or use the trash button to delete an offline device.
Hidden devices keep their priority; deleted devices return at the bottom when
rediscovered. **macOS Sound Settings…** opens macOS Sound settings; **Quit
MicFirst** (⌘Q) exits the app.

Clicking a different available input turns automatic mode off without changing the
order. Clicking the current input does nothing. Turn the switch back on to immediately
use the highest-priority available input. There is no countdown or timed resume.
External changes while automatic mode is on are restored. If all inputs are offline,
the mode stays on and waits for one to return.

When existing AudioInputLocker preferences are present, its previous locked
device is placed first, even if offline. Disabled or explicitly unlocked
installations stay manual. A fresh installation starts in
automatic mode with the current system input at the top.

## Localization

The app currently ships with:

- English: `MicFirst/en.lproj/Localizable.strings`
- Simplified Chinese: `MicFirst/zh-Hans.lproj/Localizable.strings`

Device names come from Core Audio. Identically named USB and Bluetooth inputs
receive a connection suffix so they can be distinguished.

## Project Layout

- `MicFirst/MicFirstApp.swift`: app entry point and menu bar extra.
- `MicFirst/SoundMenuView.swift`: Sound-style menu popover.
- `MicFirst/AudioInputViewModel.swift`: route coordination, volume, and verified restoration.
- `MicFirst/InputPriorityStore.swift`: persistent order, discovery, and legacy migration.
- `MicFirst/PreferredInputHUD.swift`: restoration HUD presentation.
- `MicFirstTests/InputPriorityTests.swift`: isolated priority and route regression tests.
- `docs/input-priority.md`: behavior, testing, and design reference.
- `MicFirst/CoreAudioInputManager.swift`: Core Audio wrapper.
- `MicFirst/InputDevice.swift`: input device model and icon heuristics.
- `MicFirst/HUDMicrophone.png`: HUD microphone asset.
- `MicFirst/Assets.xcassets`: app icon and menu bar icon assets.
- `scripts/build-and-run.sh`: local build and restart helper.
- `scripts/package-preview-release.sh`: local preview release packaging helper.
- `docs/visual-assets.md`: icon assets and visual notes.
- `docs/troubleshooting.md`: FAQ and troubleshooting notes.
- `docs/github-release.md`: GitHub repository setup notes.
- `docs/app-store`: App Store metadata, privacy policy, and release checklist.
- `docs/product-decisions.md`: product boundaries and dated decisions.
- `docs/liquid-glass-investigation.md`: historical notes from HUD visual
  experiments.
- `docs/project-notes.md`: historical AudioInputLocker context, retained for reference.
- `CHANGELOG.md`: notable project changes.
- `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SUPPORT.md`, and `SECURITY.md`: community and
  maintenance guidance.

## Implementation Notes

MicFirst is built with SwiftUI, AppKit, and Core Audio.

- The app is a menu bar utility and hides the Dock icon with `LSUIElement`.
- Core Audio is used for device enumeration, default input switching, input
  volume reads and writes, and device-change monitoring.
- The priority order, remembered device metadata, and automatic-mode switch are stored locally in `UserDefaults`.
- App Sandbox entitlements are included for Mac App Store validation.
- The HUD uses a borderless `NSWindow` above ordinary pop-up menus and refuses
  key/main focus. On macOS 26+, untinted clear glass sits over Popover material
  at 0.80 opacity for readability.
- The app does not use private APIs.

## Privacy

MicFirst works locally on your Mac. It does not include analytics,
network calls, accounts, or telemetry.

The app stores local device identifiers, names, icon and connection metadata,
priority order, and automatic-mode preference. See the [MicFirst privacy policy](docs/privacy.md).

## FAQ

### Does MicFirst record audio?

No. MicFirst does not record, process, upload, or analyze microphone
audio. It only manages the selected system input device through Core Audio.

### Why does a device have no volume slider?

Some input devices do not expose a writable input-volume control through Core
Audio. The slider is enabled only when macOS reports that the device supports it.

### Does input priority work with AirPods and USB microphones?

That is the main workflow. The app chooses the first available input in your
priority list and restores it after another process changes the system input.
Behavior can still vary by device firmware and macOS routing rules.

### Does the app need microphone permission?

The app does not record audio, so it is not expected to request microphone
recording permission.

More notes are in `docs/troubleshooting.md`.

## Roadmap

- Ship a signed and notarized direct-download build.
- Validate App Sandbox behavior for Mac App Store distribution.
- Add release packaging and upload automation beyond the preview script.

As of September 7, 2026, multi-microphone mixing and fusion are outside the
near-term roadmap. See [product decisions](docs/product-decisions.md).

## Contributing

Issues and pull requests are welcome. Please keep changes focused and preserve
the native macOS feel of the menu and HUD. See `CODE_OF_CONDUCT.md`,
`CONTRIBUTING.md`, `SUPPORT.md`, and `SECURITY.md` for project guidance.

Useful checks before opening a pull request:

```sh
./scripts/build-and-run.sh
```

For changes that affect input priority, please also test at least one real device
switching scenario, such as AirPods auto-switching, System Settings changes, or
USB microphone reconnects.

## License

MicFirst is released under the MIT License. See `LICENSE`.
