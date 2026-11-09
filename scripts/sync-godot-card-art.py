#!/usr/bin/env python3
"""Copy available original full card faces for the requested unit IDs."""
import argparse
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("units", nargs="*", help="Content unit IDs, e.g. shanfeng")
    parser.add_argument("--all", action="store_true", help="check every content unit")
    parser.add_argument("--missing-only", action="store_true", help="retain existing faces and verify the displayed card name")
    args = parser.parse_args()
    content = json.loads((ROOT / "godot/content/content.json").read_text())
    roles = {u["id"]: str(u.get("officialRole", "")) for u in content["units"]}
    known = set(roles)
    if not args.units and not args.all:
        parser.error("Supply unit IDs or --all")
    if set(args.units) - known:
        parser.error("Unknown units: " + ", ".join(sorted(set(args.units) - known)))
    units = known if args.all else set(args.units)
    verified = json.loads((ROOT / "godot/content/verified_rules.json").read_text())["cards"]
    originals = {}
    named = {}
    for path in sorted((ROOT / "art-reference-official/卡面-按版本").rglob("*.png")):
        number, name, kind = path.stem.split("_", 2)
        originals[number] = path
        if kind != "式神":
            owner = path.parent.name.split("_", 1)[0]
            named.setdefault((owner, name), []).append(path)
    destination = ROOT / "godot/assets/official/cards"
    destination.mkdir(parents=True, exist_ok=True)
    copied, missing = [], []
    for card in content["cards"]:
        if card.get("unitId") not in units:
            continue
        target = destination / (card["id"] + ".png")
        source = originals.get(card["id"].removeprefix("c"))
        if args.missing_only:
            if target.is_file() or card.get("cardArt"):
                continue
            name = verified.get(card["id"], {}).get("name", card["name"])
            if source and source.stem.split("_", 2)[1] != name:
                source = None
            if source is None and card.get("token"):
                choices = named.get((roles[card["unitId"]], name), [])
                if len(choices) == 1:
                    source = choices[0]
        if source is None:
            missing.append(card["id"])
            continue
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copy2(source, target)
        copied.append(card["id"])
    print(json.dumps({"available": len(copied), "cards": copied, "missing": missing}, ensure_ascii=False))


if __name__ == "__main__":
    main()
