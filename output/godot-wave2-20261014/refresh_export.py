"""Refresh only this task's disposable Godot 4.6.3 Web build."""
from pathlib import Path
import hashlib,importlib.util,json,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('wave2_pages',root/'scripts/build-pages.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.BUILD=root/'.build/wave2-20261014';m.PROJECT=m.BUILD/'godot-web-src';m.SITE=m.BUILD/'pages'
assert m.PROJECT.is_dir() and m.SITE.is_dir(),'initial build required'
paths=sorted((root/'godot').rglob('*.gd'))+[root/'godot/content/verified_rules.json',root/'godot/content/content.json']
hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
for path,h in hashes.items():
 src=root/path;dst=m.PROJECT/Path(path).relative_to('godot')
 if not dst.exists() or hashlib.sha256(dst.read_bytes()).hexdigest()!=h:shutil.copy2(src,dst)
binary='/tmp/kuangye-godot-tools/godot-macos/Godot.app/Contents/MacOS/Godot'
m.run_godot(binary,'import-final','--editor','--import','--single-threaded-scene')
m.run_godot(binary,'export','--export-release','Web',str(m.SITE/'play/index.html'))
for name in ('index.html','index.js','index.wasm','index.pck'):assert (m.SITE/'play'/name).is_file(),name
for path,h in hashes.items():assert hashlib.sha256((root/path).read_bytes()).hexdigest()==h,path
(out/'build-source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
size=sum(p.stat().st_size for p in m.SITE.rglob('*') if p.is_file());print(f'PAGES_BUILD_OK size={size/1024/1024:.1f}MiB');print('WAVE2_BUILD_SOURCE_HASHES_OK')
