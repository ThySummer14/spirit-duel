#!/usr/bin/env python3
"""Copy available original full card faces for the requested unit IDs."""
import argparse
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("units", nargs="+", help="Content unit IDs, e.g. shanfeng")
    args = parser.parse_args()
    content = json.loads((ROOT / "godot/content/content.json").read_text())
    known = {u["id"] for u in content["units"]}
    if set(args.units) - known:
        parser.error("Unknown units: " + ", ".join(sorted(set(args.units) - known)))
    originals = {}
    for path in sorted((ROOT / "art-reference-official/卡面-按版本").rglob("*.png")):
        originals[path.name.split("_", 1)[0]] = path
    destination = ROOT / "godot/assets/official/cards"
    destination.mkdir(parents=True, exist_ok=True)
    copied, missing = [], []
    for card in content["cards"]:
        if card.get("unitId") not in args.units:
            continue
        source = originals.get(card["id"].removeprefix("c"))
        if source is None:
            missing.append(card["id"])
            continue
        target = destination / (card["id"] + ".png")
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copy2(source, target)
        copied.append(card["id"])
    print(json.dumps({"available": len(copied), "cards": copied, "missing": missing}, ensure_ascii=False))


if __name__ == "__main__":
    main()
