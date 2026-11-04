from pathlib import Path
import hashlib,json,shutil,subprocess
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
name='godot/scripts/verify_toxic_pair.gd';p=root/name;q=root/'.build/godot-web-src/scripts/verify_toxic_pair.gd'
old=p.read_text();new='\n'.join(line.rstrip() for line in old.splitlines())+'\n';assert old.split()==new.split();p.write_text(new)
hashes=json.loads((out/'build-source-hashes.json').read_text());changed=[key for key,h in hashes.items() if hashlib.sha256((root/key).read_bytes()).hexdigest()!=h];assert changed==[name],changed
assert q.read_text()==old;shutil.copyfile(p,q)
r=subprocess.run([str(root/'.build/tools/godot-4.6.3.app/Contents/MacOS/Godot'),'--headless','--path',str(root/'.build/godot-web-src'),'--export-release','Web',str(root/'.build/pages/play/index.html')],capture_output=True,text=True);log=r.stdout+r.stderr;(out/'export.log').write_text(log);assert r.returncode==0 and not any(x in log for x in ['SCRIPT ERROR','ERROR:']),log[-2000:]
for key in hashes:
 a=root/key;b=root/'.build/godot-web-src'/a.relative_to(root/'godot');h=hashlib.sha256(a.read_bytes()).hexdigest();assert hashlib.sha256(b.read_bytes()).hexdigest()==h,key;hashes[key]=h
(out/'build-source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
p=out/'build-phase-results.json';rs=json.loads(p.read_text());rs.append({'phase':'incremental-export-after-verification-whitespace','exitCode':r.returncode});p.write_text(json.dumps(rs,indent=2)+'\n')
with (out/'build.log').open('a') as f:f.write('Verification-script blank-line whitespace removed; incremental Web export: OK.\nTOXIC_PAIR_BUILD_SOURCE_HASHES_OK\n')
print('WHITESPACE_ONLY_INCREMENTAL_EXPORT_OK',len(hashes))
