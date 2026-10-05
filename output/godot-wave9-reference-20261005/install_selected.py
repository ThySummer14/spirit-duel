"""安装已复核的选图字节和焦点；不做图片后处理。"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
PACKS = ["wave9", "wave10", "wave11", "wave12", "wave13", "origin"]
focus = json.loads((OUT / "focus-review.json").read_text())
p = ROOT / "godot/assets/redrawn/portraits.json"
manifest = json.loads(p.read_text())
previous = json.loads((OUT / "baseline/godot/assets/redrawn/portraits.json").read_text())
assert all(manifest["units"][uid] == entry for uid, entry in previous["units"].items())
all_units = []
for pack in PACKS:
    doc_path = ROOT / f"godot/assets/redrawn/prompts-{pack}.json"
    doc = json.loads(doc_path.read_text())
    for unit in doc["units"]:
        uid = unit["id"]
        assert unit.get("selected") and uid in focus, uid
        assert uid not in previous["units"], uid
        unit["focus"] = focus[uid]
        target = ROOT / unit["output"]
        target.parent.mkdir(parents=True, exist_ok=True)
        selected = Path(unit["selected"])
        if target.exists():
            assert target.read_bytes() == selected.read_bytes(), f"Unexpected existing asset: {uid}"
        else:
            shutil.copyfile(selected, target)
        manifest["units"][uid] = {"path": unit["output"].removeprefix("godot/"), "focus": unit["focus"]}
        all_units.append(unit)
    doc_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
assert len(all_units) == 61 and len(manifest["units"]) == 250
p.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
(OUT / "selected-roster.json").write_text(json.dumps(all_units, ensure_ascii=False, indent=2) + "\n")
print("SELECTED_INSTALLED new=61 total=250 previous=189")
