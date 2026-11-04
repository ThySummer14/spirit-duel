from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
bad=r'(?:SCRIPT )?ERROR:|\b(?:failures|FAILURES)=[1-9]|\b\w+_FAIL\b'
def clean(path):
 text=path.read_text();assert not re.search(bad,text),str(path)
 return text
def count(path):
 s=clean(path);match=re.search(r'checks=(\d+) failures=0',s);assert match,str(path)
 return int(match[1])
log=clean(out/'final-godot.log');assert 'GODOT_VERIFY_ALL_OK' in log
assert (out/'godot-exit.txt').read_text().strip()=='0'
assert json.loads((out/'suite-sources-changed.json').read_text())==[]
names=re.search(r'for check_script in (.*?); do',(root/'scripts/godot-verify.sh').read_text()).group(1).split()
assert re.findall(r'^== godot (verify\S*) ==$',log,re.M)==names
for key in ['suite-source-hashes.json','build-source-hashes.json']:
 for path,digest in json.loads((out/key).read_text()).items(): assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,path
node=(out/'node.log').read_text();assert '# tests 168' in node and '# fail 0' in node
assert '390 checks, 0 errors' in (out/'ui-audit.log').read_text()
audit=json.loads((out/'rule-fidelity.json').read_text());assert audit['fullCatalogRestored'] is False
assert (out/'audit-exit.txt').read_text().strip()=='1'
assert (out/'all-cards-ui-native-exit.txt').read_text().strip()=='0'
assert 'ARMOR_BLOOD_BUILD_SOURCE_HASHES_OK' in clean(out/'final-pages-build.log')
for name in ['index.html','index.js','index.pck','index.wasm']:assert (root/'.build/armor-blood-20261015/pages/play'/name).is_file()
for physical in [1280,1600]:
 for scene in ['01-bone-shield','02-blood-transfer','03-moon-recovery','04-realm-inspector']:assert (out/f'screenshots/{physical}-{scene}.png').is_file()
result={'completedOn':'2026-10-15','godotScripts':len(names),'focusedRules':count(out/'focused.log'),'continuationRules':count(out/'continuation.log'),'nativeUi':{'armorBlood':count(out/'ui-native.log'),'lightHealer':count(out/'light-ui-native.log'),'allCards':count(out/'all-cards-ui-native.log')},'nativeViewportSizes':[[1280,800],[1600,740]],'nodeTests':168,'uiAuditChecks':390,'frozenSuiteSources':True,'gameSourcesMatchExport':True,'webVersion':'4.6.3.stable','fidelitySummary':audit['summary'],'auditErrors':audit['errors'],'fullCatalogRestored':False,'remainingUnitEntries':sum(audit['summary']['units'].values())-audit['summary']['units']['source-backed-native'],'remainingCards':sum(audit['summary']['cards'].values())-audit['summary']['cards']['source-backed-native'],'allCardsUiScriptSha256':hashlib.sha256((out/'all_cards_ui.gd').read_bytes()).hexdigest()}
for name,expected in [('verify-armor-blood',result['focusedRules']),('verify-armor-blood-continuation',result['continuationRules'])]:assert count(root/f'.build/armor-blood-20261015/pages-{name}.log')==expected
result['webExportBytes']=sum(p.stat().st_size for p in (root/'.build/armor-blood-20261015/pages').rglob('*') if p.is_file())
(out/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('ARMOR_BLOOD_ACCEPTANCE_OK',json.dumps(result,ensure_ascii=False))
