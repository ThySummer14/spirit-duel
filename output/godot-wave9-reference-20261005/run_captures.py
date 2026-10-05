"""依次采集本轮资料包的真实 Godot 渲染；验证进程隔离玩家存档。"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
GODOT = "/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot"

for pack in ["wave9", "wave10", "wave11", "wave12", "wave13", "origin"]:
    directory = OUT / "final-shots" / pack
    directory.mkdir(parents=True, exist_ok=True)
    print(f"CAPTURE_START {pack}", flush=True)
    with (OUT / f"capture-{pack}.log").open("w") as log:
        result = subprocess.run([
            GODOT, "--path", str(ROOT / "godot"),
            "--script", "res://scripts/capture_redrawn.gd", "--",
            str(directory), f"--pack={pack}",
        ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    text = (OUT / f"capture-{pack}.log").read_text()
    assert result.returncode == 0 and "REDRAWN_CAPTURE_DONE" in text, pack
    assert all(marker not in text for marker in ["SCRIPT ERROR", "ERROR:", "WARNING:", "leaked", "still in use"]), text
    print(f"CAPTURE_DONE {pack} shots={len(list(directory.glob('*.png')))}", flush=True)

print("ALL_CAPTURES_DONE", flush=True)
