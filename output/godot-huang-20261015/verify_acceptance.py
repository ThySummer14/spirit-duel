from pathlib import Path
import hashlib,json,re,struct
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
checks=[]
def verify(condition,label):
 checks.append({'check':label,'passed':bool(condition)})
 if not condition:raise AssertionError(label)
log=(out/'full-godot.log').read_text()
verify(json.loads((out/'suite-exit.json').read_text())['exitCode']==0,'Godot suite exit0')
verify('GODOT_VERIFY_ALL_OK' in log and not re.search(r'(?:SCRIPT )?ERROR:|\bFAIL ',log),'Godot full completion and no error diagnostics')
expected=re.search(r'for check_script in (.*?); do',(root/'scripts/godot-verify.sh').read_text()).group(1).split()
actual=re.findall(r'^== godot (verify\w*) ==$',log,re.M)
verify(actual==expected and len(actual)==89,'all89 configured scripts ran in order')
verify(bool(re.search(r'HUANG checks=\d+ failures=0',log)),'Huang rule check passed in suite')
verify('PLAYTEST matches=60 completed=60' in log and 'FOCUS rounds=20 completed=20' in log and 'stalls=0' in log,'random60 and focused20 completed')
verify('covered=250' in log and 'matches=63' in log,'full roster covered')
ui=(out/'ui-native-final.log').read_text()
verify('HUANG_UI checks=50 failures=0' in ui and not re.search(r'ERROR:|WARNING:|FAIL ',ui),'native mouse50 checks passed without diagnostics')
for width,height in [(1280,800),(1600,740)]:
 for suffix in ['01-sea-inspector','02-afterglow-choice','03-moon-durability','04-spiral-swift']:
  b=(out/'screenshots'/f'{width}-{suffix}.png').read_bytes()
  verify(b[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',b[16:24])==(width,height),'native screenshot '+str(width)+' '+suffix)
node=(out/'node-tests.log').read_text();verify('# pass 168' in node and '# fail 0' in node,'Node168 passed')
verify('390 checks, 0 errors' in (out/'ui-audit.log').read_text(),'UI audit390 passed')
audit=json.loads((out/'rule-fidelity.json').read_text());prior=json.loads((root/'output/godot-armor-limit-20261015/rule-fidelity.json').read_text())
verify(audit['fullCatalogRestored'] is False and audit['errors']==prior['errors'],'restoration audit remains incomplete with same19 diagnostics')
verify(len([r for r in audit['rows'] if (r['id']=='huang' or r['id'].startswith('c1780')) and r['status']=='pending-verification'])==9,'Huang plus8 cards remain pending rather than declared complete')
h=json.loads((out/'suite-source-hashes.json').read_text());b=json.loads((out/'build-source-hashes.json').read_text())
verify(h==b,'build and suite use identical source hashes')
changed=[p for p,d in h.items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=d]
verify(not changed,'source unchanged during full validation')
verify('HUANG_BUILD_SOURCE_HASHES_OK' in (out/'build-final.log').read_text(),'stable4.6.3 Web build and focused rules passed')
for name in ['index.html','index.js','index.pck','index.wasm']:verify((root/'.build/huang-20261015/pages/play'/name).is_file(),'Web artifact '+name)
verify('Errors: 0, Warnings: 0' in (out/'browser-console.log').read_text(),'browser console clean')
verify((root/'output/playwright/huang-20261015-battle.png').stat().st_size>10000,'browser actual battle screenshot')
result={'passed':True,'checks':checks,'godotScripts':len(actual),'ruleCheck':re.search(r'HUANG checks=\d+ failures=0',log).group(),'nativeChecks':50,'audit':audit['summary'],'auditDiagnostics':len(audit['errors']),'unchangedSourceFiles':len(h)}
(out/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('HUANG_ACCEPTANCE_OK',len(checks),'checks',result['ruleCheck'])
