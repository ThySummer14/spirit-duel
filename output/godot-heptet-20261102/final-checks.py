from pathlib import Path
import subprocess,concurrent.futures,json,re
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent/'final-rules';binary=root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot'
names=['verify_arakawa','verify_zhenjian_duel','verify_ape_sleeve','verify_rednight_walnut','verify_ability_sources','verify_heptet_cross']
def run(name):
 args=['--rules-only'] if name in ['verify_zhenjian_duel','verify_rednight_walnut'] else []
 cmd=[str(binary),'--headless','--path',str(root/'godot'),'--script','res://scripts/'+name+'.gd']+(['--']+args if args else [])
 r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60);(out/(name+'.log')).write_text(r.stdout)
 return dict(name=name,status=r.returncode,errors=bool(re.search(r'(?:SCRIPT )?ERROR:',r.stdout)),summary=r.stdout.strip().splitlines()[-1:])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:results=list(ex.map(run,names))
(Path(__file__).parent/'final-rules.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,ensure_ascii=False,indent=2));raise SystemExit(int(any(r['status'] or r['errors'] for r in results)))
