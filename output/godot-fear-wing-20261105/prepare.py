from pathlib import Path
import json,hashlib,shutil
from PIL import Image
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent
raw=json.loads((root/'research-data/cards.json').read_text())
sources=[{'id':'fear-wing-original-20261105','evidence':'逐图读取本地611完整9 PNG，主体采用本地调整后版本，保留惧刃之风战力翻倍。'},{'id':'fear-wing-official-20231210','url':'https://www.taptap.cn/moment/483022168251173536?group_id=188707','evidence':'官方首曝原图：惧翼瞬发、堆叠2、每层+1战力；恐惧获得战力时造成等量伤害、源气绝移除、不可叠加。'}]
pending=['基础牌文及官方派生原图已接入；指定录像尚未逐牌核验。','惧意蔓延按实体手牌实例使用最多两张，每张堆叠整体生效；目前由玩家选择手中实例，是保留资源差异的实现推断，尚未取得原客户端可手选的证据，不能认定交互已还原。叠加牌先后/不足两张及复杂响应全序仍待原客户端复核。','惧刃之风按本地原PNG战力翻倍实现，未追随其他赛季平衡版；乏力与战力同时存在时翻倍边界待原客户端复核。']
units={'tiannimei':{'verifiedRules':True,'fearWingRules':True,'attack':3,'maxHp':4,'formLifecycle':{},'passive':{'id':'fear-wing','name':'惧翼','text':'己方回合开始时，获得一张「惧翼」。','hooks':[]},'awakenedPassive':{'id':'fear-wing-awake','name':'觉醒·天逆每','text':'己方回合开始时或敌方式神气绝时，获得一张「惧翼」。','hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}}
cards={};manifest=[]
for n in range(1,9):
 cid=f'c611{n:02d}';r=next(c for c in raw if int(c['id'])==61100+n)
 typ={'战斗':'combat','法术':'spell','形态':'form','结界':'realm'}[r['type']]
 if n==3:typ='awakening'
 text=r['desc'].replace('#r','\n')
 for k in ['战力','力量','生命','护甲']:text=text.replace('#['+k+']',k)
 action={1:'fw-combat',2:'fw-tremble',3:'fw-awaken',4:'fw-night',5:'fw-form',6:'fw-combat',7:'fw-all',8:'fw-combat'}[n]
 value={'attack':4,'hp':5,'setBase':True} if n==5 else {'attack':0,'hp':1} if n==3 else 1 if n in [6,8] else 0
 c={'verifiedRules':True,'fearWingRules':True,'type':typ,'typeLabel':{'combat':'战斗牌','spell':'法术牌','form':'形态牌','realm':'结界牌','awakening':'觉醒牌'}[typ],'level':int(r['stage']),'cost':1,'copies':2,'deckLimit':2,'text':text,'officialText':text,'keywords':['swift-card'] if n==8 else [],'tags':[],'timing':'main','responseTo':[],'target':'fw-unfeared' if n in [2,3] else 'auto','effect':action,'value':value,'effects':[{'action':action,'target':'selected' if n in [2,3] else 'source','value':value}],'formRules':{'fearWingPerson':True} if n==5 else {},'formHooks':[],'formAbility':text if typ=='form' else '', 'sources':[s['id'] for s in sources],'verificationPending':pending}
 if typ=='combat':c['combatOption']={'shield':1 if n==6 else 0,'immuneCombat':n==8,'fearDouble':n==6};c['responseAction']='assault'
 if typ=='realm':c['realm']={'hp':5,'nativeRealm':'fear-wing-night','trigger':'native-continuous'}
 cards[cid]=c
 src=next((root/'art-reference-official/卡面-按版本/20_桃源故里/611_天逆每').glob(f'611{n:02d}_*.png'));dst=root/f'godot/assets/official/cards/{cid}.png';dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 manifest.append({'source':str(src.relative_to(root)),'target':str(dst.relative_to(root)),'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
t='瞬发，堆叠（最大2）。使天逆每获得等同于堆叠层数的战力。'
cards['juyi']={'verifiedRules':True,'fearWingRules':True,'unitId':'tiannimei','name':'惧翼','type':'spell','typeLabel':'法术牌','level':1,'cost':1,'copies':0,'deckLimit':0,'starterCopies':0,'token':True,'keywords':['instant','stack'],'text':t,'officialText':t,'target':'fw-wing','timing':'main','responseTo':[],'effect':'fw-wing','value':1,'effects':[{'action':'fw-wing','target':'selected','value':1}],'stackMax':2,'sources':[s['id'] for s in sources],'verificationPending':pending}
# Extract only the two official text derivative panels. Never synthesize or redraw original art.
orig=out/'official-1.jpg'
if orig.exists():
 for cid,box in [('juyi',(98,777,383,907)),('fear-wing-charm',(1180,777,1466,959))]:
  dst=root/f'godot/assets/official/cards/{cid}.png';Image.open(orig).crop(box).save(dst)
  manifest.append({'source':'https://img2-tc.tapimg.com/moment/etag/Fp50CCshQCYNDs_YjN80-4y5RJF8.jpg','sourcePath':str(orig.relative_to(root)),'sourceSha256':hashlib.sha256(orig.read_bytes()).hexdigest(),'crop':box,'target':str(dst.relative_to(root)),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()})
charm={'id':'fear-wing-charm','unitId':'tiannimei','name':'恐惧','type':'spell','typeLabel':'灵咒','level':1,'cost':1,'token':True,'copies':0,'deckLimit':0,'starterCopies':0,'verifiedRules':True,'fearWingRules':True,'text':'当天逆每获得战力时，对所结附的式神造成等量的伤害。当天逆每气绝时，移除此灵咒。（不能叠加）','officialText':'当天逆每获得战力时，对所结附的式神造成等量的伤害。当天逆每气绝时，移除此灵咒。（不能叠加）','effects':[{'action':'fw-attach-charm','target':'selected','value':0}],'effect':'fw-attach-charm','value':0,'keywords':[],'target':'fw-unfeared','sources':[s['id'] for s in sources],'verificationPending':pending}
cards['fear-wing-charm']=charm.copy()
for name,obj in [('overlay.json',{'sources':sources,'units':units,'cards':cards}),('new_definitions.json',{'units':[],'cards':[charm]}),('card-art-manifest.json',manifest)]:(out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print('FEAR_WING_PREPARED main8 token1 charm1')
