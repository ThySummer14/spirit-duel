from pathlib import Path
import json,hashlib,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
source=root/'art-reference-official/卡面-按版本/06_沧海刀鸣/189_御馔津'
raw={int(c['id']):c for c in json.loads((root/'research-data/cards.json').read_text())}
pending=['按18900–18908完整原PNG及基础牌文接入；丰穗、奉祝与旧官网快照的差异已记录，指定录像未逐牌核验。','符咒转化、自动响应、奉祝自动用符与其他响应全序、狐狩界折扣多源组合仍待原客户端核验。']
unit={'verifiedRules':True,'yujiazhuRules':True,'nativeCharge':True,'attack':3,'maxHp':4,'passive':{'id':'yuj-talisman','name':'符咒转化','text':'充能。御馔津的符咒牌都具有「爆能3：转化为战斗牌并改为攻击任一敌方式神」。','hooks':[]},'awakenedPassive':{'id':'yuj-talisman-awake','name':'符咒转化','text':'充能。御馔津的符咒牌都具有「爆能3：转化为战斗牌并改为攻击任一敌方式神，本次战斗获得免疫战斗伤害」。','hooks':[]},'formLifecycle':{},'sources':['yuj-original-20261029','yuj-official-intro-20201008','yuj-official-balance-20201015'],'verificationPending':pending}
texts={1:'使一个有形态的敌方式神获得「本回合受到伤害时使其气绝」。',2:'攻击敌方式神时获得连击。',3:'御馔津获得3能量，抽一张牌。',4:'眩晕一个敌方式神并使其本回合力量变为0。\n响应：当御馔津被攻击时，自动对攻击她的式神使用。',5:'觉醒：充能。御馔津的符咒牌都具有「爆能3：转化为战斗牌并改为攻击任一敌方式神，本次战斗获得免疫战斗伤害」。',6:'你的所有爆能消耗-1。你的所有符咒牌都获得瞬发。',7:'使一个敌方式神本回合获得「对其攻击的式神获得暴击和贯通」。',8:'追猎。\n出击时对被攻击的式神使用每种本局游戏御馔津使用过的符咒牌。\n本局游戏每使用过一种符咒牌，御馔津获得+1力量和+1生命。'}
cards={}
for n in range(1,9):
 cid=f'c189{n:02}';c={'verifiedRules':True,'yujiazhuRules':True,'type':'spell','typeLabel':'法术牌','cost':1,'copies':2,'deckLimit':2,'target':'auto','text':texts[n],'officialText':texts[n],'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':unit['sources'],'verificationPending':pending,'level':int(raw[18900+n]['stage'])}
 action='yuj-talisman' if n in [1,4,7] else 'yuj-harvest' if n==3 else 'awaken' if n==5 else 'realm' if n==6 else 'form'
 val=0
 if n in [1,4,7]:c.update(movementRules=True,movementBurstOptions=[3],target='enemy-unit',yujTalisman=True)
 if n==4:c.update(autoResponse='source-attacked',responseModifiesCombat=True)
 if n==2:c.update(type='form',typeLabel='形态牌',formRules={'yujHunt':True});val={'attack':3,'hp':7,'setBase':True}
 if n==5:val={'attack':1,'hp':1}
 if n==6:c.update(type='realm',typeLabel='幻境牌',realm={'hp':8,'nativeRealm':'yuj-fox-hunt','triggerEffect':''})
 if n==8:c.update(type='form',typeLabel='形态牌',formRules={'yujPrayer':True,'combatKeywords':['pursuit'],'yujPrayerCount':0});val={'attack':3,'hp':6,'setBase':True}
 c.update(effect=action,value=val,effects=[{'action':action,'target':'selected' if n in [1,4,7] else 'source','value':val}])
 if n in [2,8]:c['formAbility']=texts[n]
 cards[cid]=c
sources=[{'id':'yuj-original-20261029','path':str(source.relative_to(root)),'evidence':'九张完整原PNG：基础3/4、八牌等级/身材/牌文及奉祝去重符咒成长。'}, {'id':'yuj-official-intro-20201008','url':'https://www.taptap.cn/moment/63371912369145376','evidence':'官方式神教程确认三符爆能转战斗、保留符咒效果、御狩与奉祝攻击行为。'}, {'id':'yuj-official-balance-20201015','url':'https://www.taptap.cn/moment/65548006706908103','evidence':'官方维护说明：破魔箭改+1力量/+1护甲、丰穗改得3能量抽1；奉祝可选无形态目标、驱魔0伤不气绝及封魔响应支付修复。'}]
(out/'overlay.json').write_text(json.dumps({'units':{'yujiazhu':unit},'cards':cards,'sources':sources},ensure_ascii=False,indent=2)+'\n')
manifest=[]
for n in range(18901,18909):
 p=next(source.glob(f'{n}_*.png'));dest=root/f'godot/assets/official/cards/c{n}.png';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
 manifest.append({'source':str(p.relative_to(root)),'target':str(dest.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps({'baseline':{str(k):raw[k] for k in range(18900,18909)},'sources':sources},ensure_ascii=False,indent=2)+'\n')
print('YUJIAZHU_OVERLAY_AND_ART_READY',len(cards),len(manifest))
