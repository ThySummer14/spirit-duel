from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent;errors=[];checks=0
base=json.loads((out/'before-hashes.json').read_text());oldtests={k:v for k,v in base.items() if Path(k).name.startswith('verify_') and k.endswith('.gd')}
for name,h in oldtests.items():
 checks+=1
 if hashlib.sha256((root/name).read_bytes()).hexdigest()!=h:errors.append('old verification changed: '+name)
overlay=json.loads((root/'godot/content/verified_rules.json').read_text());counts={'units':0,'cards':0};art=[]
for group in ['cooking-core','sugar-cat','rabbit-tide']:
 folder=root/f'output/godot-{group}-20261103';patch=json.loads((folder/'overlay.json').read_text())
 for kind in ['units','cards']:
  for id,props in patch[kind].items():
   counts[kind]+=1
   for key,value in props.items():
    checks+=1
    if overlay[kind].get(id,{}).get(key)!=value:errors.append('overlay mismatch '+id+'.'+key)
 for item in json.loads((folder/'card-art-manifest.json').read_text()):
  for location in ['source','target']:
   checks+=1
   if hashlib.sha256((root/item[location]).read_bytes()).hexdigest()!=item['sha256']:errors.append('art mismatch '+item[location])
  art.append(item)
derivatives=json.loads((root/'output/godot-sugar-cat-20261103/summon-art-manifest.json').read_text())
spear=json.loads((root/'output/godot-rabbit-tide-20261103/derivative-art-evidence.json').read_text())['spear']
derivatives.append({**spear,'source':'output/godot-rabbit-tide-20261103/'+spear['sourceFile']})
for item in derivatives:
 for location in [item['source'],item['target'],item['target'].removeprefix('godot/')]:
  checks+=1
  if hashlib.sha256((root/location).read_bytes()).hexdigest()!=item['sha256']:errors.append('derived art mismatch '+location)
raw={u['id']:u for u in json.loads((root/'godot/content/content.json').read_text())['units']}
for group in ['sugar-cat','rabbit-tide']:
 defs=json.loads((root/f'output/godot-{group}-20261103/new_definitions.json').read_text())
 for u in defs.get('units',[]):
  for key,value in u.items():
   checks+=1
   if raw.get(u['id'],{}).get(key)!=value:errors.append('raw derived unit mismatch '+u['id']+'.'+key)
report={'derivedOriginalArtCount':len(derivatives),'checks':checks,'oldVerifyCount':len(oldtests),'overlayEntries':counts,'originalCardPngCount':len(art),'errors':errors}
(out/'source-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
raise SystemExit(bool(errors))
