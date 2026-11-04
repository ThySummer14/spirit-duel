from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
raw = json.loads((root / 'research-data/cards.json').read_text())
sources = [{'id': 'charged-pair-original-20261030', 'path': 'art-reference-official/卡面-按版本/15_振剑归川/', 'evidence': '26800–26808、26900–26908完整原PNG；按印刷勾玉与牌型覆盖旧导出，含林中秘宝3勾、茂林深篁1勾、心如磐石2勾与不二法门3勾。'}, {'id': 'charged-mechanism-player-20220926', 'url': 'https://www.bilibili.com/opus/709901963270029348', 'evidence': '玩家规则研究补充蓄力并非使用、记录目标、每式神一张、眩晕延迟、气绝移除；与连引特例及复杂顺序仍待原客户端核验。'}]
pending = ['按完整原PNG和基础牌文接入主要机制，指定录像未逐牌覆盖；蓄力与回合开始、响应、气绝/复活及其他自动使用的完整顺序仍待原客户端核验。', '林中秘宝与万变竹影的随机牌/目标权重、已有永久增强和连引特例的全部组合仍待原客户端核验；不以历史已知bug代替基础规则。']
units = {}
for uid, role, text, awake in [
 ('wannianzhu', 'bamboo', '万年竹的牌都可以蓄力。己方式神使用已蓄力的牌时，获得1力量。', '万年竹的牌都可以蓄力。己方式神使用已蓄力的牌时，获得1力量且抽1张牌。'),
 ('shuzhu', 'beads', '当数珠蓄力时，获得1力量和1生命。', '当数珠蓄力时，永久获得1力量和1生命。'),
]:
 units[uid] = {'verifiedRules': True, 'chargedPairRole': role, 'attack': 2, 'maxHp': 5, 'formLifecycle': {}, 'passive': {'id': 'charged-'+role, 'name': '竹间清音' if role=='bamboo' else '禅意', 'text': text, 'hooks': []}, 'awakenedPassive': {'id': 'charged-'+role+'-awake', 'name': '竹间清音' if role=='bamboo' else '禅意', 'text': awake, 'hooks': []}, 'sources': [s['id'] for s in sources], 'verificationPending': pending}
texts = {
26801:'使一个式神获得2力量，抽一张牌。若该式神处于蓄力状态，则额外获得2护甲。',26802:'先攻。每有一个蓄力状态的式神，此牌获得1力量。',26803:'每回合一次，己方未蓄力的式神使用战斗牌或非觉醒法术牌后，将其复制并蓄力，目标选择相同。',26804:'当己方蓄力状态的式神气绝时，投射：造成4点伤害。',26805:'进场时为所有己方式神恢复2生命。己方蓄力状态的式神获得帷幕。',26806:'瞬发。使一个蓄力状态的式神使用他已蓄力的牌。',26807:'所有己方未蓄力的式神随机蓄力一张本局游戏他使用过的牌（随机为这些牌选择目标），然后将一张「清风徐来」置入你的手牌。',26808:'觉醒：万年竹的牌都可以蓄力。己方式神使用已蓄力的牌时，获得1力量且抽1张牌。',26901:'为数珠和你恢复3生命。从手牌使用后再次蓄力此牌。',26902:'蓄力：获得一张「降魔杖」。',26903:'蓄力：追猎。',26904:'蓄力：获得屏障。当数珠被式神攻击时，若此牌蓄力中则自动使用。',26905:'蓄力：消灭敌方战斗区式神。',26906:'昂扬。蓄力：获得迅捷。',26907:'气绝时可用，复活数珠。觉醒：当数珠蓄力时，永久获得1力量和1生命。',26908:'当数珠气绝时，复活数珠并蓄力此牌。蓄力：进场时发起一次攻击且本次攻击免疫战斗伤害。'}
levels={268:[1,1,3,2,1,2,3,2],269:[1,1,1,2,3,2,2,3]}
forms={26803:(4,6,{'chargedCopy':True}),26804:(3,6,{'chargedDeath':True}),26903:(3,6,{}),26906:(6,6,{}),26908:(6,6,{'chargedReviveForm':True})}
cards={}
for num,text in texts.items():
 uid='wannianzhu' if num//100==268 else 'shuzhu'
 c={'verifiedRules':True,'chargedPairCard':True,'type':'spell','typeLabel':'法术牌','level':levels[num//100][num%100-1],'cost':1,'copies':2,'deckLimit':2,'target':'auto','text':text,'officialText':text,'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':[s['id'] for s in sources],'verificationPending':pending}
 action={26801:'charged-grow-draw',26802:'charged-combat',26806:'charged-release',26807:'charged-history',26808:'charged-awaken',26901:'charged-heal',26902:'charged-combat',26904:'charged-combat',26905:'charged-combat',26907:'charged-awaken'}.get(num,'form' if num in forms else 'charged-realm')
 val=0
 if num in [26801,26806]:c['target']='any-unit' if num==26801 else 'ally-unit'
 if num in [26802,26902,26904,26905]:
  c.update(type='combat',typeLabel='战斗牌',responseAction='assault',combatOption={'shield':1 if num==26904 else 2 if num==26905 else 0});val={26802:1,26902:0,26904:1,26905:2}[num]
 if num==26802:c['keywords']=['first-strike'];c['combatOption']['firstStrike']=True
 if num in forms:
  atk,hp,flags=forms[num];c.update(type='form',typeLabel='形态牌',formRules=flags,formAbility=text);val={'attack':atk,'hp':hp,'setBase':True}
 if num==26906:c['keywords']=['inspired']
 if num in [26806]:c['keywords']=['instant']
 if num in [26808,26907]:c['chargedAwaken']=True;val={'attack':1,'hp':1}
 if num==26907:c['allowKnockedSource']=True
 if num==26805:c.update(type='realm',typeLabel='幻境牌',realm={'hp':6,'nativeRealm':'charged-forest','triggerEffect':''})
 if num//100==268 or num in [26902,26903,26904,26905,26906,26908]:c['canCharge']=True
 c.update(effect=action,value=val,effects=[{'action':action,'target':'selected' if num in [26801,26806] else 'source','value':val}]);cards[f'c{num}']=c
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps([c for c in raw if int(c.get('role',0)) in [268,269]],ensure_ascii=False,indent=2)+'\n')
manifest=[]
for num in texts:
 p=next((root/'art-reference-official/卡面-按版本/15_振剑归川').glob(f'{num//100}_*/{num}_*.png'));target=root/f'godot/assets/official/cards/c{num}.png';shutil.copy2(p,target)
 manifest.append({'source':str(p.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('CHARGED_PAIR_PREPARED cards=16')
