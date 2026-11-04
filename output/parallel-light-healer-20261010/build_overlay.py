import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
snapshot={str(c['id']):c for c in json.loads((root/'research-data/cards.json').read_text())}
out={'sources':[{'id':'light-healer-snapshot','path':'research-data/cards.json','evidence':'12500–12508、12900–12909、13000–13008 官方牌库快照；后续官方公告覆盖旧数值。'},{'id':'light-guide','url':'https://www.taptap.cn/moment/15221943921806134','evidence':'2019官方百科：明灯、吸魂灯与储火；不灭之火准备区说法与2020原作者说明冲突。'},{'id':'monk-guide','url':'https://www.taptap.cn/moment/15229053053176185','evidence':'原作者逐卡说明：牌手恢复触发、禅心每回合一次、佛光两次回复与敌方目标。佛印沿用公测 snapshot 的4点，不沿用文中旧5点。'},{'id':'fortune-guide','url':'https://www.taptap.cn/moment/15227915461463202','evidence':'原作者座敷童子逐卡说明：双方运势、进离场鬼火、福满乾坤。'},{'id':'light-healer-balance-20230309','url':'https://www.taptap.cn/moment/382609474805825905','evidence':'官方公告：轮回改为被对手伤害次数；觉醒座敷童子改为二勾与+1/+1。'},{'id':'fortune-fix-20230427','url':'https://www.taptap.cn/moment/400381140478722737','evidence':'官方修复福满乾坤可重置中毒牌手生命值；中毒角色跨系统联动仍保留待核对。'}], 'units':{}, 'cards':{}}
for id,num,role in [('qingfangzhu',12500,'monk'),('qingxingdeng',12900,'lantern'),('zuofutongzi',13000,'fortune')]:
 c=snapshot[str(num)]; desc=c['desc'].replace('[','').replace(']','')
 out['units'][id]={'attack':c['ll'],'maxHp':c['sm'],'officialAbility':desc,'passive':{'name':'基础能力','text':desc,'hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':snapshot[str(num+9 if num==12900 else num+6 if num==12500 else num+5)]['desc'],'hooks':[]},'lightRole':role,'formLifecycle':{},'sources':['light-healer-snapshot','light-healer-balance-20230309']}
out['units']['qingfangzhu']['awakenedPassive']['text']='当你恢复生命时，对所有敌人造成1点伤害。'
out['units']['qingxingdeng']['awakenedPassive']['text']='对手回合开始时若你有剩余鬼火，获得一张明灯。你的鬼火不会自动清除，最大可储存4点。'
out['units']['zuofutongzi']['awakenedPassive']['text']='每次运势判定中，当你运势判定失败时，重投一次。'
def card(num,action,value=0,target='auto',text=None,kw=None,**extra):
 c=snapshot[str(num)]; desc=text or c['desc'].replace('#r','。').replace('&4+{法强值}&','4').replace('&3+{法强值}&','3').replace('&8+{法强值}&','8').replace('#[力量]','力量').replace('#[生命]','生命').replace('[','').replace(']','')
 o={'verifiedRules':True,'type':'form' if c['type']=='形态' else 'spell','typeLabel':c['type']+'牌','level':c['stage'],'cost':c['ghxh'],'timing':'main','responseTo':[],'keywords':kw or [],'target':target,'text':desc,'officialText':desc,'formHooks':[],'formRules':{},'formAbility':desc if c['type']=='形态' else '', 'effect':action,'value':value,'effects':[{'condition':'always','action':action,'target':target,'value':value}],'sources':['light-healer-snapshot','light-healer-balance-20230309']}
 o.update(extra); out['cards']['c'+str(num)]=o
 return o
def form(num,rules):
 c=snapshot[str(num)]; return card(num,'form',{'attack':c['ll'],'hp':c['sm'],'setBase':True},formRules=rules)
card(12501,'monk-seal',kw=['instant'])
form(12502,{'monkHealDraw':True})
card(12503,'monk-light',target='any-living-character')
card(12504,'grant-unyielding',1,'ally-unit')
form(12505,{'enemyHealingIsDamage':True})
card(12506,'monk-awaken',type='awakening')
card(12507,'monk-sacrifice',kw=['instant'],autoResponse='avatar-lethal')
card(12508,'monk-rebirth',text='你的生命变为10。增强：本局游戏你每被对手伤害过一次，此牌效果+1。')
card(12901,'light-fire',1,kw=['instant'],lightLantern=True)
card(12902,'lantern-choice',verificationPending=['青灯夜谈未选中牌的放回顺序与官方录像仍待交叉验证；当前保持原牌库相对顺序。'])
card(12903,'lantern-level',target='lowest-ally-unit',verificationPending=['早期官方百科为随机最低等级；牌库快照已去掉随机，按指定最低等级实现，仍需视频版本确认。'])
form(12905,{'lanternCombatFire':True})
form(12906,{'lanternImmortal':True})['verificationPending']=['2019百科称返回准备区，2020原作者称原区域复生；当前采用较新原区域，缺指定录像直接证明。']
card(12907,'lantern-drain',kw=['projectile'])
form(12908,{'lanternEndFire':True})
card(12909,'light-awaken',{'attack':1,'hp':1},type='awakening')
for n,r in [(13001,{'fortuneTurnStart':'draw'}),(13002,{'fortuneTurnStart':'heal'}),(13003,{'fortuneStunAfterAttack':True}),(13006,{'fortuneZeroAttack':True}),(13007,{'fortuneEntryExitFire':True})]:form(n,r)
card(13004,'fortune-fire')
card(13005,'light-awaken',{'attack':1,'hp':1},level=2,type='awakening')
out['cards']['c13007']['fortuneEnhanceOnForm']=True
card(13008,'fortune-reset',text='增强：本局游戏若双方运势判定成功15次，则双方生命变为30，抽手牌直至十张，获得3点鬼火。',verificationPending=['官方2023-04-27明确中毒不能重置生命；中毒状态尚无统一入口，当前预留avatarHealingBlocked，跨中毒角色联动未验证。'])
out['cards']['mingdeng']=dict(out['cards']['c12901'],cost=1)
out['sources'].append({'id':'light-guide-2020','url':'https://www.taptap.cn/moment/15228324829724689','evidence':'2020原作者式神百谈：不灭之火原区域复生、百闻一得指定最低等级、百物语之火先得鬼火后得明灯。'})
out['cards']['c12906']['sources'].append('light-guide-2020')
out['cards']['c12903']['sources'].append('light-guide-2020')
(root/'output/parallel-light-healer-20261010/overlay.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
