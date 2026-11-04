from pathlib import Path
import json,hashlib,subprocess,difflib
r=Path(__file__).resolve().parents[2];o=Path(__file__).resolve().parent;b=r/'output/godot-futakuchi-20261028';before=json.loads((b/'before-hashes.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
oldtests={k:h for k,h in before.items() if Path(k).name.startswith('verify_') and k.endswith('.gd')}
changedtests=[k for k,h in oldtests.items() if not (r/k).is_file() or sha(r/k)!=h]
(o/'regression-test-integrity.json').write_text(json.dumps({'existingTests':len(oldtests),'changed':changedtests,'ok':not changedtests},indent=2)+'\n');assert not changedtests
assert sha(r/'godot/content/content.json')==before['godot/content/content.json']
v=json.loads((r/'godot/content/verified_rules.json').read_text());old=json.loads((b/'before/godot/content/verified_rules.json').read_text());roles={'erkounv','liangmianfo','xiazhongshaonv','heitongzi','baitongzi'};cards={f'c{n*100+i}' for n in [295,238,243,240,241] for i in range(1,9)}
for group,allowed in [('units',roles),('cards',cards)]:
 for key,val in old[group].items():
  if key not in allowed:assert v[group][key]==val,(group,key)
 for key in set(v[group])-set(old[group]):assert key in allowed,(group,key)
for x in old['sources']:assert x in v['sources']
art=[]
for cid in sorted(cards):
 p=r/f'godot/assets/official/cards/{cid}.png';srcs=list((r/'art-reference-official/卡面-按版本').rglob(cid[1:]+'_*.png'));assert srcs and any(s.read_bytes()==p.read_bytes() for s in srcs),cid
 art.append({'cardId':cid,'sha256':sha(p)})
(o/'card-art-manifest.json').write_text(json.dumps({'newCards':art,'totalPNG':len(list((r/'godot/assets/official/cards').glob('*.png')))},indent=2)+'\n')
paths={r/k for k in before}
paths.update((r/'godot/scripts').rglob('*.gd'));paths.update((r/'godot/scripts').rglob('*.uid'))
paths.update(r/f'godot/assets/official/cards/{cid}.png' for cid in cards)
paths.update(r/'research-notes'/name for name in ['81-futakuchi-rules.md','82-black-white-rules.md','83-two-faces-rules.md','84-box-maiden-rules.md'])
changed=[];diff=[];whitespace=[]
for p in sorted(paths):
 if not p.is_file():continue
 rel=str(p.relative_to(r));h=sha(p)
 if before.get(rel)==h:continue
 changed.append({'path':rel,'before':before.get(rel),'after':h})
 if p.suffix in ['.gd','.json','.md','.sh']:
  new=p.read_text();prior=(b/'before'/rel).read_text() if (b/'before'/rel).is_file() else ''
  diff.extend(difflib.unified_diff(prior.splitlines(True),new.splitlines(True),fromfile='before/'+rel,tofile='after/'+rel))
  for i,line in enumerate(new.splitlines(),1):
   if line.rstrip()!=line:whitespace.append(f'{rel}:{i}')
(o/'changed-files.json').write_text(json.dumps(changed,ensure_ascii=False,indent=2)+'\n');(o/'continuation.diff').write_text(''.join(diff))
d=subprocess.run(['git','diff','--check'],cwd=r,capture_output=True,text=True);(o/'diff-check.log').write_text(d.stdout+d.stderr);assert d.returncode==0;assert not whitespace,whitespace
result=subprocess.run(['npm','run','audit:rules','--','--out',str(o/'audit.json')],cwd=r,capture_output=True,text=True);(o/'audit.log').write_text(result.stdout+result.stderr);(o/'audit-exit.json').write_text(json.dumps({'exitCode':result.returncode},indent=2)+'\n')
audit=json.loads((o/'audit.json').read_text());previous=json.loads((r/'output/godot-lantern-20261027/audit.json').read_text());comparison={'before':previous['summary'],'after':audit['summary'],'errorsUnchanged':previous['errors']==audit['errors'],'errorCount':len(audit['errors'])};(o/'audit-comparison.json').write_text(json.dumps(comparison,ensure_ascii=False,indent=2)+'\n');assert result.returncode==1 and not audit['fullCatalogRestored'];assert comparison['errorsUnchanged']
print(json.dumps({'existingTestsUnchanged':len(oldtests),'newCards':len(cards),'changedFiles':len(changed),'audit':comparison},ensure_ascii=False,indent=2))
