import json
from pathlib import Path
base=Path(__file__).resolve().parents[2]
c=json.loads((base/'godot/content/content.json').read_text())
sources=[
 {'id':'poison-snake-balance-2020-06-24','url':'https://ssr.163.com/news/update/20200623/30294_888590.html','evidence':'常规平衡：蛇行击改2伤，使用后回手并失去该能力；覆盖旧1伤标记成长。'},
 {'id':'poison-pair-card-snapshot','path':'research-data/cards.json','evidence':'11400–11409、11500–11508 普通经典版牌文；以有模式归属的官方后续公告覆盖。'},
 {'id':'poison-pair-balance-2020-02-27','url':'https://ssr.163.com/news/update/20200226/30294_866061.html','evidence':'常规平衡：喷泉改为转移；瘴疠力量3，肿胀力量4。原始 HTML 已归档。'},
 {'id':'poison-pair-balance-2021-11-25','url':'https://www.taptap.cn/moment/212634043550796949','evidence':'常规平衡：肿胀体质4/16，进场获得2破甲。'},
 {'id':'poison-pair-mode-2023-03-09','url':'https://www.taptap.cn/moment/382609474805825905','evidence':'觉醒清姬全体1伤、剧毒之盾屏障投射、喷泉自身1破甲属于有个牌局调整；未推广常规。'},
 {'id':'poison-pair-jumper-guide','url':'https://www.taptap.cn/moment/15221946199312146','evidence':'官方攻略组跳跳弟弟百科：承伤/永久生命、破甲角色仍可被萤草回复。'},
 {'id':'poison-pair-tank-analysis','url':'https://www.taptap.cn/moment/15221196425529867','evidence':'狸猫会原作者：腐坏直拳相当至少+2伤；甜蜜的负担护牌手，尸毒受到超14伤仍触发。'},
 {'id':'poison-pair-control-analysis','url':'https://www.taptap.cn/moment/15227166597842769','evidence':'狸猫会原作者：公测清姬改为未破甲转换、剧毒之盾战斗伤害后破甲、形态时机。'},
 {'id':'poison-pair-priority-analysis','url':'https://www.taptap.cn/moment/467093870207830538','evidence':'原作者机制记录：伤害转换优于伤害转移/通常防护，破甲不是中毒。'}]
common={'verifiedRules':True,'poisonRules':True,'sources':[x['id'] for x in sources[:7]],'verificationPending':[]}
units={}
for uid,r,text,awak in [('tiaotiaodidi','jumper','当跳跳弟弟受到伤害时，获得等量的破甲。','当跳跳弟弟受到伤害时，获得等量的破甲并永久获得1生命。'),('qingshe','snake','清姬对无破甲角色造成的伤害会转化为等量的破甲。','清姬对无破甲角色造成的伤害会转化为等量的破甲。敌方角色的破甲不会在回合开始时清除。')]:
 units[uid]={'verifiedRules':True,'armorBreakRole':r,'passive':{'id':uid+'-native','name':'腐毒之体' if r=='jumper' else '蛇毒转化','text':text,'hooks':[]},'awakenedPassive':{'id':uid+'-awake-native','name':'尸毒觉醒' if r=='jumper' else '焚身之毒','text':awak,'hooks':[]},'sources':common['sources'],'verificationPending':[]}
cards={}
def put(id,text,action=None,value=0,target='auto',**kw):
 d=dict(common,text=text,target=target,timing='main',responseTo=[],formHooks=[],formRules={},combatOption={},copies=2,deckLimit=2)
 if action is not None:d.update(effect=action,value=value,effects=[{'condition':'always','action':action,'target':'source' if target=='auto' else 'selected','value':value}])
 d.update(kw)
 response={'poison-punch':'assault','poison-stiff':'assault','poison-snake-strike':'damage','poison-toxin':'damage','poison-scorch':'damage','poison-shield':'shield','poison-fountain':'apply-armor-break','poison-awaken':'awaken'}
 if action in response:d['responseAction']=response[action]
 cards[id]=d

def form(id,text,atk,hp,rules):
 put(id,text,'form',{'attack':atk,'hp':hp,'setBase':True},formRules=rules,formAbility=text)
put('c11401','本次获得2破甲。将自己的破甲转移到被攻击的式神上。','poison-punch',0,keywords=[])
form('c11402','对跳跳弟弟造成战斗伤害的式神获得3破甲。',3,9,{'breakCombatAttacker':True})
put('c11403','将跳跳弟弟的破甲转移到所有敌方式神上。增强：若己方回合开始你的战斗区有式神，此牌得瞬发。','poison-fountain',0,poisonFountain=True,keywords=[])
form('c11404','进场时使跳跳弟弟获得2破甲。跳跳弟弟的破甲在己方回合开始时不会清除。',4,16,{'entryArmorBreak':2,'retainOwnArmorBreak':True})
form('c11405','当跳跳弟弟受到≥6的伤害时，所有敌方角色获得3破甲。当跳跳弟弟受到≥15的伤害时，敌方牌手获得10破甲。',5,14,{'corpseThresholds':True})
put('c11406','瞬发，贯通。获得等同于自己破甲的本次力量。','poison-stiff',0,keywords=['instant','pierce'])
put('c11408','觉醒：当跳跳弟弟受到伤害时，获得等量的破甲并永久获得1生命。','poison-awaken',{'attack':1,'hp':1},type='spell',typeLabel='法术牌',keywords=['awaken'])
put('c11409','瞬发。本次+3力量。响应：当你的牌手被攻击时，自动使用此牌并使跳跳弟弟抵挡本次攻击。','assault',3,autoResponse='avatar-attacked',responseModifiesCombat=True,poisonGuard=True,keywords=['instant','response'])
put('c11501','瞬发。对一个式神造成2点伤害。使用后将此牌回手并失去此能力。','poison-snake-strike',2,'any-living-unit',keywords=['instant'])
put('c11502','对所有敌方角色造成2点伤害。','poison-toxin',2,keywords=[])
form('c11503','敌方回合结束时，敌方战斗区式神获得2破甲。',4,6,{'breakEnemyFrontAtEnd':True})
put('c11504','瞬发。投射：造成4点伤害。','damage-enemy-front',4,keywords=['instant','projectile'])
put('c11505','使一个角色获得2破甲，然后对所有拥有破甲的敌方角色造成3点伤害。','poison-scorch',3,'any-living-character',keywords=[])
put('c11506','觉醒：清姬对无破甲角色造成的伤害转化为等量破甲。敌方角色的破甲不会在回合开始时清除。','poison-awaken',{'attack':2,'hp':2},type='spell',typeLabel='法术牌',keywords=['awaken'])
put('c11507','使一个己方式神获得2护甲且本回合获得「使受到它战斗伤害的式神获得3破甲」。响应：当你战斗区式神被攻击时，自动对其使用。','poison-shield',2,'ally-unit',autoResponse='front-attacked',keywords=['response'])
form('c11508','敌方回合开始时使所有敌方角色获得1破甲。敌方有破甲的式神降低等于其破甲的力量。',4,9,{'breakEnemyTurnStart':True,'breakWeakensEnemy':True})
for id,notes in {
 'c11403':['增强瞬发在持牌副本上永久保留，后来抽到不追溯；缺指定录像对应操作片段。'],
 'c11405':['致命伤害仍触发形态阈值；觉醒致命受伤成长只加上限不复活，缺指定录像对应边界。'],
 'c11409':['直击牌手时改目标到准备区跳跳弟弟；与其他护脸响应优先级缺同局实测。'],
 'c11506':['觉醒保留破甲要求清姬能力有效；气绝期间失效，缺指定录像对应边界。']}.items(): cards[id]['verificationPending']=notes
units['tiaotiaodidi']['verificationPending']=cards['c11405']['verificationPending']
units['qingshe']['verificationPending']=['与毒蚀双向战斗转换、必杀/屏障同时出现时的精确替换优先级待实机对照。']
(base/'output/parallel-poison-pair-20261013/overlay.json').write_text(json.dumps({'schema':1,'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
