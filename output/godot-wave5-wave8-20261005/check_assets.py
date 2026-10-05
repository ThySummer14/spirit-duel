"""检查本批最终素材、旧资源保留和截图覆盖，写入可复核验收结果。"""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = read(ROOT / "godot/assets/redrawn/portraits.json")["units"]
content_units = read(ROOT / "godot/content/content.json")["units"]
content = {unit["id"]: unit for unit in content_units}
old = read(OUT / "baseline/godot/assets/redrawn/portraits.json")["units"]
assert len(old) == 83 and len(manifest) == 189
assert all(manifest[uid] == entry for uid, entry in old.items())
previous = []
for line in (ROOT / "output/godot-wave4-20261005/assets.sha256").read_text().splitlines():
    expected, filename = line.split(maxsplit=1)
    filename = filename.lstrip("*")
    assert digest(ROOT / filename) == expected, filename
    previous.append(f"PASS {filename}")
assert len(previous) == 83
(OUT / "previous-assets-check.log").write_text("\n".join(previous) + "\n")

units, assets, checks = [], [], []
for pack, expected in {"wave5": 24, "wave6": 32, "wave7": 25, "wave8": 25}.items():
    data = read(ROOT / f"godot/assets/redrawn/prompts-{pack}.json")
    assert len(data["units"]) == expected
    for unit in data["units"]:
        path = ROOT / unit["output"]
        source = ROOT / unit["reference"]
        assert str(content[unit["id"]]["officialRole"]) == unit["role"]
        assert content[unit["id"]]["pack"] == pack
        assert source.is_file() and source.name.startswith(unit["role"] + "00_")
        assert unit["inputPolicy"] == "original-reference-only"
        assert unit["reference"].startswith("art-reference-official/卡面/01_式神/")
        assert path.read_bytes() == Path(unit["selected"]).read_bytes()
        assert manifest[unit["id"]] == {"path": unit["output"].removeprefix("godot/"), "focus": unit["focus"]}
        assert len(unit["focus"]) == 2 and all(0 <= v <= 1 for v in unit["focus"])
        for revision in unit.get("revisions", []):
            assert revision["input"] == unit["reference"]
            assert revision["inputPolicy"] == "original-reference-only"
        with Image.open(path) as img:
            assert img.size == (1024, 1536) and img.format == "PNG", unit["id"]
        checks.append(f'PASS {unit["id"]} original_reference role={unit["role"]} 1024x1536 selected_bytes focus source_only_retries')
        units.append(unit)
assert len(units) == 106 and len({digest(ROOT / u["output"]) for u in units}) == 106

for uid, entry in manifest.items():
    path = ROOT / "godot" / entry["path"]
    assets.append(f'{digest(path)}  godot/{entry["path"]}')
assert len({line.split()[0] for line in assets}) == 189
(OUT / "assets.sha256").write_text("\n".join(assets) + "\n")
(OUT / "asset-check.log").write_text("\n".join(checks) + "\nASSET_OK new=106 total=189 previous=83\n")

screenshots, all_hashes = {}, []
for pack, expected in {"wave5": 24, "wave6": 32, "wave7": 25, "wave8": 25}.items():
    ids = [u["id"] for u in units if u["pack"] == pack]
    assert ids == [u["id"] for u in content_units if u.get("pack") == pack]
    paths = sorted((OUT / f"final-shots/{pack}").glob("*.png"))
    count = math.ceil(expected / 8) + 1 + 2 * math.ceil(expected / 4)
    assert len(paths) == count
    hashes = []
    for path in paths:
        with Image.open(path) as img:
            assert img.size == (1280, 800)
        hashes.append(digest(path))
    assert len(set(hashes)) == count
    all_hashes.extend(hashes)
    gallery = sorted(p.name for p in paths if "portraits" in p.name)
    deck = sorted(p.name for p in paths if "deck" in p.name)
    battle = sorted(p.name for p in paths if "battle" in p.name)
    assert len(gallery) == math.ceil(expected / 8)
    assert len(deck) == len(battle) == math.ceil(expected / 4)
    scheduled = [[ids[(offset + i) % expected] for i in range(4)] for offset in range(0, expected, 4)]
    assert set(uid for group in scheduled for uid in group) == set(ids)
    log = (OUT / f"capture-{pack}.log").read_text()
    assert "REDRAWN_CAPTURE_DONE" in log
    assert all(marker not in log for marker in ["SCRIPT ERROR", "ERROR:", "WARNING:", "leaked", "still in use"])
    screenshots[pack] = {"units": expected, "screenshots": count, "size": [1280, 800],
                         "gallery": gallery, "deck": deck, "battle": battle,
                         "allyGroups": scheduled, "allUnitsCovered": True,
                         "coverageSource": "capture_redrawn.gd _run_pack, matching roster and successful capture log"}
assert len(all_hashes) == len(set(all_hashes)) == 75
(OUT / "screenshot-check.json").write_text(json.dumps({"total": 75, "unique": 75, "packs": screenshots}, ensure_ascii=False, indent=2) + "\n")
print("ASSET_OK new=106 total=189 previous=83 SCREENSHOT_OK count=75 unique=75")
