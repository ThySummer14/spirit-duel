from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
log=(out/'final-godot.log').read_text()
assert 'GODOT_VERIFY_ALL_OK' in log,'full Godot suite has not completed'
assert not re.search(r'(?:SCRIPT )?ERROR:|\b(?:failures|FAILURES)=[1-9]|\b\w+_FAIL\b',log),'Godot diagnostic/failure'
names=re.search(r'for check_script in (.*?); do',(root/'scripts/godot-verify.sh').read_text()).group(1).split()
headers=re.findall(r'^== godot (verify\S*) ==$',log,re.M)
assert headers==names,(len(headers),len(names))
native={}
for group in ['fox_suzuka','sun_smoke','movement','tomato_fire','poison_pair','fortune_pair']:
 body=(out/f'verify_{group}_ui-native.log').read_text()
 assert not re.search(r'(?:SCRIPT )?ERROR:|_FAIL\b',body),group
 match=re.search(r'checks=(\d+) failures=(\d+)',body);assert match and match[2]=='0',group
 native[group]=int(match[1])
node=(out/'final-node.log').read_text();assert '# tests 168' in node and '# fail 0' in node
assert '390 checks, 0 errors' in (out/'ui-audit.log').read_text()
assert 'WAVE2_BUILD_SOURCE_HASHES_OK' in (out/'final-pages-build.log').read_text()
for path,h in json.loads((out/'build-source-hashes.json').read_text()).items():assert hashlib.sha256((root/path).read_bytes()).hexdigest()==h,path
report=json.loads((out/'final-rule-fidelity.json').read_text());assert report['fullCatalogRestored'] is False
results={'completedOn':'2026-10-15','godotScripts':len(names),'nativeUiChecks':native,'nativeViewportSizes':[[1280,800],[1600,740]],'nodeTests':168,'uiAuditChecks':390,'webExportMiB':89.7,'gameSourcesMatchExport':True,'fullCatalogRestored':False,'remainingUnitEntries':250-report['summary']['units']['source-backed-native'],'remainingCards':2114-report['summary']['cards']['source-backed-native'],'fidelitySummary':report['summary'],'auditErrors':report['errors']}
(out/'validation.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('WAVE2_ACCEPTANCE_OK',json.dumps(results,ensure_ascii=False))
