from pathlib import Path
from PIL import Image
import colorsys, json, re
root=Path.cwd();folder=root/'art-reference-official/卡面-按版本/09_四相琉璃'
templates={k:next(folder.glob(f'{n}_*/{n}00_*.png')) for k,n in [('红莲',204),('紫岩',205),('苍叶',206),('青岚',207)]}
def color(x):
 r,g,b=x;h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
 if s<.22 or v<.28:return ''
 if h<.06 or h>.96:return '红莲'
 if .2<h<.43:return '苍叶'
 if .51<h<.66:return '青岚'
 if .69<h<.85:return '紫岩'
 return ''
coords={}
for k,p in templates.items():
 im=Image.open(p).convert('RGB');coords[k]=[(x,y) for y in range(314,352) for x in range(142,191) if color(im.getpixel((x,y)))==k];print(k,len(coords[k]))
raw=json.load(open(root/'godot/content/content.json'));units={str(u.get('officialRole')):u['id'] for u in raw['units'] if u.get('officialRole')};out=[]
for p in (root/'art-reference-official/卡面-按版本').rglob('*.png'):
 m=re.match(r'^(\d+)00_.*_式神\.png$',p.name)
 if not m or m[1] not in units:continue
 im=Image.open(p).convert('RGB');scores={}
 for k,cs in coords.items():scores[k]=sum(color(im.getpixel(c))==k for c in cs)/len(cs)
 ordered=sorted(scores,key=scores.get,reverse=True)
 out.append({'id':units[m[1]],'role':m[1],'path':str(p.relative_to(root)),'faction':ordered[0],'scores':scores,'margin':scores[ordered[0]]-scores[ordered[1]]})
out.sort(key=lambda x:x['margin']);(root/'output/godot-mianqiling-20261028/faction-raw.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
for x in out[:55]:print(x['id'],x['faction'],'margin',round(x['margin'],2),'scores',str({k:round(v,2) for k,v in x['scores'].items()}))
print('count',len(out),'low<.2',sum(x['margin']<.2 for x in out))
