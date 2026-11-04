from pathlib import Path
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
binary = root / ".build/tools/godot-4.6.3.app/Contents/MacOS/Godot"
checks = [
    ("mirror_song", "godot-mirror-song-20261030/rules-final4.log"),
    ("red_purple", "godot-red-purple-20261030/rules-final-shared.log"),
    ("blue_green", "godot-blue-green-20261030/rules-final-shared.log"),
    ("charged_pair", "godot-charged-pair-20261030/rules-final-shared.log"),
    ("octet_cross", "godot-octet-20261030/cross-rules-final.log"),
]
results_path = out / "final-rules.json"
results = json.loads(results_path.read_text()) if results_path.exists() else []
for name, log in checks:
    if sys.argv[1:] and name not in sys.argv[1:]:
        continue
    args = [str(binary), "--headless", "--path", str(root / "godot"), "--script", f"res://scripts/verify_{name}.gd"]
    if name != "octet_cross":
        args.extend(["--", "--rules-only"])
    run = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    path = root / "output" / log
    path.write_text(run.stdout)
    match = re.search(r"_OK checks=(\d+) failures=(\d+)", run.stdout)
    passed = run.returncode == 0 and match is not None and int(match[2]) == 0 and not re.search(r"(?:SCRIPT )?ERROR:", run.stdout)
    item = {"name": name, "exitCode": run.returncode, "checks": int(match[1]) if match else None, "passed": passed, "log": str(path.relative_to(root))}
    results = [r for r in results if r["name"] != name] + [item]
    results_path.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    print(f"{name}: {'PASS' if passed else 'FAIL'} checks={item['checks']}", flush=True)
    if not passed:
        raise SystemExit(1)
