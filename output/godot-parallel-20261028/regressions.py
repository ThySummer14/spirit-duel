from pathlib import Path
import json
import subprocess
import time

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
godot = root / '.build/tools/godot-4.6.3.app/Contents/MacOS/Godot'
names = ['combat', 'movement', 'instant', 'sun_smoke', 'lantern', 'glutton',
         'armor_limit', 'battle_status', 'fortune_pair', 'spider_lily', 'butterfly', 'sparrow']
results = []
for name in names:
    source = root / f'godot/scripts/verify_{name}.gd'
    command = [str(godot), '--headless', '--path', str(root / 'godot'), '--script',
               f'res://scripts/verify_{name}.gd']
    if '--rules-only' in source.read_text():
        command += ['--', '--rules-only']
    start = time.monotonic()
    run = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=120)
    log = run.stdout + run.stderr
    (out / f'regression-{name}.log').write_text(log)
    ok = (run.returncode == 0 and not any(marker in log for marker in ('SCRIPT ERROR', 'ERROR:', '_FAIL '))
          and ('_OK' in log or 'failures=0' in log or 'FAILURES 0' in log))
    results.append({'name': name, 'ok': ok, 'exitCode': run.returncode,
                    'seconds': round(time.monotonic() - start, 2)})
    print(f'{name}: {"OK" if ok else "FAIL"}', flush=True)
(out / 'regressions.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
if not all(item['ok'] for item in results):
    raise SystemExit(1)
