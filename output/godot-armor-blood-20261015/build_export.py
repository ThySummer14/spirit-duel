from pathlib import Path
import hashlib,importlib.util,json,os
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('armor_blood_pages',root/'scripts/build-pages.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.BUILD=root/'.build/armor-blood-20261015';m.PROJECT=m.BUILD/'godot-web-src';m.SITE=m.BUILD/'pages'
os.environ['GODOT_BIN']='/tmp/kuangye-godot-tools/godot-macos/Godot.app/Contents/MacOS/Godot'
os.environ['GODOT_WEB_TEMPLATE']=str(root/'.build/tools/web_nothreads_release.zip')
# The cold import has previously hit an engine font-import crash. Use Godot's
# documented single-threaded scene import on this disposable copy only.
original=m.run_godot
def run(binary,phase,*args):
 if phase=='import':args=(*args,'--single-threaded-scene')
 return original(binary,phase,*args)
m.run_godot=run
paths=sorted((root/'godot').rglob('*.gd'))+[root/'godot/content/verified_rules.json',root/'godot/content/content.json']
hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
m.main()
for path,h in hashes.items():
 assert hashlib.sha256((root/path).read_bytes()).hexdigest()==h,path
 assert hashlib.sha256((m.PROJECT/Path(path).relative_to('godot')).read_bytes()).hexdigest()==h,path
(out/'build-source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
print('ARMOR_BLOOD_BUILD_SOURCE_HASHES_OK')
