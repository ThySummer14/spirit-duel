"""Focused prior-rule regression for the eight-character batch; no source edits."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import time

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
binary = root / ".build/tools/godot-4.6.3.app/Contents/MacOS/Godot"
names = [
    "combat", "armor_limit", "monk_cleaner", "owl_insect", "instant", "battle_status",
    "movement", "whale", "box_maiden", "sun_smoke", "puppet", "garuda", "oni_asura",
    "moon_bamboo", "book_jue", "eye_crab", "bond_dream", "wind_night_mask",
    "link_cross", "spider_lily", "butterfly", "yaoginshi", "koi_fragrance", "signed_debuff",
    "lantern", "cotton", "sea_butterfly", "silk_ninja", "susanoo", "sparrow", "futakuchi", "fortune_pair",
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_hashes():
    paths = sorted((root / "godot/scripts").rglob("*.gd"))
    paths += sorted((root / "godot/content").glob("*.json"))
    return {str(p.relative_to(root)): sha(p) for p in paths}


before = source_hashes()
results = []
for name in names:
    script = root / f"godot/scripts/verify_{name}.gd"
    rules_only = '"--rules-only"' in script.read_text()
    command = [str(binary), "--headless", "--path", str(root / "godot"), "--script", f"res://scripts/verify_{name}.gd"]
    if rules_only:
        command.extend(["--", "--rules-only"])
    started = time.monotonic()
    try:
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
        code, output = process.returncode, process.stdout
        timed_out = False
    except subprocess.TimeoutExpired as error:
        code, timed_out = None, True
        raw = error.stdout or ""
        output = raw.decode(errors="replace") if isinstance(raw, bytes) else raw
        output += "\nREGRESSION_RUNNER_TIMEOUT after90s\n"
    (out / f"{name}.log").write_text(output)
    errors = re.findall(r"^.*(?:(?:SCRIPT )?ERROR:|(?:_FAIL\b|failures=[1-9]\d*)).*$", output, re.MULTILINE)
    counts = re.findall(r"\bchecks=(\d+)", output)
    cases = re.findall(r"\bcases=(\d+)", output)
    passed = code == 0 and not errors and bool(counts or cases)
    results.append({
        "script": str(script.relative_to(root)), "scriptSha256": sha(script),
        "command": command, "rulesOnly": rules_only, "exitCode": code,
        "timedOut": timed_out, "seconds": round(time.monotonic() - started, 3),
        "checks": int(counts[-1]) if counts else 0,
        "cases": int(cases[-1]) if cases else 0,
        "passed": passed, "errors": errors,
        "log": str((out / f"{name}.log").relative_to(root)),
    })
    (out / "results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
    print(f"{name}: {'OK' if passed else 'FAIL'} checks={results[-1]['checks']} cases={results[-1]['cases']}", flush=True)
    if not passed:
        print(output, flush=True)

after = source_hashes()
changed = {path: {"before": digest, "after": after.get(path)} for path, digest in before.items() if after.get(path) != digest}
changed.update({path: {"before": None, "after": digest} for path, digest in after.items() if path not in before})
summary = {
    "groups": len(results), "passedGroups": sum(r["passed"] for r in results),
    "checks": sum(r["checks"] for r in results), "cases": sum(r["cases"] for r in results),
    "sourceChangesDuringRun": changed,
    "scope": "prior 24 targeted groups plus lantern/cotton/sea_butterfly/silk_ninja/susanoo/sparrow/futakuchi/fortune_pair; native-only UI omitted where rules-only is supported",
}
(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
print(f"OCTET_REGRESSIONS groups={summary['groups']} passed={summary['passedGroups']} checks={summary['checks']} cases={summary['cases']}", flush=True)
if not all(r["passed"] for r in results):
    raise SystemExit(1)
