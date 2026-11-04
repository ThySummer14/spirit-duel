import json
from pathlib import Path
out=Path(__file__).parent
sources=[
 {'id':'tomato-fire-official-guides-2020','url':'https://www.taptap.cn/moment/15206247968014725','title':'官方式神百谈跳跳妹妹；作者西园寺世界（2020-03-24），基础费用/召唤/连击/+3/+3觉醒牌面'},
 {'id':'fire-official-guide-2020','url':'https://www.taptap.cn/moment/15216199386268975','title':'官方百闻小课堂不知火；作者狸猫会一波啊丶（2020-04-21），初会伤害事件/烬染随机攻击/19随机效果'},
 {'id':'fire-swan-table-2020','url':'https://www.taptap.cn/moment/15217826067382434','title':'官方小课堂次日转载完整19效果表；与原帖同图，原始图存references/swan-19-effects.jpg'},
 {'id':'fire-balance-2020-08-20','url':'https://ssr.163.com/news/update/20200819/30294_900059.html','title':'官网2020-08-20常规平衡：真意瞬发鼓舞+1/+1并重置；自由迅捷+2/+2；星火二勾'},
 {'id':'tomato-balance-2020-10-29','url':'https://ssr.163.com/news/update/20201028/30294_912564.html','title':'官网2020-10-29常规平衡：坐下召唤番茄并永久+1力量'},
 {'id':'tomato-revival-fix-2020-03-27','url':'https://ssr.163.com/news/update/20200327/30294_871653.html','title':'官网气绝妹妹使用不玩了啦少支付鬼火修复'},
 {'id':'fire-balance-2023-11-23','url':'https://www.taptap.cn/moment/476492882555962569','title':'官方常规平衡：觉醒不知火增加本回合鼓舞贯通；烬染基础1/1->2/2'},
 {'id':'tomato-balance-2025-02-20','url':'https://www.taptap.cn/moment/641946893718388989?group_id=188707','title':'官方2025-02-20标准天梯长图：觉醒番茄随机获得战斗牌1->2张；觉醒非战斗全替换未变'},
 {'id':'tomato-fire-card-snapshot','url':'https://ssr.res.netease.com/pc/zt/20200309143407/data/cards.json','title':'原始牌面资料快照；数值需结合更新，不可单独判定最终版本'},
 {'id':'fire-keyword-author-2023','url':'https://www.taptap.cn/moment/467093870207830538','title':'关键词原作者鼓舞/本回合迅捷时限说明（2023-10-29）'}
]
base={'sources':sources,'units':{},'cards':{}}
common={'passive':{'id':'verified-tomato-fire','name':'原版能力','text':'','hooks':[]},'awakenedPassive':{'id':'verified-tomato-fire-awake','name':'原版觉醒','text':'','hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':[]}
base['units']['tiaotiaomeimei']={**common,'attack':3,'maxHp':6,'tomatoFireRole':'sister','summonStats':{'attack':4,'hp':4},'officialAbility':'跳跳妹妹出击或使用战斗牌额外消耗1点鬼火。','verificationPending':['番茄基础属性：官方早期快照4/4与2021原作者3/4冲突，待视频/后续官方牌面核定；暂用快照4/4。']}
base['units']['buzhinhuo']={**common,'attack':2,'maxHp':4,'tomatoFireRole':'fire','summonStats':{'attack':2,'hp':2},'officialAbility':'己方回合开始时，鼓舞：获得+1力量。'}
base['units']['fanqie']={**common,'tomatoFireRole':'tomato-roster','officialAbility':'唯一。享受跳跳妹妹法术牌对番茄的永久效果。','verificationPending':['原版番茄为召唤物；旧库独立番茄角色及其8张w11构筑牌无官方来源，不认定为真实构筑。','召唤番茄属性4/4与3/4版本冲突待核定。']}
base['units']['jinran-buye']={**common,'attack':2,'maxHp':2,'tomatoFireRole':'burn','officialAbility':'迅捷。攻击时改为对两个随机敌方角色造成等同于自身力量的伤害。','verificationPending':['原版烬染不夜为召唤物；旧库独立角色及其8张w11构筑牌无官方来源，不认定为真实构筑。','随机两个角色是否允许重复及召唤物参与式神范围，待新版实机核定。']}
def card(id,text,action,value=None,**extra):
 d={'verifiedRules':True,'text':text,'officialText':text,'cost':1,'target':'auto','effect':action,'value':value,'effects':[{'condition':'always','action':action,'target':'source','value':value}],'keywords':[],'timing':'main','responseTo':[],'sources':[s['id'] for s in sources],'verificationPending':[]}
 d.update(extra);base['cards'][id]=d;return d
card('c14601','本次攻击+3力量。贯通。','assault',3,keywords=['pierce'],tomatoFireRule='combat')
card('c14602','召唤「番茄」并使其攻击。','tomato-summon',tomatoFireRule='summon-attack')['effects'][0]['attack']=True
card('c14603','召唤「番茄」并使其永久获得+1力量。','tomato-sit',tomatoFireRule='sit')
card('c14604','连击：本次战斗额外先攻击一次。','assault',0,keywords=['combo'],tomatoFireRule='combat')
card('c14605','瞬发。召唤「番茄」。响应：当跳跳妹妹被攻击时，自动使用此牌。','tomato-summon',keywords=['instant'],autoResponse='source-attacked',responseModifiesCombat=True,tomatoFireRule='guard')
card('c14606','气绝时可用。复活跳跳妹妹。本次攻击+2力量/+2护甲。','tomato-revive',allowKnockedSource=True,combatOption={'shield':2},tomatoFireRule='revive')['effects'].append({'condition':'source-ready','action':'assault','target':'source','value':2})
card('c14607','召唤「番茄」并使其永久获得「攻击造成伤害时，随机对另一个敌方角色造成3点伤害」。（效果可叠加）','tomato-out',tomatoFireRule='out',verificationPending=['攻击伤害触发是否包含反击，待最新版实机核定。当前按真实战斗伤害包括反击处理。'])
card('c14608','随机将两张跳跳妹妹的战斗牌置入手牌。+3力量/+3生命。觉醒：跳跳妹妹替换成「番茄」，并将所有她的非战斗牌随机替换成战斗牌。','tomato-awaken',{'attack':3,'hp':3},tomatoFireRule='awaken-tomato',verificationPending=['觉醒数值+3/+3由2020官方牌面证实，尚未取得2025最新牌面确认数值未改。'])
def form(id,text,attack,hp,rules):
 d=card(id,text,'form',{'attack':attack,'hp':hp,'setBase':True},tomatoFireRule='form',formRules=rules,formHooks=[],formAbility=text);return d
form('c16701','4力量/5生命。你的出击加成效果在使用战斗牌时也生效。',4,5,{'encourageCombat':True})
card('c16702','使一个己方式神本回合获得迅捷。鼓舞：获得+2力量/+2护甲。','fire-freedom',target='ally-unit',tomatoFireRule='freedom',encourage={})
card('c16703','瞬发。鼓舞：获得+1力量/+1护甲。重置你的出击次数。','fire-truth',keywords=['instant'],tomatoFireRule='truth')
form('c16704','2力量/6生命。远程。当己方式神出击并对敌方牌手造成伤害时，抽一张牌。',2,6,{'drawBasicAvatarDamage':True,'combatKeywords':['remote']})
card('c16705','召唤一个「烬染不夜」。','fire-spark',level=2,tomatoFireRule='spark',verificationPending=['随机两个敌方角色是否允许重复及召唤物参与式神范围，待新版实机核定。'])
form('c16706','5力量/5生命。你的出击加成效果不会因出击而消耗。',5,5,{'retainEncourage':True})
form('c16707','7力量/7生命。每个回合开始时，随机触发一个效果。',7,7,{'swanRandom':True})['verificationPending']=['已实现官方小课堂19效果表；各回合随机池分布、除表中明确永久/一回合外的效果时限，尚缺最新实机；临时属性当前按本回合处理。']
card('c16708','+1力量/+1生命。鼓舞：本回合获得贯通。觉醒：己方回合开始时，鼓舞获得+1力量。你的鼓舞效果额外获得+1力量与+1护甲。','fire-awaken',{'attack':1,'hp':1},tomatoFireRule='awaken-fire',verificationPending=['多名同角色觉醒叠加及觉醒当次鼓舞与能力替换次序按牌文顺序实现，待全同变体原版实机核定。'])
card('fanqie','唯一。番茄召唤物；离开战斗区时移除。','tomato-summon',tomatoFireRule='derived',verificationPending=['此ID仅展示原版召唤物；原版不生成可使用的0费法术手牌。旧库导入手牌兼容使用仍待核定。'])
card('jinran-buye','迅捷。烬染不夜2/2召唤物；攻击改为对两个随机敌方角色造成等同于力量的伤害。','fire-spark',tomatoFireRule='derived',verificationPending=['此ID仅展示原版召唤物；原版不生成可使用的0费法术手牌。旧库导入手牌兼容使用仍待核定。'])
content=json.load(open('godot/content/content.json'))
for c in content['cards']:
 if c['unitId'] in ['fanqie','jinran-buye']:
  base['cards'][c['id']]={'sources':[],'verificationPending':['旧库独立衍生角色的构筑牌无原版牌文/官方来源；保留入口但尚未还原，不属于本轮16张真实构筑牌。']}
(out/'overlay.json').write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
