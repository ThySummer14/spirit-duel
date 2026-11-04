from pathlib import Path
import json
import re
import subprocess

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
binary = root / ".build/tools/godot-4.6.3.app/Contents/MacOS/Godot"
names = [
    "combat", "armor_limit", "monk_cleaner", "owl_insect", "instant", "battle_status",
    "movement", "whale", "box_maiden", "sun_smoke", "puppet", "garuda", "oni_asura",
    "moon_bamboo", "book_jue", "eye_crab", "bond_dream", "wind_night_mask",
    "link_cross", "spider_lily", "butterfly", "yaoginshi", "koi_fragrance", "signed_debuff",
]
results = []
for name in names:
    result = subprocess.run(
        [str(binary), "--headless", "--path", str(root / "godot"), "--script", f"res://scripts/verify_{name}.gd"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90,
    )
    (out / f"regression-{name}.log").write_text(result.stdout)
    failed = result.returncode != 0 or re.search(r"(?:SCRIPT )?ERROR:|(?:_FAIL|failures=[1-9])", result.stdout) is not None
    results.append({"script": f"verify_{name}.gd", "exitCode": result.returncode, "passed": not failed})
    (out / "regressions.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"{name}: {'FAIL' if failed else 'OK'}", flush=True)
    if failed:
        print(result.stdout, flush=True)
if not all(r["passed"] for r in results):
    raise SystemExit(1)
print(f"RESTORATION_REGRESSIONS_OK groups={len(results)}", flush=True)
