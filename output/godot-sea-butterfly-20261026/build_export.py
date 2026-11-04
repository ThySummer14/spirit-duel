from pathlib import Path
import hashlib
import importlib.util
import json
import os

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("batch_pages", root / "scripts/build-pages.py")
pages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pages)
os.environ["GODOT_BIN"] = str(root / ".build/tools/godot-4.6.3.app/Contents/MacOS/Godot")
os.environ["GODOT_WEB_TEMPLATE"] = str(root / ".build/tools/web_nothreads_release.zip")
pages.PROJECT = root / ".build/sea-butterfly-20261026/godot-web-src"
pages.SITE = root / ".build/sea-butterfly-20261026/pages"
original_run = pages.run_godot
original_subprocess_run = pages.subprocess.run
phase_results = []
def monitored_run(*args, **kwargs):
    result = original_subprocess_run(*args, **kwargs)
    command = args[0] if args else kwargs.get("args", [])
    if isinstance(command, list) and "--headless" in command:
        phase_results.append({"phase": "import" if "--import" in command else "export", "exitCode": result.returncode})
        (out / "build-phase-results.json").write_text(json.dumps(phase_results, indent=2) + "\n")
    return result
pages.subprocess.run = monitored_run

def run(binary, phase, *args):
    if phase == "import":
        args = (*args, "--single-threaded-scene")
    return original_run(binary, phase, *args)

pages.run_godot = run
paths = sorted((root / "godot/scripts").rglob("*.gd")) + sorted((root / "godot/assets/official/cards").glob("*.png")) + [root / "godot/content/verified_rules.json", root / "godot/content/content.json"]
hashes = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
pages.main()
for path, digest in hashes.items():
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path
    assert hashlib.sha256((pages.PROJECT / Path(path).relative_to("godot")).read_bytes()).hexdigest() == digest, path
(out / "build-source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")
print("SEA_BUTTERFLY_BUILD_SOURCE_HASHES_OK", flush=True)
