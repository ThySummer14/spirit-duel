from pathlib import Path
import hashlib,json,re,struct,subprocess
root=Path(__file__).resolve().parents[2]; out=Path(__file__).resolve().parent
checks=[]
def verify(ok,label):
 checks.append({'check':label,'passed':bool(ok)})
 if not ok: raise AssertionError(label)
log=(out/'full-godot.log').read_text()
verify(json.loads((out/'suite-exit.json').read_text())['exitCode']==0,'Godot suite exit0')
verify('GODOT_VERIFY_ALL_OK' in log and not re.search(r'(?:SCRIPT )?ERROR:|\bFAIL ',log),'full suite completed without error diagnostics')
expected=re.search(r'for check_script in (.*?); do',(root/'scripts/godot-verify.sh').read_text()).group(1).split()
actual=re.findall(r'^== godot (verify\w*) ==$',log,re.M)
verify(actual==expected and len(actual)==90,'all90 configured scripts ran in order')
verify('INSTANT_FEEDBACK_UI checks=60 failures=0' in log,'new feedback checks passed in full suite')
verify('PLAYTEST matches=60 completed=60' in log and 'FOCUS rounds=20 completed=20' in log and 'stalls=0' in log,'random60 and focused20 completed')
verify('covered=250' in log and 'matches=63' in log,'roster250 covered')
ui=(out/'native-ui-final.log').read_text()
verify('INSTANT_FEEDBACK_UI checks=60 failures=0' in ui and not re.search(r'ERROR:|WARNING:|FAIL ',ui),'native real mouse60 passed')
for width,height in [(1280,800),(1600,740)]:
 for suffix in ['01-instant-payment','02-instant-extra-cost','03-opponent-instant-response']:
  b=(out/'screenshots'/f'{width}-{suffix}.png').read_bytes()
  verify(b[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',b[16:24])==(width,height),'native screenshot '+str(width)+' '+suffix)
node=(out/'node-test.log').read_text()
verify('# pass 168' in node and '# fail 0' in node,'Node168 passed')
verify('390 checks, 0 errors' in (out/'ui-audit.log').read_text(),'UI audit390 passed')
audit=json.loads((out/'rule-fidelity.json').read_text()); prior=json.loads((root/'output/godot-huang-20261015/rule-fidelity.json').read_text())
verify(not audit['fullCatalogRestored'] and audit['errors']==prior['errors'] and audit['summary']==prior['summary'],'strict fidelity audit remains incomplete and unchanged')
h=json.loads((out/'suite-source-hashes.json').read_text()); b=json.loads((out/'build-source-hashes.json').read_text())
verify(h==b,'suite and exported sources identical')
verify(all(hashlib.sha256((root/p).read_bytes()).hexdigest()==d for p,d in h.items()),'source unchanged during validation')
verify('INSTANT_BUILD_SOURCE_HASHES_OK' in (out/'build-final.log').read_text(),'stable4.6.3 Web build and3 focused checks passed')
for name in ['index.html','index.js','index.pck','index.wasm']:
 verify((root/'.build/instant-feedback-20261016/pages/play'/name).is_file(),'Web artifact '+name)
verify('Errors: 0, Warnings: 0' in (out/'browser-console.log').read_text(),'game browser console clean')
for name in ['boot','opening','battle']:
 verify((root/f'output/playwright/instant-feedback-20261016-{name}.png').stat().st_size>10000,'browser '+name+' displayed')
movie=out/'instant-feedback.mp4'
meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration,size:stream=codec_name,width,height','-of','json',str(movie)]))
verify(7<float(meta['format']['duration'])<9 and meta['streams'][0]['width']==1600 and meta['streams'][0]['height']==740,'native movie duration and dimensions')
r=subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(movie),'-f','null','-'],capture_output=True,text=True)
verify(r.returncode==0 and not r.stderr,'movie fully decodes')
verify('INSTANT_MOTION checks=2 failures=0' in (out/'motion-demo.log').read_text(),'movie capture exercised both real payments')
media=(out/'video-browser-final.log').read_text()
played=json.loads(re.search(r'### Result\n(\{[^\n]*\})',media).group(1))
verify(played['error'] is None and not played['paused'] and played['currentTime']>1,'movie plays in browser without media error')
verify('Errors: 0, Warnings: 0' in (out/'video-console.log').read_text(),'isolated video browser console clean')
result={'passed':True,'checks':checks,'godotScripts':len(actual),'nativeChecks':60,'sourceFiles':len(h),'audit':audit['summary'],'auditDiagnostics':len(audit['errors']),'movie':meta,'movieSHA256':hashlib.sha256(movie.read_bytes()).hexdigest()}
(out/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('INSTANT_FEEDBACK_ACCEPTANCE_OK',len(checks),'checks')
