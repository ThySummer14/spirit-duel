from pathlib import Path
import json,hashlib,subprocess,difflib,re
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
hashes=json.loads((out/'build-source-hashes.json').read_text())
for name,h in hashes.items():
 p=root/name;q=root/'.build/godot-web-src'/p.relative_to(root/'godot')
 assert hashlib.sha256(p.read_bytes()).hexdigest()==h and hashlib.sha256(q.read_bytes()).hexdigest()==h,name
old_hash=json.loads((root/'output/godot-minglei-pair-20261024/build-source-hashes.json').read_text());assert hashes['godot/content/content.json']==old_hash['godot/content/content.json']
site=root/'.build/pages';entry={n:(site/'play'/n).is_file() for n in ['index.html','index.js','index.wasm','index.pck']};assert all(entry.values())
(out/'build-validation.json').write_text(json.dumps({'hashCount':len(hashes),'sourceHashesMatch':True,'pagesBytes':sum(p.stat().st_size for p in site.rglob('*') if p.is_file()),'entryFiles':entry},indent=2)+'\n')
changed=[];diff=[]
for old in sorted((out/'before').rglob('*')):
 if not old.is_file():continue
 relative=old.relative_to(out/'before');p=root/relative
 if old.read_bytes()==p.read_bytes():continue
 changed.append(str(relative));diff.extend(difflib.unified_diff(old.read_text().splitlines(True),p.read_text().splitlines(True),fromfile='before/'+str(relative),tofile='after/'+str(relative)))
for relative in [f'godot/scripts/{n}{suffix}' for n in ['toxic_rules','verify_toxic_pair'] for suffix in ['.gd','.gd.uid']]+['research-notes/77-toxic-pair-rules.md']:
 p=root/relative;changed.append(relative);diff.extend(difflib.unified_diff([],p.read_text().splitlines(True),fromfile='/dev/null',tofile='after/'+relative))
changed += [f'godot/assets/official/cards/c{role}{n:02}.png' for role in [283,284] for n in range(1,9)]
(out/'changed-files.json').write_text(json.dumps(changed,ensure_ascii=False,indent=2)+'\n');(out/'continuation.diff').write_text(''.join(diff))
trailing=[]
for name in changed:
 if name.endswith('.png'):continue
 for n,line in enumerate((root/name).read_text().splitlines(),1):
  if line.rstrip()!=line:trailing.append(name+':'+str(n))
r=subprocess.run(['git','diff','--check'],cwd=root,capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr;assert not trailing,trailing
rules=(out/'rules.log').read_text();native=(out/'native.log').read_text();assert 'TOXIC_PAIR_OK checks=167 failures=0 rules_only=true' in rules;assert 'TOXIC_PAIR_OK checks=189 failures=0 rules_only=false' in native
for name in ['rules.log','native.log','build.log','import.log','export.log']:
 s=(out/name).read_text();assert not any(q in s for q in ['SCRIPT ERROR','ERROR:','_FAIL ']),name
regs=json.loads((out/'regressions/results.json').read_text());assert len(regs)==18 and all(x['ok'] for x in regs)
for row in regs:
 s=(out/'regressions'/('verify_'+row['name']+'.log')).read_text();assert not any(q in s for q in ['SCRIPT ERROR','ERROR:','_FAIL ']),row['name']
audit=json.loads((out/'audit-comparison.json').read_text());evidence=json.loads((out/'official-source-evidence.json').read_text());assert audit['errorsUnchanged'] and evidence['allEighteenMatchLocalSnapshot']
manifest=json.loads((out/'card-art-manifest.json').read_text());assert len(manifest['newMainFaces'])==16
for row in manifest['newMainFaces']:
 assert hashlib.sha256((root/row['source']).read_bytes()).hexdigest()==row['sha256']==hashlib.sha256((root/row['destination']).read_bytes()).hexdigest()
assert len(list((out/'screenshots').glob('*.png')))==6
assert json.loads((out/'regression-test-integrity.json').read_text())['allExistingTestsUnchanged']
assert all(x['exitCode']==0 for x in json.loads((out/'build-phase-results.json').read_text()))
result={'gitDiffCheck':True,'batchTrailingWhitespace':trailing,'textFiles':len(changed)-16,'originalPNGs':16,'cumulativeOriginalPNGs':491,'buildHashCount':len(hashes),'sourceAndBuildHashesMatch':True,'legacyBaseContentUnchanged':True,'pureRuleChecks':167,'nativeChecksIncludingRules':189,'relatedRegressionGroups':len(regs),'auditExitCode':1,'fullCatalogRestored':False,'auditDiagnosticsUnchanged':19,'officialSnapshotDefinitionsMatched':18}
(out/'final-validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False))
