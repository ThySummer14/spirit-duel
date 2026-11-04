from pathlib import Path
import json,re,subprocess,hashlib
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
raw={int(x['id']):x for x in json.loads((root/'research-data/cards.json').read_text())}
js=(out/'official-index.js').read_text();items=[]
for n in range(28700,28709):
 m=re.search(r'\{id:'+str(n)+r',.*?\}',js);assert m
 code=m.group(0)
 result=subprocess.run(['node','-e','process.stdout.write(JSON.stringify(('+code+')))'],capture_output=True,text=True,check=True)
 official=json.loads(result.stdout);assert official==raw[n],n;items.append(official)
(out/'official-source-evidence.json').write_text(json.dumps({'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','matched':items},ensure_ascii=False,indent=2)+'\n')
art=[]
for p in sorted((root/'art-reference-official/卡面-按版本/17_鸣雷启蛰/287_灵海蝶').glob('*.png')):
 n=int(p.name.split('_')[0])
 if n==28700:continue
 target=root/f'godot/assets/official/cards/c{n}.png';assert p.read_bytes()==target.read_bytes()
 art.append({'source':str(p.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(art,ensure_ascii=False,indent=2)+'\n')
print('OFFICIAL_SOURCE_MATCHES',len(items),'ORIGINAL_PNG',len(art))
