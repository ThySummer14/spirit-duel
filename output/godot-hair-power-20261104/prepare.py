from pathlib import Path
import json,hashlib,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent;raw=json.loads((root/'research-data/cards.json').read_text())
sources=[{'id':'hair-original-20261104','evidence':'609完整中文原PNG：1/6基础，真实之颜5/8、食发之喜2/7、两结界耐久5。'},{'id':'hair-official-combat-power','url':'https://www.taptap.cn/moment/483003889277208129','evidence':'官方战力寿命：下一次战斗伤害加成、战斗后移除、未战斗也在下个己方回合开始移除；疾速改付出击次数，瞬发优先。'}]
sources.append({'id':'hair-official-guard','url':'https://www.taptap.cn/app/158690/topic?page=65&type=official','evidence':'坚守额外获得一次免费出击及出击加成（若有），式神移入战斗区但不发动攻击；在下个己方回合开始失去。'})
pending=['按基础牌文与完整原PNG接入，指定录像未逐牌核验；战力/乏力叠加抵消、半数取整、多重战斗/切换/反制完整全序仍待原客户端核验。','疾速按瞬发优先、坚守次数优先于普通出击；坚守真实移入战斗区不攻击。多来源出击加成与鼓舞关键词持续范围仍待原客户端核验。']
units={'shifagui':{'verifiedRules':True,'hairPowerRules':True,'attack':1,'maxHp':6,'formLifecycle':{},'passive':{'id':'hair-power','name':'战力','text':'己方回合开始时获得2战力。','hooks':[]},'awakenedPassive':{'id':'hair-power-awake','name':'觉醒·食发鬼','text':'己方回合开始时获得2战力，本局之后每个己方回合开始时此效果+1（气绝时有效）。','hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}}
cards={};manifest=[]
for n in range(1,9):
 id=f'c609{n:02d}';r=next(c for c in raw if c['id']==60900+n);typ={'战斗':'combat','法术':'spell','形态':'form','结界':'realm'}[r['type']]
 if n==4:typ='awakening'
 text=r['desc'].replace('#r','\n')
 for key in ['战力','力量','乏力','生命','护甲']:text=text.replace('#['+key+']',key)
 action='hair-combat' if typ=='combat' else 'hair-form' if typ=='form' else 'hair-realm' if typ=='realm' else 'hair-awaken'
 value={'attack':5 if n==6 else 2,'hp':8 if n==6 else 7,'setBase':True} if typ=='form' else {'attack':1,'hp':1} if n==4 else 0
 c={'verifiedRules':True,'hairPowerRules':True,'type':typ,'typeLabel':{'combat':'战斗牌','form':'形态牌','realm':'结界牌','awakening':'觉醒牌'}[typ],'level':int(r['stage']),'cost':1,'copies':2,'deckLimit':2,'text':text,'officialText':text,'keywords':['swift-card','penetration','pierce'] if n==1 else ['pursuit'] if n==5 else ['instant'] if n==7 else [],'tags':[],'timing':'main','responseTo':[],'target':'ally-unit' if n==3 else 'enemy-unit' if n in [4,5] else 'auto','effect':action,'value':value,'effects':[{'action':action,'target':'selected' if n in [3,4,5] else 'source','value':value}],'formRules':{'hairFace':True} if n==6 else {'hairJoy':True} if n==8 else {},'formHooks':[],'formAbility':text if typ=='form' else '', 'sources':[s['id'] for s in sources],'verificationPending':pending}
 if typ=='combat':c['combatOption']={'pursuit':n==5,'penetration':n==1,'pierce':n==1};c['responseAction']='assault'
 if n==8:c['allowKnockedSource']=True
 if typ=='realm':c['realm']={'hp':5,'nativeRealm':'hair-fear' if n==3 else 'hair-fearless','trigger':'native-continuous'}
 cards[id]=c
 src=next((root/'art-reference-official/卡面-按版本/20_桃源故里/609_食发鬼').glob(f'609{n:02d}_*.png'));dst=root/f'godot/assets/official/cards/{id}.png';dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);manifest.append({'source':str(src.relative_to(root)),'target':str(dst.relative_to(root)),'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
for name,obj in [('overlay.json',{'sources':sources,'units':units,'cards':cards}),('new_definitions.json',{'units':[],'cards':[]}),('card-art-manifest.json',manifest)]:(out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print('HAIR_PREPARED main8')
