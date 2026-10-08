#!/usr/bin/env python3
"""Build SF Symbols 7 symbol sets from the unmodified Apple-exported masters.

The microphone, waves, and lock are Apple's paths. Only placement and uniform
scaling change. The extra rounded rectangle is a transparent badge separation
layer, using the native clear-behind annotation rather than an SVG mask.
"""

import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / "docs/design/status-hud/2026-10-07-native-symbols"
ORIGINALS = ROOT / "docs/design/status-hud/2026-10-07-native-eight/originals"
ASSETS = ROOT / "MicFirst/Assets.xcassets"
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
MASTERS = ("Ultralight-S", "Regular-S", "Black-S")
TOKEN = re.compile(r"[MLCQZ]|-?\d*\.?\d+(?:[eE][-+]?\d+)?")


def tag(name):
    return f"{{{NS}}}{name}"


def source(file, master):
    tree = ET.parse(file)
    group = next(e for e in tree.iter() if e.get("id") == master)
    return re.findall(r"M[^M]+", "".join(e.get("d", "") for e in group.iter()))


def positioned(path, scale=1, dx=0, dy=0):
    """Apply an affine transform without replacing any exported control point."""
    tokens = TOKEN.findall(path)
    output = []
    i = 0
    arity = {"M": 2, "L": 2, "C": 6, "Q": 4, "Z": 0}
    while i < len(tokens):
        command = tokens[i]
        i += 1
        output.append(command)
        for coordinate in range(arity[command]):
            value = float(tokens[i]) * scale + (dx if coordinate % 2 == 0 else dy)
            i += 1
            output.append(f"{value:.6f}".rstrip("0").rstrip("."))
    return " ".join(output)


def rounded_rectangle(x, y, width, height, radius):
    k = 0.552284749831 * radius
    return (
        f"M{x+radius} {y} L{x+width-radius} {y} "
        f"C{x+width-radius+k} {y} {x+width} {y+radius-k} {x+width} {y+radius} "
        f"L{x+width} {y+height-radius} "
        f"C{x+width} {y+height-radius+k} {x+width-radius+k} {y+height} {x+width-radius} {y+height} "
        f"L{x+radius} {y+height} "
        f"C{x+radius-k} {y+height} {x} {y+height-radius+k} {x} {y+height-radius} "
        f"L{x} {y+radius} C{x} {y+radius-k} {x+radius-k} {y} {x+radius} {y} Z"
    )


def generate(name, waves, locked, draw_wave=None):
    tree = ET.parse(ORIGINALS / "microphone.fill.svg")
    root = tree.getroot()
    for e in root.iter():
        if e.get("id") == "template-version":
            e.text = "Template v.7.0"
        elif e.get("id") == "descriptive-name":
            e.text = name

    layers = [(None, False)]
    if waves:
        layers += [(0.0, False), (0.34, False), (0.68, False)]
    if locked:
        layers += [(None, True), (None, False)]
    style = root.find(tag("style"))
    styles = [".defaults {-sfsymbols-variable-value-mode:color;-sfsymbols-draw-reverses-motion-groups:false}"]
    for index, (threshold, erase) in enumerate(layers):
        properties = []
        if threshold is not None:
            properties.append(f"-sfsymbols-variable-threshold:{threshold}")
        if draw_wave is not None and index != draw_wave and not erase:
            properties.append("opacity:0.0")
        properties.append(f"-sfsymbols-motion-group:{index}")
        properties.append(f"-sfsymbols-layer-tags:micfirst.layer.{index}")
        if erase:
            properties += ["opacity:0.0", "-sfsymbols-clear-behind:true"]
        for rendering in (f"monochrome-{index}", f"multicolor-{index}:tintColor", f"hierarchical-{index}:primary"):
            styles.append(f".{rendering} {{" + ";".join(properties) + "}")
    styles.append(".SFSymbolsPreviewWireframe {fill:none;opacity:1.0;stroke:black;stroke-width:0.5}")
    style.text = "\n".join(styles) + "\n"

    symbols = next(e for e in root.iter() if e.get("id") == "Symbols")
    for group in symbols:
        master = group.get("id")
        assert master in MASTERS
        mic = source(ORIGINALS / "microphone.fill.svg", master)
        native_waves = source(ORIGINALS / "speaker.wave.3.fill.svg", master)[1:]
        draw_source = ET.parse(DESIGN / "originals/speaker.wave.3.fill.draw-symbol.svg")
        draw_master = next(e for e in draw_source.iter() if e.get("id") == master)
        draw_waves = [e for e in draw_master if e.get("data-clipstroke-keyframes")][::-1]
        native_lock = source(DESIGN / "originals/lock.fill.svg", master)
        paths = [" ".join(positioned(p, dx=-2.5 if waves else 13.75) for p in mic)]
        if waves:
            paths += [positioned(p, dx=6.5, dy=-9) for p in native_waves]
        if locked:
            paths.append(rounded_rectangle(58.125, -15.625, 42.5, 38.125, 9.375))
            # 5.9 pt high at the approved 0.16 drawing scale, preserving aspect ratio.
            lock_scale = 5.9 / 0.16 / 75.48827
            paths.append(" ".join(positioned(p, scale=lock_scale, dx=66.875-lock_scale*10.7422,
                                             dy=18.125-lock_scale*1.51367) for p in native_lock))
        for old in list(group):
            group.remove(old)
        for index, path in enumerate(paths):
            classes = f"monochrome-{index} multicolor-{index}:tintColor hierarchical-{index}:primary SFSymbolsPreviewWireframe"
            attributes = {"class": classes, "d": path}
            if waves and 1 <= index <= 3:
                # Apple-exported normalized Draw guide data follows the same
                # unmodified wave path; translation does not change its fractions.
                assert TOKEN.findall(native_waves[index - 1]) == TOKEN.findall(draw_waves[index - 1].get("d"))
                attributes["data-clipstroke-keyframes"] = draw_waves[index - 1].get("data-clipstroke-keyframes")
            ET.SubElement(group, tag("path"), attributes)

        # Regular master uses the approved 21×18 pt canvas at 16 pt symbol size.
        # The other two masters retain the natural size changes of native weights.
        tx = float(re.findall(r"-?\d*\.?\d+", group.get("transform"))[4])
        width = {"Ultralight-S": 128.0, "Regular-S": 131.25, "Black-S": 155.0}[master]
        for line in root.iter(tag("line")):
            if line.get("id") == f"left-margin-{master}":
                line.set("x1", str(tx))
                line.set("x2", str(tx))
            elif line.get("id") == f"right-margin-{master}":
                line.set("x1", str(tx + width))
                line.set("x2", str(tx + width))

    asset = ASSETS / f"{name}.symbolset"
    asset.mkdir(exist_ok=True)
    contents = {"info": {"author": "xcode", "version": 1},
                "symbols": [{"filename": f"{name}.svg", "idiom": "universal"}]}
    (asset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    ET.indent(tree)
    tree.write(asset / f"{name}.svg", encoding="utf-8", xml_declaration=True)
    print(f"{name}: SF Symbols 7, 3 masters, {len(layers)} layers")


if __name__ == "__main__":
    generate("MenuBarMicrophoneVolume", waves=True, locked=False)
    generate("MenuBarMicrophoneVolumeLocked", waves=True, locked=True)
    generate("MenuBarMicrophoneUnknownLocked", waves=False, locked=True)
    for wave in range(1, 4):
        for locked in (False, True):
            generate(f"MenuBarMicrophoneDrawWave{wave}{'Locked' if locked else ''}",
                     waves=True, locked=locked, draw_wave=wave)
