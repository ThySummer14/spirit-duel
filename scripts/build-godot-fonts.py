#!/usr/bin/env python3
"""Subset the bundled Noto CJK fonts for the Godot build.

Godot's SystemFont lookup for "PingFang SC" resolves to the PingFang HK face on
macOS, which lacks simplified-only glyphs such as 敌. Shipping our own fonts
fixes that and makes the look identical on every platform.

Usage:
  python3 scripts/build-godot-fonts.py <NotoSansSC[wght].ttf> <NotoSerifSC[wght].ttf>

Sources (SIL OFL 1.1): https://github.com/google/fonts/tree/main/ofl/notosanssc
                       https://github.com/google/fonts/tree/main/ofl/notoserifsc
Glyph set: every character used by godot/content and godot/scripts, ASCII,
CJK punctuation, and GB2312 level-1 hanzi so typed search text still renders.
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = ROOT / "godot"
OUT = GODOT / "assets" / "fonts"


def project_chars() -> set[str]:
    chars: set[str] = set()
    for pattern in ("content/**/*.json", "scripts/**/*.gd", "scenes/**/*.tscn"):
        for path in GODOT.glob(pattern):
            chars.update(path.read_text(encoding="utf-8"))
    return chars


def gb2312_level1() -> set[str]:
    chars = set()
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return chars


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    chars = project_chars() | gb2312_level1()
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update(chr(c) for c in range(0x3000, 0x3040))  # CJK punctuation
    chars.update(chr(c) for c in range(0xFF00, 0xFFF0))  # full-width forms
    chars.update("·—…‹›«»“”‘’•●○◆◇★☆←→↑↓×÷±∞√")
    text = "".join(sorted(c for c in chars if c.isprintable()))
    OUT.mkdir(parents=True, exist_ok=True)
    for src, name in ((sys.argv[1], "NotoSansSC.ttf"), (sys.argv[2], "NotoSerifSC.ttf")):
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        options.hinting = False
        font = TTFont(src)
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        font.save(OUT / name)
        print(f"{name}: {len(text)} chars, {(OUT / name).stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
