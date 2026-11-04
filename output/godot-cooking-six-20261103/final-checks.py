from pathlib import Path
import subprocess,concurrent.futures,json,re
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent/'final-rules';out.mkdir(exist_ok=True)
names=['cooking_core','sugar_cat','rabbit_tide','food_cross']
def run(name):
 cmd=[str(root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot'),'--headless','--path',str(root/'godot'),'--script',f'res://scripts/verify_{name}.gd']+(['--','--rules-only'] if name!='food_cross' else [])
 r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90);(out/f'{name}.log').write_text(r.stdout)
 return {'name':name,'status':r.returncode,'errors':bool(re.search(r'(?:SCRIPT )?ERROR:|_FAIL |failures["=: ]+[1-9]',r.stdout)),'summary':r.stdout.strip().splitlines()[-1:]}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:results=list(ex.map(run,names))
(Path(__file__).parent/'final-rules.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n');print(json.dumps(results,ensure_ascii=False,indent=2));raise SystemExit(int(any(x['status'] or x['errors'] for x in results)))
