from pathlib import Path
import json
root=Path(__file__).resolve().parents[2];path=root/'godot/content/verified_rules.json';v=json.loads(path.read_text())
raw={str(c['id']):c for c in json.loads((root/'research-data/cards.json').read_text())}
pending=['基础主体机制按牌文实现；指定录像未逐卡覆盖本组。诅咒叠层、奇数手牌弃置和复杂自动用牌/反制边界仍保留实机核验。']
source='eye-crab-baseline'
v['sources']=[s for s in v['sources'] if s.get('id') != source]
v['sources'].append({'id':source,'path':'research-data/cards.json','url':'https://www.iyingdi.com/tz/post/2334401','evidence':'19600–19608、21000–21008基础牌文与本地原版卡面；原作者百目鬼攻略及20210714蟹姬攻略补充诅咒四选一与全牌库弹回。'})
for uid,role,flag in [('baimugui','196','eyeDivination'),('xieji','210','crabSameName')]:
 r=raw[role+'00'];desc='每当己方式神占卜时，投射：造成1点伤害。' if uid=='baimugui' else '手牌中蟹姬的牌，若本局使用过同名牌，则获得瞬发。'
 awake='每当己方式神占卜时，投射：造成等同占卜数量的伤害。' if uid=='baimugui' else '手牌中己方式神的牌，若本局使用过同名牌，则获得瞬发。'
 v['units'][uid]={'verifiedRules':True,flag:True,'attack':int(r['ll']),'maxHp':int(r['sm']),'formLifecycle':{},'passive':{'name':'基础能力','text':desc,'hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':awake,'hooks':[]},'sources':[source],'verificationPending':pending}
def card(num,typ,text,effect,value=None,target='auto',kws=None,**extra):
 r=raw[str(num)];x={'verifiedRules':True,'type':typ,'typeLabel':{'spell':'法术牌','awakening':'觉醒牌','form':'形态牌','combat':'战斗牌','realm':'幻境牌'}[typ],'level':int(r['stage']),'cost':1,'target':target,'effect':effect,'value':value,'text':text,'officialText':text,'keywords':kws or [],'timing':'main','responseTo':[],'formHooks':[],'sources':[source],'verificationPending':pending,'eyeRules':str(num).startswith('196'),'crabRules':str(num).startswith('210')}
 if typ=='form': x.update(formAbility=text,formRules={})
 x.update(extra)
 x.setdefault('effects',[{'action':effect,'target':'source' if typ in ['combat','form','awakening'] else target,'value':value}])
 v['cards']['c'+str(num)]=x
body=lambda a,h:{'attack':a,'hp':h,'setBase':True}
card(19601,'spell','占卜1，抽两张牌。','eye-divination',1,effects=[{'action':'eye-divination','value':1},{'action':'draw','target':'ally-player','value':2}])
card(19602,'spell','贯通。对一个敌方式神造成2点伤害，使用后将原牌洗入牌库，本局同名牌永久+2伤害。','eye-flame',2,'enemy-unit',['pierce'])
card(19603,'form','己方占卜效果+1。','form',body(3,6),formRules={'eyeDivinationBonus':1})
card(19604,'spell','移动一个式神。','move-unit',None,'any-living-unit')
card(19605,'awakening','占卜2。觉醒：每当己方式神占卜时，投射：造成X点伤害，X为占卜牌数量。','eye-awaken',{'attack':1,'hp':1},awakening=True,effects=[{'action':'eye-awaken'},{'action':'eye-divination','value':2}])
card(19606,'spell','选择一个角色，抽一张牌，对其造成等同所抽牌等级两倍的伤害。','eye-draw-gaze',None,'any-living-character')
card(19607,'spell','为敌方牌手占卜2，然后展示他牌库顶牌，消灭此牌对应的式神。','eye-enemy-divination',2,effects=[{'action':'eye-enemy-divination','value':2},{'action':'eye-all-knowing'}])
card(19608,'form','进场时随机为敌方牌库四张牌结附「诅咒」。己方回合开始时，为敌方牌手占卜1。','form',body(4,8),formRules={'eyeCurse':True})
card(21001,'spell','选择一张蟹姬手牌，将三张复制洗入牌库，抽一张牌。','crab-sleep')
card(21002,'combat','增强：本局每使用过一张此牌，额外获得+2力量和+1护甲。','assault',1,combatOption={'shield':1})
card(21003,'spell','抽一张牌。增强：本局每使用过一张此牌，额外多抽一张。','draw',1,effects=[{'action':'draw','target':'ally-player','value':1}])
card(21004,'form','帷幕。增强：本局每使用过一张此牌，额外获得2力量和2生命。','form',body(6,6),formRules={'combatKeywords':['veil']},crabGrowingBody=True)
card(21005,'spell','对一个敌方角色造成4点伤害。增强：本局每使用过一张此牌，额外随机对一个敌方角色造成2点伤害。','crab-hammer',4,'enemy-character')
card(21006,'realm','己方回合结束时，随机将一张手牌的复制置入手牌。','realm',realm={'hp':8,'nativeRealm':'crab-dream','trigger':'native-continuous'})
card(21007,'awakening','随机将一张手牌的复制置入手牌。觉醒：手牌中己方式神的牌，若本局使用过同名牌，则获得瞬发。','crab-awaken',{'attack':2,'hp':2},awakening=True)
card(21008,'form','蟹姬所有战斗和法术牌获得一次弹回。每回合一次，使用本局已用过的同名牌后，发起一次攻击，本次战斗免疫所有伤害。','form',body(4,8),formRules={'crabBounce':True})
for ident in ['c19602','c19606','c21005']: v['cards'][ident]['responseAction']='damage'
path.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
