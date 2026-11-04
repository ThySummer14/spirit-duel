import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
x=json.loads((root/'godot/content/content.json').read_text())
raw={c['id']:c for c in x['cards']}
sources=[
 {'id':'paper-transform-20200928','url':'https://www.taptap.cn/moment/59609610805317142','evidence':'官方机制调整：变形身份仍算原式神，继承等级与升级变化，无法使用自己的卡牌。'},
 {'id':'fortune-pair-snapshot','path':'research-data/cards.json','evidence':'12600–12609、12700–12712官方牌库快照（research-data/card表README记录抓取来源），公告优先覆盖。'},
 {'id':'rabbit-guide-20200226','url':'https://www.taptap.io/post/243739','evidence':'官方攻略发布原作者西园寺世界：觉醒山兔整条能力投两次；纸人3/3、小纸人1/1，移除初始/觉醒/形态能力；友方任意六点累计。'},
 {'id':'rabbit-win-20210729','url':'https://www.taptap.cn/moment/169528710922242294','evidence':'官方常规平衡调整：这把算我赢改为二勾、瞬发，山兔下一投骰必六；10六点特殊胜利。'},
 {'id':'frog-door-20200428','url':'https://www.taptap.cn/moment/15226566611042541','evidence':'官方攻略区原作者西园寺世界对2020-04-23调整解读：门前清新增出击时运势4护甲。'}]
v={'schema':1,'sources':sources,'units':{},'cards':{}}
base_pending=['用户录像未直接展示本组所有卡牌及随机结算；官方快照和2020/2021公告核对完成，尚缺2021之后逐公告穷尽式版本核验。']
for uid,role,ability,awake in [
 ('qingwa-ciqi','frog','青蛙瓷器在你运势判定成功过的回合获得2力量。','青蛙瓷器在你运势判定成功过的回合获得2力量。你运势判定成功后效果触发两次。'),
 ('shantu','rabbit','己方回合开始时，运势6：其他己方式神的倒计时-1并获得1力量。','己方回合开始时，运势6：其他己方式神的倒计时-1并获得2力量，然后重复一次。')]:
 v['units'][uid]={'fortuneRole':role,'formLifecycle':{},'officialAbility':ability,'passive':{'name':'基础能力','text':ability,'hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':awake,'hooks':[]},'sources':[s['id'] for s in sources], 'verificationPending':base_pending}
def put(id,action=None,target='auto',value=0,**kw):
 c=raw[id]
 d={'verifiedRules':True,'fortunePair':True,'text':c['officialText'].replace('#[力量]','力量').replace('#[生命]','生命').replace('#r','\n'),'target':target,'effect':action or c['effect'],'value':value,'effects':[{'condition':'always','action':action or c['effect'],'target':target,'value':value}], 'keywords':[],'timing':'main','responseTo':[],'formHooks':[],'formRules':{},'formAbility':'','sources':[s['id'] for s in sources], 'verificationPending':base_pending}
 d.update(kw);v['cards'][id]=d;return d
put('c12601','fortune-combat',keywords=['fortune'],fortuneCombat=True,combatOption={'shield':1})
put('c12602','form',value={'attack':2,'hp':9,'setBase':True},text='2力量/9生命。当青蛙瓷器出击或被攻击时，运势4：获得2点护甲。',formRules={'fortuneAttackArmor':True})
put('c12603','form',value={'attack':2,'hp':7,'setBase':True},formRules={'fortunePermanentPower':1})
put('c12604','fortune-dice-damage',keywords=['fortune'],target='enemy-character',text='运势1：对一个敌方角色造成等同于骰子点数的伤害。')
put('c12605','assault',keywords=['fortune'],value=0,fortuneReplay=True,combatOption={})
put('c12606','awaken',value={'attack':2,'hp':2})
put('c12608','form',value={'attack':3,'hp':3,'setBase':True},fortuneEnhancement='distinct-body')
put('c12609','fortune-combat',keywords=['fortune','response'],fortuneCombat=True,fortuneImmune=True,combatOption={},autoResponse='source-attacked',responseModifiesCombat=True)
put('c12701','damage-enemy-front',value=2,keywords=['instant','projectile'],fortuneEnhancement='sixes-projectile',text='瞬发。投射：造成2点伤害。增强：本局游戏你骰子每投出一次6点，此牌效果+1。')
put('c12702','buff-stats',target='any-unit',value={'attack':1,'hp':1},fortuneEnhancement='sixes-blessing')
put('c12706','form',text='6力量/6生命。增强：本局游戏若你骰子投出三次6点，此牌获得不屈。',value={'attack':6,'hp':6,'setBase':True},fortuneEnhancement='sixes-unyielding',formRules={'fortuneUnyielding':False})
put('c12707','awaken',value={'attack':1,'hp':1})
put('c12708','form',value={'attack':6,'hp':6,'setBase':True},fortuneEnhancement='sixes-body',formRules={'alwaysSix':True})
put('c12710','fortune-win',level=2,keywords=['instant'],text='瞬发。山兔下一次投骰子必定会投出6点。增强：本局游戏若你骰子投出十次6点，则你获得本局游戏的胜利。')
put('c12711','fortune-transform',keywords=['response'],autoResponse='source-attacked',text='将敌方战斗区式神变成3力量/3生命的「纸人」，失去形态及式神能力（含觉醒）。增强：本局投出三次6点，改为1力量/1生命「小纸人」。响应：山兔被攻击时自动使用。',verificationPending=base_pending+['变形与所有其他扩展角色的特殊存储状态、永久能力、外源重结附形态和复活恢复顺序尚缺原版实机联动证据。'])
put('c12712','fortune-force-attack',target='enemy-unit',verificationPending=base_pending+['强制攻击与远程、激怒、禁止位移等关键词组合需原版实机逐项核对。'])
for c in v['cards'].values():
 import re
 c['text']=re.sub(r'&[0-9]+','',c['text'])
 c['formAbility']=c['text'] if c['effect']=='form' else ''
 c['ruleFidelity']={'status':'source-backed-pending','pending':c['verificationPending']}
Path(__file__).with_name('overlay.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
print('FORTUNE_PAIR_OVERLAY',len(v['units']),len(v['cards']))
