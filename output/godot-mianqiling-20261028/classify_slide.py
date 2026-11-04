from pathlib import Path
from PIL import Image
import cv2,numpy as np, json,re,collections
root=Path.cwd();folder=root/'art-reference-official/卡面-按版本/09_四相琉璃'
refs={k:next(folder.glob(f'{n}_*/{n}00_*.png')) for k,n in [('红莲',204),('紫岩',205),('苍叶',206),('青岚',207)]}
def masks(im):
 a=np.array(im.convert('RGB')); h,s,v=cv2.split(cv2.cvtColor(a,cv2.COLOR_RGB2HSV));valid=(s>56)&(v>70)
 return {'红莲':(valid&((h<11)|(h>173))).astype('float32'),'苍叶':(valid&(h>36)&(h<77)).astype('float32'),'青岚':(valid&(h>91)&(h<119)).astype('float32'),'紫岩':(valid&(h>124)&(h<153)).astype('float32')}
templates={k:masks(Image.open(p))[k][314:352,142:191] for k,p in refs.items()}
raw=json.load(open(root/'godot/content/content.json'));units=collections.defaultdict(list)
for u in raw['units']:
 if u.get('officialRole'):units[str(u['officialRole'])].append(u['id'])
out=[]
for p in (root/'art-reference-official/卡面-按版本').rglob('*.png'):
 m=re.match(r'^(\d+)00_.*_式神\.png$',p.name)
 if not m or m[1] not in units:continue
 im=Image.open(p); maps=masks(im);w,h=im.size;scores={};positions={}
 for k,template in templates.items():
  region=maps[k][270:min(h,410),max(0,int(w/2)-55):min(w,int(w/2)+55)]
  res=cv2.matchTemplate(region,template,cv2.TM_CCORR_NORMED);_,v,_,xy=cv2.minMaxLoc(res);scores[k]=v;positions[k]=xy
 ordered=sorted(scores,key=scores.get,reverse=True)
 for id in units[m[1]]:out.append({'id':id,'role':m[1],'path':str(p.relative_to(root)),'faction':ordered[0],'scores':scores,'margin':scores[ordered[0]]-scores[ordered[1]],'xy':positions[ordered[0]]})
out.sort(key=lambda x:x['margin']);(root/'output/godot-mianqiling-20261028/faction-slide.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
for x in out[:65]:print(x['id'],x['faction'],'max',round(x['scores'][x['faction']],2),'margin',round(x['margin'],2),'scores',str({k:round(v,2) for k,v in x['scores'].items()}))
print('count',len(out),'low<.1',sum(x['margin']<.1 for x in out))
