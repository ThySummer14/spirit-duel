from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
raw=json.loads((root/'research-data/cards.json').read_text());base=json.loads((root/'godot/content/content.json').read_text());old={c['id']:c for c in base['cards']}
sources=[{'id':'rednight-walnut-original-20261102','path':'art-reference-official/卡面-按版本/15_振剑归川/','evidence':'266宁红夜和267土御门胡桃完整原PNG各9张；本地同期官方版式介绍大图。净天地低耐久按原图对双方所有式神造成伤害；万刃轮原图+2力量。'},{'id':'rednight-20221027-description-fix','url':'https://m.youxi369.com/gonglue/142422.html','evidence':'2022-10-27维护公告转载：散射仅敌方是描述修正；蓄力射击仍允许友方。不是后续平衡替换。'},{'id':'walnut-introduction-items','url':'https://note.com/vongole8940/n/n2c524f462e08','evidence':'2022-10-13同期介绍译注，补足落物堆五种随机物品和剑气定义；飓风客选项分组仍待原客户端核验。'}]
pending=['按基础牌文和完整原PNG实现主要机制；指定录像未逐牌核验。蓄力、非战斗伤害触发与复活/响应的完整先后仍待原客户端核验。','飓风客先攻击物品三选一、结算后再辅助物品三选一：现有2023攻略与初版同期译注的随机三项表述有差别；采用可见攻防两组，不宣称选项池抽样已实机核对。落物堆五种物品取同期译注，尚缺单独官方物品原图。']
units={};cards={};manifest=[]
for number,uid,role,atk,hp in [(266,'ninghongye','rednight',3,4),(267,'tayumenhutao','walnut',2,5)]:
 row=next(x for x in raw if int(x['id'])==number*100)
 awakened=next(x for x in raw if int(x['id'])==number*100+7)['desc'].replace('觉醒：','').replace('#r','\n')
 units[uid]={'verifiedRules':True,'rednightWalnutRole':role,'attack':atk,'maxHp':hp,'formLifecycle':{},'passive':{'id':f'{role}-native','name':'红夜' if number==266 else '庇佑','text':row['desc'],'hooks':[]},'awakenedPassive':{'id':f'{role}-awake','name':'觉醒','text':awakened,'hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}
 for n in range(1,9):
  cid=f'c{number}{n:02d}';r=next(x for x in raw if int(x['id'])==number*100+n)
  typ='awakening' if n==7 else {'法术':'spell','战斗':'combat','形态':'form','结界':'realm'}[r['type']]
  level=([1,1,1,2,2,2,3,3] if number==266 else [1,1,2,1,2,2,3,3])[n-1]
  target='any-unit' if number==266 and n in [2,4,5] else 'enemy-unit' if number==266 and n in [5,8] else 'ally-unit' if number==267 and n==1 else 'auto'
  value={'attack':int(r['ll']),'hp':int(r['sm']),'setBase':True} if typ=='form' else {'attack':2,'hp':2} if n==7 else 1 if cid=='c26603' else 0
  text=r['desc'].replace('#r','\n').replace('#[耐久]','耐久').replace('#[生命]','生命').replace('#[护甲]','护甲')
  if cid=='c26605':text='对一个敌方式神和随机另一个敌方式神各造成3点伤害。蓄力：此牌伤害+1。'
  c={'verifiedRules':True,'rednightWalnutRules':True,'type':typ,'typeLabel':'觉醒牌' if n==7 else {'spell':'法术牌','combat':'战斗牌','form':'形态牌','realm':'幻境牌'}[typ],'level':level,'cost':1,'target':target,'copies':2,'deckLimit':2,'text':text,'officialText':text,'keywords':['instant'] if cid=='c26604' else ['remote'] if cid=='c26603' else [],'tags':[],'timing':'main','responseTo':[],'effect':'rw-card','value':value,'effects':[{'action':'rw-card','target':'selected' if target!='auto' else 'source','value':value}],'formHooks':[],'formRules':{'rwLock':True} if cid=='c26601' else {'rwPhoenix':True} if cid=='c26606' else {'rwProtect':True} if cid=='c26701' else {'rwParry':True} if cid=='c26703' else {},'formAbility':text if typ=='form' else '', 'sources':[s['id'] for s in sources],'verificationPending':pending}
  if number==266 and n in [1,2,3,5,8]:c['canCharge']=True
  if cid=='c26603':c['combatOption']={'remote':True}
  if cid in ['c26602','c26603','c26605']:c['responseAction']='damage'
  if cid in ['c26604','c26608']:c['responseAction']='freeze'
  if typ=='realm':c['realm']={'hp':int(r['sm']),'nativeRealm':{4:'rw-loot',5:'rw-pure',6:'rw-earth'}[n],'trigger':'native-continuous'}
  cards[cid]=c
  source=next((root/'art-reference-official/卡面-按版本/15_振剑归川').glob(f'{number}_*/*{number}{n:02d}_*.png'))
  targetpath=root/f'godot/assets/official/cards/{cid}.png';shutil.copy2(source,targetpath)
  manifest.append({'source':str(source.relative_to(root)),'target':str(targetpath.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
token={'id':'rednight-sword-aura','unitId':'ninghongye','name':'剑气','verifiedRules':True,'rednightWalnutRules':True,'type':'combat','typeLabel':'战斗牌','level':2,'cost':0,'copies':0,'deckLimit':0,'token':True,'target':'auto','effect':'rw-card','value':0,'effects':[{'action':'rw-card','target':'source','value':0}],'text':'获得2护甲。本次攻击免疫战斗伤害。攻击后投射：造成3点伤害。','officialText':'0力量/2护甲，免疫战斗伤害，攻击后投射3点伤害。','keywords':[],'timing':'main','responseTo':[],'combatOption':{'shield':2,'immuneCombat':True},'sources':[s['id'] for s in sources],'verificationPending':pending}
cards[token['id']]=token
for name,obj in [('overlay.json',{'sources':sources,'units':units,'cards':cards}),('new_definitions.json',{'units':[],'cards':[token]}),('card-art-manifest.json',manifest),('official-source-evidence.json',[r for r in raw if str(r.get('role')) in ['266','267']])]:
 (out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print('REDNIGHT_WALNUT_PREPARED cards=16 token=1')
