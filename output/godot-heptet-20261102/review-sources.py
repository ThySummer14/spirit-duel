from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent
v=json.loads((root/'godot/content/verified_rules.json').read_text());before=json.loads((out/'before-hashes.json').read_text());bad=[];manifests=[];scope={}
for name in ['zhenjian-duel','rednight-walnut','ape-sleeve','arakawa']:
 f=root/f'output/godot-{name}-20261102';o=json.loads((f/'overlay.json').read_text());scope[name]={k:len(o[k]) for k in ['units','cards']}
 for k in ['units','cards']:
  for id,data in o[k].items():
   if v[k].get(id)!=data:bad.append('overlay mismatch '+id)
 for m in json.loads((f/'card-art-manifest.json').read_text()):
  p=root/m['source'];q=root/m['target'];digest=lambda t:hashlib.sha256(t.read_bytes()).hexdigest()
  ok=p.exists() and q.exists() and digest(p)==digest(q)==m['sha256']
  manifests.append({**m,'matches':ok})
  if not ok:bad.append('card art mismatch '+str(q))
oldtests={k:h for k,h in before.items() if Path(k).name.startswith('verify_') and k.endswith('.gd')};changed=[]
for k,h in oldtests.items():
 p=root/k
 if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=h:changed.append(k)
if changed:bad+=changed
report={'scope':scope,'mainCardArtCount':len(manifests),'cardArt':manifests,'unchangedExistingVerifications':len(oldtests)-len(changed),'changedExistingVerifications':changed,'errors':bad}
(out/'source-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='cardArt'},ensure_ascii=False));raise SystemExit(bool(bad))
