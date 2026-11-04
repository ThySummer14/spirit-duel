import json,pathlib
out=pathlib.Path(__file__).parent
sources=[
 {'id':'xuenv-official-snapshot','path':'research-data/cards.json','evidence':'10600及10602–10610原版牌文、觉醒+2/+1；过期流霰、本体和冰风暴数值由后续官方公告覆盖。'},
 {'id':'xuenv-original-guide','url':'https://www.taptap.cn/moment/15226776540151963','evidence':'官方攻略账号署名西园寺世界：八牌和雪球目标、瞬发；寒冰之盾眩晕受到其战斗伤害者；冰墙替换及离场规则。'},
 {'id':'xuenv-balance-20200723','url':'https://www.taptap.cn/moment/35106451286394490','evidence':'官方维护公告：雪女基础改2/5，冰风暴改3/5。'},
 {'id':'xuenv-balance-20210729','url':'https://www.taptap.cn/moment/169528710922242294','evidence':'官方维护公告：流霰改为对一个敌方角色自动用一张雪球，本局每从手牌用过一张额外重复一次；不再瞬发/消耗全部手牌。'},
 {'id':'xuenv-icewall-original','url':'https://www.taptap.cn/moment/143310130094541107','evidence':'原作者小果酱渣2021实测：冰墙0/4、受到实际战斗伤害眩晕攻击者、敌回合眩晕持续至其下回合末；冰风暴护甲挡住伤害不触发眩晕。'}]
base='每回合一次，当你眩晕敌方式神时，将一张「雪球」置入手牌。'
units={'xuenv':{'attack':2,'maxHp':5,'officialAbility':base,'passive':{'name':'基础能力','text':base,'hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':'眩晕受到雪女伤害的式神。'+base,'hooks':[]},'formLifecycle':{},'snowWoman':True,'sources':['xuenv-official-snapshot','xuenv-balance-20200723','xuenv-original-guide']}}
cards={}
def card(id,rule,text,action,target='auto',value=0,**kw):
 c={'verifiedRules':True,'type':'spell','typeLabel':'法术牌','cost':1,'timing':'main','responseTo':[],'keywords':[],'target':target,'text':text,'officialText':text,'formHooks':[],'formRules':{},'xuenvRule':rule,'effect':action,'value':value,'effects':[{'condition':'always','action':action,'target':target,'value':value}], 'sources':['xuenv-official-snapshot','xuenv-original-guide']}
 c.update(kw);cards[id]=c
card('c10602','shield','使一个己方式神获得2护甲，且本回合获得「眩晕受到其战斗伤害的式神」。响应：当你战斗区式神被攻击时，自动对其使用。','xuenv-shield','ally-unit',2,level=1,autoResponse='front-attacked',keywords=['response'])
card('c10603','collapse','消灭一个眩晕的式神，或眩晕一个未眩晕的式神。','xuenv-collapse','any-living-unit',level=2)
card('c10604','storm','每当敌方式神攻击后，对其造成1点伤害，然后眩晕受到此伤害的式神。','form',value={'attack':3,'hp':5,'setBase':True},level=2,type='form',typeLabel='形态牌',formRules={'snowstorm':True},formAbility='敌方式神攻击后，对其造成1伤害；造成实际伤害才眩晕。',sources=['xuenv-official-snapshot','xuenv-balance-20200723','xuenv-icewall-original'])
card('c10605','damage','造成3点伤害，将一张「雪球」置入手牌。','xuenv-damage','any-character',3,level=1)
cards['c10605']['effects'].append({'condition':'always','action':'xuenv-token','target':'ally-player','value':1})
card('c10606','awaken','永久获得+2力量/+1生命。觉醒：眩晕受到雪女伤害的式神。'+base,'xuenv-awaken',value={'attack':2,'hp':1},level=3)
card('c10607','flurry','对一个敌方角色使用一张「雪球」，本局游戏你每从手牌使用过一张「雪球」额外重复一次。','xuenv-flurry','enemy-character',level=3,sources=['xuenv-balance-20210729'])
card('c10609','wall','在战斗区召唤一个0/4冰墙。冰墙不能攻击；眩晕对其造成战斗伤害的式神；离开战斗区时移除。','xuenv-wall',level=1,sources=['xuenv-original-guide','xuenv-icewall-original'])
card('c10610','heart','将两张「雪球」置入手牌。本局游戏你所有「雪球」的伤害+1。','xuenv-heart',level=2)
card('xueqiu','snowball','瞬发。对一个敌方式神造成1点伤害。','xuenv-damage','enemy-unit',1,level=1,keywords=['instant'],snowball=True,sources=['xuenv-original-guide'])
# No matching frame has yet established these post-2021 rules in the reference recording.
# Preserve this evidence boundary rather than implying whole-library verification.
units['xuenv']['verificationPending']=['指定2026-10-04录像中未定位雪女出场片段，采用已检索到的最新正式公告与原作者实测；重复眩晕已眩晕目标是否再触发基础能力待同版本实机核验。']
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
