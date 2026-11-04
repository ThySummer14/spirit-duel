from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
rules = json.loads((out / "final-rules.json").read_text())
assert len(rules) == 5 and all(r["passed"] for r in rules)
native = []
for group, filename, base, textures, interactions in [
    ("red-purple", "native.log", 265, 16, 16),
    ("blue-green", "native-final.log", 219, 16, 16),
    ("mirror-song", "native-first.log", 259, 16, 20),
    ("charged-pair", "native-first.log", 159, 16, 12),
]:
    path = root / f"output/godot-{group}-20261030" / filename
    text = path.read_text()
    match = re.search(r"_OK checks=(\d+) failures=(\d+)", text)
    assert match and int(match[2]) == 0 and int(match[1]) == base + textures + interactions and "ERROR:" not in text, path
    native.append({"group": group, "checks": int(match[1]), "includedRules": base, "textures": textures, "interactionChecks": interactions, "passed": True, "log": str(path.relative_to(root))})
regressions = json.loads((out / "regressions/results.json").read_text())
continuations = json.loads((out / "regressions/continuation-results.json").read_text())
unique = {r["script"]: r for r in regressions + continuations}
for check in rules + list(unique.values()):
    assert check["passed"]
    assert "ERROR:" not in (root / check["log"]).read_text(), check["log"]
source_review = json.loads((out / "source-review.json").read_text())
hashes = json.loads((out / "build-source-hashes.json").read_text())
for path, expected in hashes.items():
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == expected, path
    assert hashlib.sha256((root / ".build/octet-20261030/godot-web-src" / Path(path).relative_to("godot")).read_bytes()).hexdigest() == expected, path
phases = json.loads((out / "build-phase-results.json").read_text())
assert len(phases) == 2 and all(p["exitCode"] == 0 for p in phases)
for phase in ["import", "export"]:
    assert "ERROR:" not in (out / f"build-{phase}.log").read_text()
package = json.loads((out / "package-check.json").read_text())
assert package["passed"]
audit = json.loads((out / "audit.json").read_text())
before_audit = json.loads((root / "output/godot-restoration-20261028/audit.json").read_text())
assert not audit["fullCatalogRestored"]
new_errors = sorted(set(audit["errors"]) - set(before_audit["errors"]))
assert new_errors == ["Missing executable reviewed rules: c20602"]
assert set(before_audit["errors"]).issubset(audit["errors"])
size = sum(p.stat().st_size for p in (root / ".build/octet-20261030/pages").rglob("*") if p.is_file())
summary = {
    "checkedOn": "2026-11-02",
    "roles": ["huoqumo", "yuanjiulanghu", "yingxueji", "jingliuliqian", "yunwaijing", "song", "wannianzhu", "shuzhu"],
    "mainCards": 64,
    "mainCardsWithReviewedExecutableRules": 63,
    "partialMainCards": ["c20602"],
    "allNewDefinitionsRetainVerificationPending": True,
    "ruleChecks": rules,
    "pureRoleChecks": sum(r["checks"] for r in rules if r["name"] != "octet_cross"),
    "crossChecks": next(r["checks"] for r in rules if r["name"] == "octet_cross"),
    "nativeChecks": native,
    "nativeScreenshotsReviewed": 26,
    "uniqueOldRegressionGroups": len(unique),
    "uniqueOldRegressionChecks": sum(r.get("checks", 0) for r in unique.values()),
    "uniqueOldRegressionCases": sum(r.get("cases", 0) for r in unique.values()),
    "oldVerifyScriptsUnchanged": source_review["oldVerifyScriptsUnchanged"],
    "originalArtMatches": source_review["originalCardArtMatches"],
    "build": {"passed": True, "sourceHashesMatched": len(hashes), "sizeBytes": size, "sizeMiB": round(size / 1024 / 1024, 1), "path": ".build/octet-20261030/pages/play", "packageProbe": package},
    "strictAudit": {"exitCode": 1, "fullCatalogRestored": False, "summary": audit["summary"], "errorCount": len(audit["errors"]), "retainedOldErrors": len(before_audit["errors"]), "newErrors": new_errors},
}
(out / "checks.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
charged = root / "output/godot-charged-pair-20261030"
(charged / "checks.json").write_text(json.dumps({"rules": next(r for r in rules if r["name"] == "charged_pair"), "native": next(r for r in native if r["group"] == "charged-pair"), "screenshotsReviewed": sorted(str(p.relative_to(charged)) for p in (charged / "screenshots").glob("*.png")), "sourceHash": hashlib.sha256((root / "godot/scripts/charged_pair_rules.gd").read_bytes()).hexdigest(), "crossChecks": summary["crossChecks"], "originalArtMatches": 16}, ensure_ascii=False, indent=2) + "\n")
print(f"OCTET_CHECKS_OK role_rules={summary['pureRoleChecks']} cross={summary['crossChecks']} old_groups={len(unique)} build_hashes={len(hashes)} catalog_restored=false partial=c20602")
