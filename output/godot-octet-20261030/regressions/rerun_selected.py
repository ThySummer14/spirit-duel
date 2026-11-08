"""Rerun only failed/affected groups after a production fix, preserving first evidence."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
binary = root / ".build/tools/godot-4.6.3.app/Contents/MacOS/Godot"
first = out / "results-first.json"
if not first.exists():
    first.write_bytes((out / "results.json").read_bytes())
    (out / "summary-first.json").write_bytes((out / "summary.json").read_bytes())
results = json.loads((out / "results.json").read_text())
names = sys.argv[1:] or [Path(r["script"]).stem.removeprefix("verify_") for r in results if not r["passed"]]
unknown = set(names) - {Path(r["script"]).stem.removeprefix("verify_") for r in results}
if unknown:
    raise SystemExit(f"Untracked regression groups: {sorted(unknown)}")
for name in names:
    script = root / f"godot/scripts/verify_{name}.gd"
    command = [str(binary), "--headless", "--path", str(root / "godot"), "--script", f"res://scripts/verify_{name}.gd"]
    rules_only = '"--rules-only"' in script.read_text()
    if rules_only:
        command.extend(["--", "--rules-only"])
    started = time.monotonic()
    try:
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
        code, output, timed_out = process.returncode, process.stdout, False
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or ""
        code, timed_out = None, True
        output = (raw.decode(errors="replace") if isinstance(raw, bytes) else raw) + "\nREGRESSION_RUNNER_TIMEOUT after90s\n"
    log = out / f"{name}-final.log"
    log.write_text(output)
    errors = re.findall(r"^.*(?:(?:SCRIPT )?ERROR:|(?:_FAIL\b|failures=[1-9]\d*)).*$", output, re.MULTILINE)
    counts = re.findall(r"\bchecks=(\d+)", output)
    cases = re.findall(r"\bcases=(\d+)", output)
    passed = code == 0 and not errors and bool(counts or cases)
    record = {
        "script": str(script.relative_to(root)), "scriptSha256": hashlib.sha256(script.read_bytes()).hexdigest(),
        "command": command, "rulesOnly": rules_only, "exitCode": code, "timedOut": timed_out,
        "seconds": round(time.monotonic() - started, 3), "checks": int(counts[-1]) if counts else 0,
        "cases": int(cases[-1]) if cases else 0, "passed": passed, "errors": errors,
        "log": str(log.relative_to(root)), "rerunAfterContributionRefreshFix": True,
    }
    index = next(i for i, item in enumerate(results) if item["script"] == record["script"])
    results[index] = record
    (out / "results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
    print(f"{name}: {'OK' if passed else 'FAIL'} checks={record['checks']} cases={record['cases']}", flush=True)
    if not passed:
        print(output, flush=True)
summary = json.loads((out / "summary-first.json").read_text())
summary.update({"passedGroups": sum(r["passed"] for r in results), "checks": sum(r["checks"] for r in results), "cases": sum(r["cases"] for r in results), "rerunGroups": names})
(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
print(f"OCTET_REGRESSIONS groups={summary['groups']} passed={summary['passedGroups']} checks={summary['checks']} cases={summary['cases']}", flush=True)
if not all(r["passed"] for r in results):
    raise SystemExit(1)
