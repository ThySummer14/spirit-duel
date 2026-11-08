from pathlib import Path
import importlib.util,os,hashlib,json
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('build_pages',root/'scripts/build-pages.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
build.BUILD=root/'.build/completion-drive-20261104';build.PROJECT=build.BUILD/'godot-web-src';build.SITE=build.BUILD/'pages'
os.environ['GODOT_BIN']=str(root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot');os.environ['GODOT_WEB_TEMPLATE']=str(root/'.build/tools/web_nothreads_release.zip')
paths=list((root/'godot/scripts').rglob('*.gd'))+list((root/'godot/content').glob('*.json'))+[p for p in (root/'godot/assets/official').rglob('*') if p.is_file() and p.suffix.lower() in {'.png','.jpg','.jpeg'}]
hashes={str(p.relative_to(root/'godot')):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
build.main()
errors=[]
for k,h in hashes.items():
 if hashlib.sha256((root/'godot'/k).read_bytes()).hexdigest()!=h:errors.append('source changed during build: '+k)
 if hashlib.sha256((build.PROJECT/k).read_bytes()).hexdigest()!=h:errors.append('build copy mismatch: '+k)
report={'count':len(hashes),'errors':errors,'hashes':hashes}
(Path(__file__).parent/'build-source-hashes.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
assert not errors,errors
print('COMPLETION_DRIVE_BUILD_SOURCE_MATCH',len(hashes))
