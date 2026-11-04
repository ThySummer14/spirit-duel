from pathlib import Path
import subprocess,json,time
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent/'regressions';out.mkdir(exist_ok=True)
names=['combat','growth','resource_effects','turn_order','rebirth','fortune_pair','light_healer','moon_bamboo','whale','crocodile','armor_blood','classic_core','battle_status','ghost_mountain_maple','spider_lily','onikiri']
results=[]
for name in names:
 source=root/f'godot/scripts/verify_{name}.gd';cmd=[str(root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot'),'--headless','--path',str(root/'godot'),'--script',f'res://scripts/verify_{name}.gd']
 if '--rules-only' in source.read_text():cmd+=['--','--rules-only']
 began=time.monotonic();r=subprocess.run(cmd,cwd=root,capture_output=True,text=True,timeout=120);s=r.stdout+r.stderr;(out/f'verify_{name}.log').write_text(s)
 ok=r.returncode==0 and not any(x in s for x in ['SCRIPT ERROR','ERROR:','_FAIL ']) and ('_OK' in s or 'failures=0' in s)
 results.append({'name':name,'exitCode':r.returncode,'ok':ok,'seconds':round(time.monotonic()-began,2)});print(name,ok,flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(x['ok'] for x in results)
