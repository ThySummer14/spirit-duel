from pathlib import Path
import json,hashlib,shutil
from PIL import Image
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent
raw=json.loads((root/'research-data/cards.json').read_text());by={int(c['id']):c for c in raw}
sources=[{'id':'sg-original-20261104','path':'art-reference-official/卡面-按版本','evidence':'194/220共18张完整PNG目检；中文主体优先，不采用JP后来1战力神愤或觉醒直接消灭。'}, {'id':'sg-ghost-derivatives','url':'https://gamerch.com/onmyojicard/244805','evidence':'觉醒白3勾+2/+2瞬发不屈、倒计时1、每回合一次受伤自动索魂投射等额伤害。'}, {'id':'sg-white-body','url':'https://gamerch.com/onmyojicard/243525','evidence':'鬼使白2/6、倒计时2切黑。'}, {'id':'sg-snake-body','url':'https://gamerch.com/onmyojicard/352142','evidence':'蛇魔3/3迅捷相关卡。'}, {'id':'sg-reap-chain','url':'https://gamerch.com/onmyojicard/245067','evidence':'索命按该次链中使用次数增长，复制次数为时限/兄弟之忆切黑历史；白气绝复归黑不增加切黑历史。'}, {'id':'sg-chaos-guide','url':'https://www.taptap.cn/moment/159680773731912617','evidence':'混沌化身移除专牌、禁止手动操作、自动生成并使用自己的法术。'}, {'id':'sg-snake-copy','url':'https://shouyou.3dmgame.com/gl/297445.html','evidence':'觉醒后新蛇魔获得与大蛇相同身材；蛇魔气绝后原式神进入复活倒计时。'}, {'id':'sg-switch-boundaries','url':'https://www.taptap.cn/moment/467093870207830538','evidence':'切换清护甲/破甲、保留灵咒与眩晕等；化身25/15，蛇魔不再向大蛇用不洁之力。'}]
ids=[s['id'] for s in sources]
pending=['中文主体以本地完整PNG为准，派生借日文完整原卡补证。指定录像未逐牌核验；切换/死亡与多段、全体伤害、响应的精细全序仍待原客户端核对。','觉醒蛇魔复制大蛇的形态/身材，原身份和UID保留；复制时其他附属状态、直接变形后的复杂永久成长还原、神愤免战伤持续边界待核。']
units={}
for uid,role,atk,hp,text,awake in [('guishiheibai','ghost',3,4,'充能。当鬼使黑气绝时，消耗2能量，切换为鬼使白。','充能，迅捷。当鬼使黑气绝时，消耗2能量，切换为鬼使白。'),('bayiqidashe','serpent',2,5,by[22000]['desc'],by[22008]['desc'])]:
 units[uid]={'verifiedRules':True,'serpentGhostRole':role,'attack':atk,'maxHp':hp,'nativeCharge':role=='ghost','formLifecycle':{},'passive':{'id':'sg-'+role,'name':'冥界协作' if role=='ghost' else '蛇魔','text':text,'hooks':[]},'awakenedPassive':{'id':'sg-'+role+'-awake','name':'觉醒','text':awake,'hooks':[]},'sources':ids,'verificationPending':pending}
forms={19408:(6,5,{'sgVerdict':True,'combatKeywords':['lethal','first-strike']}),19409:(3,6,{'sgLivingDead':True}),22002:(3,6,{'sgInspireSnakes':True}),22004:(6,6,{'sgShadow':True}),22007:(4,8,{'sgWandering':True})}
actions={19401:'sg-ghost-combat',19402:'sg-brothers',19403:'sg-ghost-combat',19404:'sg-ghost-awaken',19405:'sg-impermanence',19406:'sg-reap',22001:'sg-impure',22003:'sg-sacrifice',22005:'sg-all-snakes',22006:'sg-transform-enemy',22008:'sg-serpent-awaken'}
cards={}
for n in [19401,19402,19403,19404,19405,19406,19408,19409]+list(range(22001,22009)):
 r=by[n];text=r['desc'].split('&')[0].replace('鬼使黑/鬼使白','鬼使黑').replace('#r','\n').replace('#[力量]','力量').replace('#[生命]','生命').replace('#[能量]','能量').replace('#[护甲]','护甲')
 if n==22002:text='你的「蛇魔」获得1力量。\n进场和己方回合开始时，你的「蛇魔」获得昂扬。'
 c={'verifiedRules':True,'serpentGhostRules':True,'type':'spell','typeLabel':'法术牌','level':r['stage'],'cost':1,'copies':2,'deckLimit':2,'target':'auto','text':text,'officialText':text,'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':ids,'verificationPending':pending}
 a=actions.get(n,'sg-form');v=0
 if n in forms:
  atk,hp,flags=forms[n];c.update(type='form',typeLabel='形态牌',formRules=flags,formAbility=text);v={'attack':atk,'hp':hp,'setBase':True}
 if n in [19401,19403,19406]:c.update(type='combat',typeLabel='战斗牌',combatOption={'shield':1 if n==19401 else 2 if n==19403 else 0},responseAction='assault');v=1 if n==19401 else 2 if n==19403 else 0
 if n==19401:c['keywords']=['penetration'];c['combatOption']['penetration']=True
 if n in [19401,19403]:c['movementBurstOptions']=[2]
 if n==19405:c.update(autoResponse='source-attacked',responseTo=['unit-attacked'])
 if n in [19408,22003]:c['keywords']=['instant']
 if n in [19404,22008]:c['tags']=['觉醒'];v={'attack':1 if n==19404 else 5,'hp':1 if n==19404 else 5}
 if n in [22001,22003]:c['target']='sg-other-ally'
 if n==22006:c['target']='enemy-unit'
 c.update(effect=a,value=v,effects=[{'action':a,'target':'selected' if c['target']!='auto' else 'source','value':v}]);cards['c'+str(n)]=c
# Complete, non-constructible derivative definitions.
new={'units':[], 'cards':[]}
for uid,name,atk,hp,text,art in [('sg-ghost-white','鬼使白',2,6,'倒计时2：切换为鬼使黑。','white-txsKFqxc.png'),('sg-snake','蛇魔',3,3,'迅捷。','snake-PT289B07.jpg')]:
 dest='assets/official/serpent-ghost/'+art
 u={'id':uid,'name':name,'title':'鬼使协作身份' if uid=='sg-ghost-white' else '八岐大蛇变形','role':'切换身份','strategy':'','attack':atk,'maxHp':hp,'pack':'wave4','art':dest,'awakenedArt':dest,'color':'#b997a8','token':True,'selectable':False,'countsAsShikigami':True,'passive':{'id':uid+'-passive','name':name,'text':text,'hooks':[]},'verifiedRules':True,'sources':ids,'verificationPending':pending}
 new['units'].append(u);units[uid]=u
for uid,name,level,text,act,value,kw in [('sg-white-awaken','觉醒·鬼使白',3,'瞬发。觉醒：不屈，倒计时1：切换为鬼使黑。每回合一次，当鬼使白受到伤害时，自动使用「索魂」。','sg-white-awaken',{'attack':2,'hp':2},['instant']),('sg-white-soul','索魂',1,'投射：造成等同于鬼使白此次受到伤害的伤害。','sg-white-soul',0,[])]:
 c={'id':uid,'name':name,'unitId':'guishiheibai','pack':'wave4','type':'spell','typeLabel':'法术牌','level':level,'cost':1,'copies':0,'deckLimit':0,'starterCopies':0,'token':True,'target':'auto','text':text,'officialText':text,'keywords':kw,'tags':['觉醒'] if uid=='sg-white-awaken' else [],'timing':'main','responseTo':[],'effect':act,'value':value,'effects':[{'action':act,'target':'source','value':value}],'verifiedRules':True,'serpentGhostRules':True,'sources':ids,'verificationPending':pending}
 new['cards'].append(c);cards[uid]=c
manifest=[]
for n in [19401,19402,19403,19404,19405,19406,19408,19409]+list(range(22001,22009)):
 p=next((root/'art-reference-official/卡面-按版本').glob(f'*/{n//100}_*/{n}_*.png'));target=root/f'godot/assets/official/cards/c{n}.png';target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
 manifest.append({'source':str(p.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for name in ['white-txsKFqxc.png','snake-PT289B07.jpg']:
 for base in [root,root/'godot']:
  dest=base/'assets/official/serpent-ghost'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(out/name,dest)
derivative_manifest=[]
for name,id in [('white-awaken-WEffgx2w.png','sg-white-awaken'),('white-soul-b2zFEqrU.jpg','sg-white-soul')]:
 target=root/f'godot/assets/official/cards/{id}.png'
 # CardFace's original-card path is PNG. Preserve decoded JPEG pixels exactly.
 if name.endswith('.png'):shutil.copy2(out/name,target)
 else:Image.open(out/name).save(target)
 derivative_manifest.append({'source':str((out/name).relative_to(root)),'sourcePage':'https://gamerch.com/onmyojicard/244805','target':str(target.relative_to(root)),'sourceSha256':hashlib.sha256((out/name).read_bytes()).hexdigest(),'targetSha256':hashlib.sha256(target.read_bytes()).hexdigest(),'encoding':'original PNG bytes' if name.endswith('.png') else 'JPEG decoded pixels saved as PNG; not original byte identity','decodedPixelsEqual':Image.open(out/name).convert('RGBA').tobytes()==Image.open(target).convert('RGBA').tobytes()})
for name,page in [('white-txsKFqxc.png','243525'),('snake-PT289B07.jpg','352142')]:
 target=root/'godot/assets/official/serpent-ghost'/name
 derivative_manifest.append({'source':str((out/name).relative_to(root)),'sourcePage':'https://gamerch.com/onmyojicard/'+page,'target':str(target.relative_to(root)),'sourceSha256':hashlib.sha256((out/name).read_bytes()).hexdigest(),'targetSha256':hashlib.sha256(target.read_bytes()).hexdigest(),'encoding':'original image bytes'})
(out/'derivative-art-manifest.json').write_text(json.dumps(derivative_manifest,ensure_ascii=False,indent=2)+'\n')
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
(out/'new_definitions.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
print('SG_METADATA_READY main16 units2 cards2')
