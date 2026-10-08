#!/usr/bin/env python3
"""Export the approved two-state HUD microphone illustration.

The selected on/off PNGs under docs/design/status-hud are used unmodified. This
script only normalizes their alpha (clears the faint matte fringe, restores the
solid interior) and resamples the unchanged square canvas to the 34 pt HUD
sizes. It never redraws, crops, or re-composes the approved art.
"""

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "MicFirst/Assets.xcassets"

# PreferredInputHUDView.hudIconSize is the only size the HUD draws.
BASE_POINTS = 34
SCALES = (1, 2, 3)

# alpha <= 8 is residual matte edge left by image generation; clear it to fully
# transparent so the 34 pt capsule never shows a dark square fringe.
FRINGE_ALPHA = 8
# alpha >= 240 is interior artwork; restore it to fully opaque.
SOLID_ALPHA = 240

STATES = {
    "HUDMicrophoneEnabled": ROOT / "docs/design/status-hud/2026-10-07/runner/hud-microphone.png",
    "HUDMicrophoneDisabled": ROOT / "docs/design/status-hud/2026-10-07-arms-folded/disabled/hud-microphone.png",
}


def normalize_alpha(image):
    """Clear the faint matte fringe and restore the solid interior.

    The mid-range anti-aliased edge is preserved so the 34 pt render keeps its
    smooth silhouette instead of a stair-stepped cutout.
    """
    cleaned = image.getchannel("A").point(
        lambda value: 0 if value <= FRINGE_ALPHA else (255 if value >= SOLID_ALPHA else value)
    )
    rgba = image.copy()
    rgba.putalpha(cleaned)
    return rgba


def export(name, source):
    canvas = normalize_alpha(Image.open(source).convert("RGBA"))
    asset = ASSETS / f"{name}.imageset"
    asset.mkdir(parents=True, exist_ok=True)

    images = []
    for scale in SCALES:
        pixels = BASE_POINTS * scale
        suffix = "" if scale == 1 else f"@{scale}x"
        filename = f"hud-microphone{suffix}.png"
        # reducing_gap box-prefilters the large downscale, which keeps the thin
        # baton and grille slots clean at 34 pt.
        resampled = canvas.resize((pixels, pixels), Image.LANCZOS, reducing_gap=2.0)
        resampled.save(asset / filename, optimize=True)
        images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})

    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    (asset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"{name}: {canvas.size[0]}px source -> {BASE_POINTS}pt @1x/2x/3x")


if __name__ == "__main__":
    for state_name, state_source in STATES.items():
        export(state_name, state_source)
