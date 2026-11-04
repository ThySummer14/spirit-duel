from pathlib import Path
import hashlib, json, shutil
root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
raw = json.loads((root / 'research-data/cards.json').read_text())
sources = [
 {'id':'rabbit-tide-original-20261103','path':'art-reference-official/卡面-按版本/13_喧哗烩战/','evidence':'24700–24708、25000–25008完整原PNG目检。觅食为抽牌；孤独的美食兔为烹饪触发；萌动免疫战斗伤害、增强追猎；塑潮使者4/5远程；永生之汐含帷幕。'},
 {'id':'rabbit-tide-official-20220414','url':'https://www.taptap.cn/moment/263404919191503871','evidence':'官方海原贝戟离场若手中无咏流则给一张；永生之汐进场眩晕、在场帷幕、离场全敌方角色2伤。'},
 {'id':'rabbit-tide-official-20220331','url':'https://www.taptap.cn/moment/258340769469827609','evidence':'唤潮眩晕并压制降低2力量；萌动免战伤并在敌方不明食材/黑暗料理历史后获得追猎。'},
 {'id':'rabbit-tide-spear-derivative','url':'https://gamerch.com/onmyojicard/353804','evidence':'相关卡：海原贝戟1勾0/2；咏流1勾召唤贝戟，增强当千姬使用牌时此牌获得瞬发。主体觉醒继续采用中文PNG版本。'},
 {'id':'rabbit-recipe-derivative','url':'https://gamerch.com/onmyojicard/354067','evidence':'兔丸特制食谱：已获得山珍追加投射3，海味追加牌手恢复5，时蔬追加压制-3/-3。'},
 {'id':'rabbit-unknown-dark','url':'https://gamerch.com/onmyojicard/354060','evidence':'相关卡：不明食材使式神获得4破甲；合成佳肴时改成黑暗料理；黑暗料理瞬发、使一个式神获得6破甲。'},
 {'id':'cooking-chinese-mechanics','url':'https://www.taptap.cn/moment/341546240254673892','evidence':'玩家实测说明黑暗料理视为佳肴参与猫掌柜效果，但厨艺研行不使用它；解忧移除海原贝戟不提供咏流，复杂移除边界待核。'}
]
pending = ['按完整原PNG与基础牌文接入主要机制，指定录像尚未逐牌核验；食材派生采用日文相关卡补证，中文完整tooltip与复杂运势/响应全序仍待原客户端核验。', '千姬召唤、离场、移除和解忧等交叉边界仍需原客户端核验；已明确接入的中文PNG版本保留，不逐季回退。']
units = {}
for uid,role,atk,hp,base,awake in [
 ('tuwan','rabbit',2,6,'每回合一次，当兔丸运势失败时，获得一张「不明食材」。','己方回合开始时，运势4：烹饪。当兔丸运势失败时，获得一张「不明食材」。'),
 ('qianji','tide',3,4,'第一个己方回合开始时，召唤「海原贝戟」。','你的海原贝戟获得+4力量。「咏流」获得瞬发。')]:
 units[uid] = {'verifiedRules':True,'rabbitTideRole':role,'attack':atk,'maxHp':hp,'formLifecycle':{},'passive':{'id':'rt-'+role,'name':'美食之旅' if role=='rabbit' else '海原贝戟','text':base,'hooks':[]},'awakenedPassive':{'id':'rt-'+role+'-awake','name':'觉醒','text':awake,'hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}
texts = {
24701:'使你的海原贝戟获得4力量并使其发起攻击，本次攻击免疫战斗伤害。',24702:'对一个式神造成3点伤害。增强：若海原贝戟在场，投射：造成3点伤害。',24703:'当你召唤海原贝戟时，压制：降低2力量。',24704:'眩晕一个敌方式神，压制：降低2力量。增强：若海原贝戟在场，抽一张牌。',24705:units['qianji']['awakenedPassive']['text'],24706:'远程。当你召唤海原贝戟时，使千姬发动一次攻击。',24707:'使你的海原贝戟获得5力量并攻击一个指定的敌方式神，本次攻击免疫战斗伤害。',24708:'海原贝戟进场时，随机眩晕一个敌方式神。海原贝戟在场时，千姬获得帷幕。海原贝戟离场时，对所有敌方角色造成2点伤害。',
25001:'运势4：抽一张牌。',25002:'每回合一次，当己方式神烹饪时，运势4：随机对兔丸使用一张食材。',25003:'瞬发。抽一张牌。增强：本局游戏每获得过一种食材，追加一种效果。山珍：投射3；海味：为你的牌手恢复5点生命；时蔬：压制，降低3力量和3护甲。',25004:units['tuwan']['awakenedPassive']['text'],25005:'当兔丸攻击式神或被式神攻击时，运势4：对该式神使用一张不明食材。',25006:'免疫战斗伤害。增强：若本回合你对敌方式神使用过不明食材或黑暗料理，此牌获得追猎。',25007:'进场时，对一个式神使用一张不明食材。当你对敌方式神使用不明食材或黑暗料理后，对其造成3点伤害。',25008:'贯通。当兔丸攻击式神时，对其使用一张不明食材。'}
levels={247:[1,1,1,2,3,2,2,3],250:[1,1,1,2,2,2,3,3]}
forms={24703:(3,6,{'rtDeepSea':True}),24706:(4,5,{'rtTideShaper':True,'combatKeywords':['remote']}),24708:(6,6,{'rtEternal':True}),25002:(3,6,{'rtLonely':True}),25005:(4,7,{'rtTaste':True}),25007:(6,6,{'rtCookingSoul':True})}
actions={24701:'rt-spear-attack',24702:'rt-tide-dream',24704:'rt-call-tide',24705:'rt-awaken',24707:'rt-spear-hunt',25001:'rt-rabbit-combat',25003:'rt-recipe',25004:'rt-awaken',25006:'rt-rabbit-combat',25008:'rt-rabbit-combat'}
cards={}
for num,text in texts.items():
 c={'verifiedRules':True,'rabbitTideRules':True,'type':'spell','typeLabel':'法术牌','level':levels[num//100][num%100-1],'cost':1,'copies':2,'deckLimit':2,'target':'auto','text':text,'officialText':text,'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':[s['id'] for s in sources],'verificationPending':pending}
 action=actions.get(num,'rt-form');value=0
 if num in forms:
  atk,hp,flags=forms[num];c.update(type='form',typeLabel='形态牌',formRules=flags,formAbility=text);value={'attack':atk,'hp':hp,'setBase':True}
 if num in [25001,25006,25008]:
  atk,shield={25001:(1,1),25006:(2,0),25008:(2,2)}[num];value=atk;c.update(type='combat',typeLabel='战斗牌',responseAction='assault',combatOption={'shield':shield})
 if num==25001:c['rtForage']=True
 if num==25006:c['combatOption']['immuneCombat']=True
 if num==25008:c['combatOption']['pierce']=True;c['keywords']=['pierce'];c['rtFoodOnAttack']=True
 if num in [24705,25004]:value={'attack':1,'hp':1}
 if num==25003:c['keywords']=['instant']
 if num in [24702,25007]:c['target']='any-living-unit'
 if num in [24704,24707]:c['target']='enemy-unit'
 if num==25007:c['rtEntryFood']=True
 c.update(effect=action,value=value,effects=[{'action':action,'target':'selected' if c['target']!='auto' else 'source','value':value}]);cards[f'c{num}']=c
# Derivative body/full spell data are supplied separately only when evidenced.
derivatives_path=out/'spear-definitions.json'
new={'units':[],'cards':[]}
if derivatives_path.exists():
 new=json.loads(derivatives_path.read_text())
 for c in new.get('cards',[]):cards[c['id']]=c
 for u in new.get('units',[]):units[u['id']]=u
(out/'new_definitions.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps([c for c in raw if int(c.get('role',0)) in [247,250]],ensure_ascii=False,indent=2)+'\n')
manifest=[]
for num in texts:
 p=next((root/'art-reference-official/卡面-按版本/13_喧哗烩战').glob(f'{num//100}_*/{num}_*.png'));target=root/f'godot/assets/official/cards/c{num}.png'
 manifest.append({'source':str(p.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
token_source=out/'spear-related-card.png'
if token_source.exists():
 token_target=root/'godot/assets/official/tokens/qianji-spear.png';token_target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(token_source,token_target)
print(f'RABBIT_TIDE_PREPARED main=16 derivatives={len(new["cards"])}')
