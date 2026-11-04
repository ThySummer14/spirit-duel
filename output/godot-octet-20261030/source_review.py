from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
snapshot = json.loads((out / "before-hashes.json").read_text())
old_tests = {p: h for p, h in snapshot.items() if Path(p).name.startswith("verify_") and p.endswith(".gd")}
changed_tests = [p for p, h in old_tests.items() if not (root / p).is_file() or digest(root / p) != h]
assert not changed_tests, changed_tests
before = json.loads((out / "before/godot/content/verified_rules.json").read_text())
current = json.loads((root / "godot/content/verified_rules.json").read_text())
expected = {"units": {}, "cards": {}}
art = []
for group in ["red-purple", "blue-green", "mirror-song", "charged-pair"]:
    folder = root / f"output/godot-{group}-20261030"
    overlay = json.loads((folder / "overlay.json").read_text())
    for kind in expected:
        expected[kind].update(overlay[kind])
        for key, value in overlay[kind].items():
            assert current[kind][key] == value, (kind, key)
    for entry in json.loads((folder / "card-art-manifest.json").read_text()):
        assert digest(root / entry["source"]) == entry["sha256"], entry["source"]
        assert digest(root / entry["target"]) == entry["sha256"], entry["target"]
        art.append(entry)
assert len(art) == 64 and len({a["target"] for a in art}) == 64
diffs = {kind: sorted(key for key in set(before[kind]) | set(current[kind]) if before[kind].get(key) != current[kind].get(key)) for kind in expected}
for kind in expected:
    assert set(diffs[kind]) == set(expected[kind]), (kind, diffs[kind])
assert len(expected["units"]) == 8 and len(expected["cards"]) == 65
partial = [key for key, card in expected["cards"].items() if not card.get("verifiedRules", False)]
assert partial == ["c20602"], partial
assert current["cards"]["c20602"]["bgMingchePool"] == []
for kind in expected:
    for key, definition in expected[kind].items():
        assert definition.get("verificationPending"), (kind, key)
for path in ["godot/content/content.json", "godot/content/factions.json"]:
    assert digest(root / path) == snapshot[path], path
factions = json.loads((root / "godot/content/factions.json").read_text())
assert len(factions["units"]) == 215
result = {
    "oldVerifyScriptsUnchanged": len(old_tests),
    "changedSnapshotFiles": sorted(p for p, h in snapshot.items() if not (root / p).is_file() or digest(root / p) != h),
    "changedOverlayDefinitions": diffs,
    "originalCardArtMatches": len(art),
    "fullMainCards": 63,
    "partialMainCards": partial,
    "derivatives": ["julijialuo-wan"],
    "baseContentAndFactionsUnchanged": True,
    "factionEvidenceEntries": len(factions["units"]),
}
(out / "source-review.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(f"OCTET_SOURCE_REVIEW_OK old_tests={len(old_tests)} original_art={len(art)} roles=8 main_full=63 partial=1")
