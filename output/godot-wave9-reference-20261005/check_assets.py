"""本轮 61 位插画、既有资源与实际截图的交付校验。"""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
PACKS = {"wave9": 27, "wave10": 2, "wave11": 10, "wave12": 8, "wave13": 6, "origin": 8}
FILLERS = ["yaodaoji", "jutun-tongzi", "bingyong", "datiangou", "xuenv", "yingcao", "taohuayao", "guniao"]


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = read(ROOT / "godot/assets/redrawn/portraits.json")["units"]
content_units = read(ROOT / "godot/content/content.json")["units"]
content = {unit["id"]: unit for unit in content_units}
old = read(OUT / "baseline/godot/assets/redrawn/portraits.json")["units"]
assert len(old) == 189 and len(manifest) == 250
assert set(manifest) == set(content)
assert all(manifest[uid] == entry for uid, entry in old.items())
previous = []
for line in (OUT / "baseline/assets.sha256").read_text().splitlines():
    expected, filename = line.split(maxsplit=1)
    filename = filename.lstrip("*")
    assert digest(ROOT / filename) == expected, filename
    previous.append(f"PASS {filename}")
assert len(previous) == 189
(OUT / "previous-assets-check.log").write_text("\n".join(previous) + "\n")

units, checks = [], []
for pack, expected in PACKS.items():
    data = read(ROOT / f"godot/assets/redrawn/prompts-{pack}.json")
    assert len(data["units"]) == expected
    assert data["coverage"] == "complete-pack"
    for unit in data["units"]:
        uid = unit["id"]
        assert content[uid].get("pack", "origin") == pack
        assert uid not in old
        path = ROOT / unit["output"]
        assert path.read_bytes() == Path(unit["selected"]).read_bytes()
        assert manifest[uid] == {"path": unit["output"].removeprefix("godot/"), "focus": unit["focus"]}
        assert len(unit["focus"]) == 2 and all(0 <= v <= 1 for v in unit["focus"])
        with Image.open(path) as img:
            assert img.size == (1024, 1536) and img.format == "PNG", uid
        if unit["referenceKind"] == "project-setting":
            assert unit["reference"] is None
            assert "user-authorized" in unit["inputPolicy"]
            assert data["settingGenerationAuthorization"] == "用户 2026-10-05：允许按现有设定补画，统一画风。"
            assert unit["settingSource"] == "godot/content/content.json"
            assert unit["setting"]["color"] == content[uid]["color"]
            assert unit["existingArt"] == content[uid]["art"]
        else:
            source = ROOT / unit["reference"]
            assert source.is_file() and unit["inputPolicy"] == "original-reference-only"
            if unit["referenceKind"] == "original-unit-card":
                assert str(content[uid]["officialRole"]) == unit["role"]
                assert source.name.startswith(unit["role"] + "00_")
            elif uid == "fanqie":
                assert unit["referenceKind"] == "original-derived-card" and source.name == "146001_番茄_r146.png"
            elif uid == "bingqiang":
                assert unit["referenceKind"] == "original-spell-card" and source.name == "10609_冰墙.png"
            else:
                raise AssertionError(uid)
            for revision in unit.get("revisions", []):
                assert revision["input"] == unit["reference"]
                assert revision["inputPolicy"] == "original-reference-only"
        checks.append(f'PASS {uid} {unit["referenceKind"]} 1024x1536 selected_bytes focus')
        units.append(unit)
assert len(units) == 61 and len({u["id"] for u in units}) == 61
assert len([u for u in units if u["reference"]]) == 30
assert len([u for u in units if not u["reference"]]) == 31
assets = [f'{digest(ROOT / "godot" / entry["path"])}  godot/{entry["path"]}' for entry in manifest.values()]
assert len({line.split()[0] for line in assets}) == 250
(OUT / "assets.sha256").write_text("\n".join(assets) + "\n")
(OUT / "asset-check.log").write_text("\n".join(checks) + "\nASSET_OK new=61 total=250 previous=189 reference=30 setting=31\n")

screenshots, all_hashes = {}, []
for pack, expected in PACKS.items():
    ids = [u["id"] for u in content_units if u.get("pack", "origin") == pack]
    assert len(ids) == expected and set(ids) == {u["id"] for u in units if u["pack"] == pack}
    paths = sorted((OUT / f"final-shots/{pack}").glob("*.png"))
    decks = expected if expected < 4 else math.ceil(expected / 4)
    battles = math.ceil(expected / 4)
    count = math.ceil(expected / 8) + 1 + decks + battles + (pack == "origin")
    assert len(paths) == count, (pack, len(paths), count)
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
    assert len(deck) == decks and len(battle) == battles
    pool = ids.copy()
    if len(pool) < 8:
        pool += [uid for uid in FILLERS if uid not in pool]
    scheduled = [[pool[(offset + i) % len(pool)] for i in range(4)] for offset in range(0, expected, 4)]
    assert all(len(set(group)) == 4 for group in scheduled)
    assert set(ids).issubset({uid for group in scheduled for uid in group})
    log = (OUT / f"capture-{pack}.log").read_text()
    assert "REDRAWN_CAPTURE_DONE" in log
    assert all(marker not in log for marker in ["SCRIPT ERROR", "ERROR:", "WARNING:", "leaked", "still in use"])
    screenshots[pack] = {"units": expected, "screenshots": count, "size": [1280, 800], "gallery": gallery,
                         "deck": deck, "battle": battle, "allyGroups": scheduled, "allUnitsCovered": True,
                         "coverageSource": "capture_redrawn.gd _run_pack; small packs use distinct classic fillers"}
assert len(all_hashes) == len(set(all_hashes)) == 52
(OUT / "screenshot-check.json").write_text(json.dumps({"total": 52, "unique": 52, "packs": screenshots}, ensure_ascii=False, indent=2) + "\n")
print("ASSET_OK new=61 total=250 previous=189 reference=30 setting=31 SCREENSHOT_OK count=52 unique=52")
