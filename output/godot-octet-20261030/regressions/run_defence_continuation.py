"""Four prior-rule groups affected by the verified combat-victim continuation fixes."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import time

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
binary = root / ".build/tools/godot-4.6.3.app/Contents/MacOS/Godot"
results = []
for name in ["sun_smoke", "poison_pair", "yujiazhu", "movement"]:
    script = root / f"godot/scripts/verify_{name}.gd"
    command = [str(binary), "--headless", "--path", str(root / "godot"), "--script", f"res://scripts/verify_{name}.gd"]
    only = '"--rules-only"' in script.read_text()
    if only:
        command.extend(["--", "--rules-only"])
    started = time.monotonic()
    process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
    log = out / f"continuation-{name}.log"
    log.write_text(process.stdout)
    errors = re.findall(r"^.*(?:(?:SCRIPT )?ERROR:|(?:_FAIL\b|failures=[1-9]\d*)).*$", process.stdout, re.MULTILINE)
    counts = re.findall(r"\bchecks=(\d+)", process.stdout)
    passed = process.returncode == 0 and not errors and bool(counts)
    results.append({"script": str(script.relative_to(root)), "scriptSha256": hashlib.sha256(script.read_bytes()).hexdigest(), "rulesOnly": only, "checks": int(counts[-1]) if counts else 0, "exitCode": process.returncode, "passed": passed, "errors": errors, "log": str(log.relative_to(root)), "seconds": round(time.monotonic() - started, 3)})
    (out / "continuation-results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
    print(f"{name}: {'OK' if passed else 'FAIL'} checks={results[-1]['checks']}", flush=True)
    if not passed:
        print(process.stdout, flush=True)
print(f"CONTINUATION_REGRESSIONS groups={len(results)} passed={sum(r['passed'] for r in results)} checks={sum(r['checks'] for r in results)}", flush=True)
if not all(r["passed"] for r in results):
    raise SystemExit(1)
