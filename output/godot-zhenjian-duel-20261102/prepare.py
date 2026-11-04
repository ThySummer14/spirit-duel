from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
raw=json.loads((root/'research-data/cards.json').read_text())
sources=[{'id':'zhenjian-duel-original-20261102','path':'art-reference-official/卡面-按版本/15_振剑归川/','evidence':'26400–26408、26500–26508完整原PNG逐图目检；迅烈如火为4/7形态；闪步·振刀采用本地原图2勾，两仪剑阵无蓄力敌人时4伤。'}, {'id':'wuchen-followup-card','url':'https://gamerch.com/onmyojicard/478995','evidence':'相关衍生追加攻击+1力量、无护甲；若飞索突袭选择的式神未气绝则以其为攻击目标。主体数值以本地中文PNG优先，不采用日服两仪3伤版本。'}, {'id':'canghai-manual-release-observed','url':'https://www.taptap.cn/moment/467093870207830538','evidence':'原作者观察记载觉醒季沧海通过手牌最右的蓄力牌主动释放；蓄力并非用牌。BUG记载不作为改写基础规则的理由。'}]
pending=['按完整原PNG与基础牌文接入主要机制；指定原版录像未逐牌核验。蓄力、响应、同时交战、复活及移动的复杂全序仍待原客户端核验。','觉醒季沧海蓄力双触发、旋风斩半伤取整与伤害类型、无尘新获得牌及蓄力费用的边界仍需原客户端核验；主体数值保留本地中文原PNG版本。']
units={}
for uid,role,atk,hp,base,awake in [('jicanghai','canghai',2,6,'季沧海蓄力状态下获得等同于自身等级的力量。','季沧海在蓄力状态下获得等同于自身等级的力量。季沧海蓄力的牌蓄力效果触发两次，且回合开始时不再自动打出，改为玩家可以自行决定蓄力出牌的时机。'),('wuchen','wuchen',3,4,'当无尘移动回准备区时，本回合他的下一张牌获得瞬发。','每回合一次，当无尘移动时，本回合他的下一张牌获得不消耗鬼火，并且未蓄力时也能触发蓄力效果。')]:
 units[uid]={'verifiedRules':True,'zdRole':role,'attack':atk,'maxHp':hp,'formLifecycle':{},'passive':{'id':'zd-'+role,'name':'蓄势待发' if role=='canghai' else '身法','text':base,'hooks':[]},'awakenedPassive':{'id':'zd-'+role+'-awake','name':'蓄势待发' if role=='canghai' else '两仪身法','text':awake,'hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}
levels={264:[1,2,1,1,2,2,3,3],265:[1,2,1,2,2,2,3,3]}
text={26401:'蓄力：获得+1力量和贯通。',26402:'蓄力：造成伤害后对另一个敌方角色再造成一半的伤害。',26403:'当季沧海被式神攻击时，若此牌蓄力中则自动使用。投射：造成等同于自身力量的伤害。蓄力：使季沧海获得屏障。',26404:'当季沧海被蓄力状态的式神攻击时，若此牌蓄力中则自动使用并使该式神气绝。蓄力：抽一张牌。',26405:'季沧海受到的战斗伤害-1。当季沧海攻击式神或被式神攻击后，随机蓄力一张等级为1的牌。',26406:units['jicanghai']['awakenedPassive']['text'],26407:'免疫战斗伤害。从手牌使用后自动蓄力此牌。蓄力：再次使用此牌。',26408:'进场和己方回合开始时，随机获得一张本局游戏季沧海使用过的战斗牌。季沧海所有牌获得瞬发，季沧海免疫非战斗伤害和直接消灭效果。',26501:'蓄力：直击。',26502:'移动无尘，抽一张牌。直到你的下一个回合开始，当无尘被蓄力状态的式神攻击时，使其气绝。增强：若本回合无尘攻击过，此牌不消耗鬼火。',26503:'追猎。蓄力一张「追加攻击」。',26504:'攻击后移动回准备区。蓄力：免疫战斗伤害。',26505:'进场时移动无尘。每回合一次，当无尘将受到伤害时，防止本次伤害并移动无尘。',26506:'蓄力：此牌获得连击。',26507:'随机获得一张无尘的战斗牌。觉醒：'+units['wuchen']['awakenedPassive']['text'],26508:'迅捷，替身。当无尘蓄力或移动时，随机对一个蓄力状态的敌方式神造成10点伤害，若没有则改为对一个随机敌方角色造成4点伤害。'}
forms={26405:(4,7,{'zdRock':True}),26408:(4,7,{'zdFierce':True}),26505:(4,5,{'zdDischarge':True}),26508:(4,7,{'zdSword':True,'substitute':True})}
combats={26401:(1,1),26402:(2,1),26404:(0,0),26407:(1,1),26501:(1,1),26503:(0,1),26504:(2,2),26506:(2,1)}
cards={}
for num,t in text.items():
 c={'verifiedRules':True,'zdRules':True,'type':'spell','typeLabel':'法术牌','level':levels[num//100][num%100-1],'cost':1,'copies':2,'deckLimit':2,'target':'auto','text':t,'officialText':t,'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':[s['id'] for s in sources],'verificationPending':pending}
 action='zd-flame' if num==26403 else 'zd-awaken' if num in [26406,26507] else 'zd-step' if num==26502 else 'zd-combat';val=0
 if num in forms:
  atk,hp,flags=forms[num];c.update(type='form',typeLabel='形态牌',formRules=flags,formAbility=t);action='form';val={'attack':atk,'hp':hp,'setBase':True}
 if num in combats:
  atk,shield=combats[num];c.update(type='combat',typeLabel='战斗牌',responseAction='assault',combatOption={'shield':shield});val=atk
 if num==26407:c['combatOption']['immuneCombat']=True
 if num==26503:c.update(target='enemy-unit',keywords=['pursuit']);c['combatOption']['pursuit']=True
 if num in [26406,26507]:c['zdAwaken']=True;val={'attack':1,'hp':1}
 if num in [26401,26402,26403,26404,26407,26501,26504,26506]:c['canCharge']=True
 if num==26508:c['keywords']=['swift','substitute']
 c.update(effect=action,value=val,effects=[{'action':action,'target':'selected' if num==26503 else 'source','value':val}]);cards[f'c{num}']=c
follow={'id':'wuchen-followup','name':'追加攻击','unitId':'wuchen','token':True,'derivedFrom':'c26503','pack':'wave6','type':'combat','typeLabel':'战斗牌','level':0,'cost':1,'copies':0,'deckLimit':0,'target':'auto','text':'若「飞索突袭」所选择的式神未气绝，将本次攻击目标改为该式神。','officialText':'若「飞索突袭」所选择的式神未气绝，将本次攻击目标改为该式神。','keywords':[],'effect':'zd-combat','value':1,'effects':[{'action':'zd-combat','target':'source','value':1}],'combatOption':{'shield':0},'zdRules':True,'verifiedRules':True,'timing':'main','responseTo':[],'sources':[s['id'] for s in sources],'verificationPending':pending}
cards['wuchen-followup']=follow
(out/'new_definitions.json').write_text(json.dumps({'units':[],'cards':[follow]},ensure_ascii=False,indent=2)+'\n')
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps([c for c in raw if int(c.get('role',0)) in [264,265]],ensure_ascii=False,indent=2)+'\n')
manifest=[]
for num in text:
 p=next((root/'art-reference-official/卡面-按版本/15_振剑归川').glob(f'{num//100}_*/{num}_*.png'));target=root/f'godot/assets/official/cards/c{num}.png'
 manifest.append({'source':str(p.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
for entry in manifest:shutil.copy2(root/entry['source'],root/entry['target'])
print('ZHENJIAN_DUEL_PREPARED main=16 derivatives=1')
