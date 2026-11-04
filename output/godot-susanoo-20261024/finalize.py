from pathlib import Path
import json,hashlib,subprocess,difflib
root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
hashes=json.loads((out/'build-source-hashes.json').read_text())
for name,h in hashes.items():
 p=root/name;q=root/'.build/godot-web-src'/p.relative_to(root/'godot')
 assert hashlib.sha256(p.read_bytes()).hexdigest()==h and hashlib.sha256(q.read_bytes()).hexdigest()==h,name
site=root/'.build/pages';entry={n:(site/'play'/n).is_file() for n in ['index.html','index.js','index.wasm','index.pck']};assert all(entry.values())
(out/'build-validation.json').write_text(json.dumps({'hashCount':len(hashes),'sourceHashesMatch':True,'pagesBytes':sum(p.stat().st_size for p in site.rglob('*') if p.is_file()),'entryFiles':entry},indent=2)+'\n')
changed=[];diff=[]
for old in sorted((out/'before').rglob('*')):
 if not old.is_file():continue
 relative=old.relative_to(out/'before');p=root/relative
 if old.read_bytes()==p.read_bytes():continue
 changed.append(str(relative));diff.extend(difflib.unified_diff(old.read_text().splitlines(True),p.read_text().splitlines(True),fromfile='before/'+str(relative),tofile='after/'+str(relative)))
for relative in ['godot/scripts/susanoo_rules.gd','godot/scripts/susanoo_rules.gd.uid','godot/scripts/verify_susanoo.gd','godot/scripts/verify_susanoo.gd.uid','research-notes/75-susanoo-rules.md']:
 p=root/relative;changed.append(relative);diff.extend(difflib.unified_diff([],p.read_text().splitlines(True),fromfile='/dev/null',tofile='after/'+relative))
changed+=['godot/assets/official/cards/c281%02d.png'%n for n in range(1,9)]
(out/'changed-files.json').write_text(json.dumps(changed,ensure_ascii=False,indent=2)+'\n');(out/'continuation.diff').write_text(''.join(diff))
trailing=[]
for name in changed:
 if name.endswith('.png'):continue
 for n,line in enumerate((root/name).read_text().splitlines(),1):
  if line.rstrip()!=line:trailing.append(name+':'+str(n))
r=subprocess.run(['git','diff','--check'],cwd=root,capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
assert not trailing,trailing
rules=(out/'rules.log').read_text();native=(out/'native.log').read_text();assert 'SUSANOO_OK checks=107 failures=0 rules_only=true' in rules;assert 'SUSANOO_OK checks=121 failures=0 rules_only=false' in native
for name in ['rules.log','native.log','build.log','import.log','export.log']:
 s=(out/name).read_text();assert not any(q in s for q in ['SCRIPT ERROR','ERROR:','_FAIL ']),name
regs=json.loads((out/'regressions/results.json').read_text());assert len(regs)==16 and all(x['ok'] for x in regs)
for row in regs:
 s=(out/'regressions'/('verify_'+row['name']+'.log')).read_text();assert not any(q in s for q in ['SCRIPT ERROR','ERROR:','_FAIL ']),row['name']
audit=json.loads((out/'audit-comparison.json').read_text());evidence=json.loads((out/'official-source-evidence.json').read_text());assert audit['errorsUnchanged'] and evidence['allNineMatchLocalSnapshot']
manifest=json.loads((out/'card-art-manifest.json').read_text());assert len(manifest['newMainFaces'])==8
for row in manifest['newMainFaces']:
 assert hashlib.sha256((root/row['source']).read_bytes()).hexdigest()==row['sha256']==hashlib.sha256((root/row['destination']).read_bytes()).hexdigest()
lethal=json.loads((out/'lethal-regression-comparison.json').read_text());assert lethal['sameExistingTestBytes'] and lethal['baselineLightHealerFailed'] and lethal['before']['energy']==1 and lethal['after']['energy']==2 and lethal['after']['hp']==5
result={'gitDiffCheck':True,'batchTrailingWhitespace':trailing,'textFiles':len(changed)-8,'originalPNGs':8,'cumulativeOriginalPNGs':459,'buildHashCount':len(hashes),'sourceAndBuildHashesMatch':True,'pureRuleChecks':107,'nativeChecksIncludingRules':121,'relatedRegressionGroups':len(regs),'auditExitCode':1,'fullCatalogRestored':False,'auditDiagnosticsUnchanged':19,'officialSnapshotFieldsMatched':9}
(out/'final-validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False))
