from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,json,re
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent/'regressions';out.mkdir(exist_ok=True)
# Shared payment, neutral/source-specific spell events, summon lifecycle, growth/reset and turn hooks.
names=['classic_core','combat','instant','peach','phoenix','monk_cleaner','tree_sakura','bond_dream','pipe_fox','koi_fragrance','weaver','fusion_trio','movement_continuation','armor_blood','sun_smoke','growth','turn_order','rebirth','susanoo','fox_lotus','cooking_core','sugar_cat','rabbit_tide','food_cross','blue_green','zhenjian_duel','black_white','whale']
def run(name):
 cmd=[str(root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot'),'--headless','--path',str(root/'godot'),'--script',f'res://scripts/verify_{name}.gd']+(['--','--rules-only'] if '--rules-only' in (root/f'godot/scripts/verify_{name}.gd').read_text() else [])
 r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
 (out/f'{name}.log').write_text(r.stdout)
 passed=r.returncode==0 and not re.search(r'(?:SCRIPT )?ERROR:|(?:^|_)FAIL(?:ED)? ',r.stdout,re.M) and bool(re.search(r'(?:OK|PASS|failures[=\": ]+0|FAILURES 0)',r.stdout))
 return {'name':name,'returncode':r.returncode,'passed':passed,'summary':[s for s in r.stdout.splitlines() if re.search('OK|PASS|FAIL|ERROR:',s)]}
import sys
selected=sys.argv[1:] or names
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,selected))
(out/('rerun-results.json' if selected!=names else 'results.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
for r in results:print(r['name'],r['passed'],'; '.join(r['summary'])[:250],flush=True)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
