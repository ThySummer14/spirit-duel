from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
bad = r"(?:SCRIPT )?ERROR:|\b(?:failures|FAILURES)=[1-9]|\b\w+_FAIL\b"


def clean(path):
    text = path.read_text()
    assert not re.search(bad, text), str(path)
    return text


def checks(path):
    text = clean(path)
    match = re.search(r"checks=(\d+) failures=0", text)
    assert match, str(path)
    return int(match[1])


log = clean(out / "final-godot.log")
assert "GODOT_VERIFY_ALL_OK" in log
assert (out / "godot-exit.txt").read_text().strip() == "0"
assert json.loads((out / "suite-sources-changed.json").read_text()) == []
scripts = re.search(r"for check_script in (.*?); do", (root / "scripts/godot-verify.sh").read_text()).group(1).split()
assert re.findall(r"^== godot (verify\S*) ==$", log, re.M) == scripts
assert len(scripts) == 87
assert re.search(r"PLAYTEST matches=60 completed=60 wins=\[[^\]]+\] stalls=0", log)
assert re.search(r"FOCUS rounds=20 completed=20 wins=\[[^\]]+\] stalls=0", log)
assert "units=250 portraits=500 matches=63 covered=250" in log
suite = json.loads((out / "suite-source-hashes.json").read_text())
build = json.loads((out / "build-source-hashes.json").read_text())
assert suite == build
for path, digest in suite.items():
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path

node = clean(out / "node.log")
assert "# tests 168" in node and "# fail 0" in node
assert "390 checks, 0 errors" in clean(out / "ui-audit.log")
for name in ("node", "ui-audit", "ui"):
    assert (out / (name + "-exit.txt")).read_text().strip() == "0", name
assert "ARMOR_LIMIT_BUILD_SOURCE_HASHES_OK" in clean(out / "pages-build.log")
pages = root / ".build/armor-limit-20261015"
for filename in ("index.html", "index.js", "index.wasm", "index.pck"):
    assert (pages / "pages/play" / filename).is_file(), filename
focused = {}
for name in ("armor_limit", "blessing_continuation"):
    focused[name] = checks(out / ("focused-" + name + ".log"))
    assert checks(pages / ("pages-verify-" + name + ".log")) == focused[name]
assert focused == {"armor_limit": 72, "blessing_continuation": 44}
assert checks(out / "ui-native.log") == 50
for physical in (1280, 1600):
    for scene in ("01-blessing-2", "01-blessing-3", "02-armor-inspector", "03-break-inspector"):
        assert (out / f"screenshots/{physical}-{scene}.png").is_file()
browser = (out / "browser-console-final.log").read_text()
assert "Errors: 0, Warnings: 0" in browser
assert "Godot Engine v4.6.3.stable" in browser and "WebGL 2.0" in browser
for scene in ("boot", "battle", "match"):
    assert (root / f"output/playwright/armor-limit-20261015/web-{scene}.png").is_file()
audit = json.loads((out / "rule-fidelity.json").read_text())
assert audit["fullCatalogRestored"] is False
assert (out / "audit-exit.txt").read_text().strip() == "1"
assert len(audit["errors"]) == 19
result = {
    "completedOn": "2026-10-15", "godotScripts": len(scripts),
    "focusedChecks": focused, "nativeUiChecks": 50,
    "randomAiMatches": 60, "focusedAiMatches": 20, "aiStalls": 0,
    "rosterUnits": 250, "rosterMatches": 63,
    "nativeViewportSizes": [[1280, 800], [1600, 740]],
    "nodeTests": 168, "uiAuditChecks": 390,
    "frozenSourceFiles": len(suite), "frozenSourcesMatchBuild": True,
    "browserSmoke": "main menu, start match, confirm opening hand; no console errors",
    "webVersion": "4.6.3.stable",
    "webBytes": sum(p.stat().st_size for p in (pages / "pages").rglob("*") if p.is_file()),
    "fidelitySummary": audit["summary"], "auditErrors": audit["errors"],
    "fullCatalogRestored": False,
    "remainingUnitEntries": sum(audit["summary"]["units"].values()) - audit["summary"]["units"]["source-backed-native"],
    "remainingCards": sum(audit["summary"]["cards"].values()) - audit["summary"]["cards"]["source-backed-native"],
}
(out / "validation.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print("ARMOR_LIMIT_ACCEPTANCE_OK", json.dumps(result, ensure_ascii=False))
