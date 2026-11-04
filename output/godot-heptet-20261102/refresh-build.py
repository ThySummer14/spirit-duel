from pathlib import Path
import hashlib,importlib.util,json,os,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent
spec=importlib.util.spec_from_file_location('build_pages',root/'scripts/build-pages.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
build.BUILD=root/'.build/heptet-20261102';build.PROJECT=build.BUILD/'godot-web-src';build.SITE=build.BUILD/'pages'
binary=str(root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot')
prior=json.loads((out/'build-source-hashes.json').read_text());shutil.copy2(out/'build-source-hashes.json',out/'build-source-hashes-initial.json')
paths=list((root/'godot/scripts').rglob('*.gd'))+list((root/'godot/content').glob('*.json'))+list((root/'godot/assets/official/cards').glob('*.png'))
hashes={str(p.relative_to(root/'godot')):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths};updated=[]
for k,h in hashes.items():
 target=build.PROJECT/k
 if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest()!=h:
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/'godot'/k,target);updated.append(k)
print('Incremental source updates:',json.dumps(updated),flush=True)
build.run_godot(binary,'import','--editor','--import')
build.run_godot(binary,'export','--export-release','Web',str(build.SITE/'play/index.html'))
errors=[]
for k,h in hashes.items():
 if hashlib.sha256((root/'godot'/k).read_bytes()).hexdigest()!=h:errors.append('source changed during build: '+k)
 if hashlib.sha256((build.PROJECT/k).read_bytes()).hexdigest()!=h:errors.append('build copy mismatch: '+k)
(out/'build-source-hashes.json').write_text(json.dumps({'count':len(hashes),'updated':updated,'errors':errors,'hashes':hashes},ensure_ascii=False,indent=2)+'\n')
assert not errors,errors
size=sum(p.stat().st_size for p in build.SITE.rglob('*') if p.is_file());print('HEPTET_FINAL_BUILD',len(hashes),'sources',round(size/1024/1024,1),'MiB')
