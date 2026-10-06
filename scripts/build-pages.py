#!/usr/bin/env python3
"""Build the legacy browser game and current Godot game into .build/pages.

GODOT_BIN must be Godot 4.6.3; GODOT_WEB_TEMPLATE optionally points to the
official web_nothreads_release.zip when templates are not installed globally.
Only the disposable build copy uses smaller, lossy portrait imports.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / ".build"
PROJECT = BUILD / "godot-web-src"
SITE = BUILD / "pages"
VERSION = "4.6.3"


def godot_binary():
    candidates = [os.environ.get("GODOT_BIN"), shutil.which("godot"),
                  str(Path.home() / "Applications/Godot-4.6.3.app/Contents/MacOS/Godot")]
    binary = next((p for p in candidates if p and Path(p).is_file()), None)
    if not binary:
        raise RuntimeError("Set GODOT_BIN to a Godot 4.6.3 executable")
    actual = subprocess.check_output([binary, "--version"], text=True).strip()
    if not actual.startswith(VERSION + ".stable"):
        raise RuntimeError(f"Expected Godot {VERSION}.stable, got {actual}")
    return binary


def run_godot(binary, phase, *args):
    result = subprocess.run([binary, "--headless", "--path", str(PROJECT), *args],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (BUILD / f"pages-{phase}.log").write_text(result.stdout)
    if result.returncode or re.search(r"(?:SCRIPT )?ERROR:", result.stdout):
        print(result.stdout)
        raise RuntimeError(f"Godot {phase} failed; see .build/pages-{phase}.log")
    print(f"Godot {phase}: OK", flush=True)


def main():
    binary = godot_binary()
    BUILD.mkdir(exist_ok=True)
    # These fixed paths contain only outputs owned by this build command.
    for path in (PROJECT, SITE):
        if path.exists():
            shutil.rmtree(path)
    shutil.copytree(ROOT / "godot", PROJECT,
                    ignore=shutil.ignore_patterns(".godot", ".DS_Store"))
    settings = PROJECT / "project.godot"
    settings.write_text(settings.read_text().replace('"4.8", "GL Compatibility"',
                                                      '"4.6", "GL Compatibility"'))
    for imported in (PROJECT / "assets/redrawn").rglob("*.png.import"):
        text = imported.read_text()
        text = re.sub(r"^process/size_limit=\d+$", "process/size_limit=768", text, flags=re.M)
        text = re.sub(r"^compress/mode=\d+$", "compress/mode=1", text, flags=re.M)
        text = re.sub(r"^compress/lossy_quality=[\d.]+$", "compress/lossy_quality=0.8", text, flags=re.M)
        imported.write_text(text)
    custom_template = os.environ.get("GODOT_WEB_TEMPLATE")
    if custom_template:
        template = Path(custom_template).resolve()
        if not template.is_file():
            raise RuntimeError(f"Missing web template: {template}")
        preset = PROJECT / "export_presets.cfg"
        preset.write_text(preset.read_text().replace('custom_template/release=""',
                                                     "custom_template/release=" + json.dumps(str(template), ensure_ascii=False)))
    SITE.mkdir()
    for pattern in ("*.html", "*.css", "*.js"):
        for source in ROOT.glob(pattern):
            shutil.copy2(source, SITE / source.name)
    shutil.copytree(ROOT / "assets", SITE / "assets")
    (SITE / ".nojekyll").touch()
    (SITE / "play").mkdir()
    run_godot(binary, "import", "--editor", "--import")
    run_godot(binary, "export", "--export-release", "Web", str(SITE / "play/index.html"))
    required = ("index.html", "index.js", "index.wasm", "index.pck")
    for filename in required:
        if not (SITE / "play" / filename).is_file():
            raise RuntimeError(f"Missing exported file: {filename}")
    size = sum(p.stat().st_size for p in SITE.rglob("*") if p.is_file())
    if size > 900 * 1024 * 1024:
        raise RuntimeError("Pages output exceeds the 900 MiB build budget")
    print(f"Pages build: {size / 1024 / 1024:.1f} MiB, current game at /play/", flush=True)


if __name__ == "__main__":
    main()
