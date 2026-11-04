from pathlib import Path
import json
v=Path('godot/content/verified_rules.json');x=json.loads(v.read_text())
sources=['huang-cardmaker-20261015','huang-cardmaker-images-20261015','huang-moon-bugfix-20201126']
entries=[
 {'id':sources[0],'url':'https://ssr.163.com/cardmaker/','asset':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','retrieved':'2026-10-15','evidence':'本次直接获取官方内嵌17800–17808数据；9月25日版本提示无年份，不据此推定已覆盖后续全部公告。'},
 {'id':sources[1],'url':'https://ssr.res.netease.com/pc/zt/20191112204330/data/card/17803.png?15','moonUrl':'https://ssr.res.netease.com/pc/zt/20191112204330/data/card/17806.png?15','retrieved':'2026-10-15','evidence':'本次直接目检官方荒海、月坠牌面，补足@1780302文本与月坠每己方回合+3。'},
 {'id':sources[2],'url':'https://www.taptap.cn/moment/80802089336308748','evidence':'官方普通BUG修复：月坠触发后不能因耐久降低而不移除。'}]
x['sources']=[s for s in x['sources'] if s['id'] not in sources]+entries
pending=['指定录像未展示荒全组完整结算，后续普通维护公告未穷尽；保留当前官网快照与早期测试版差异，不宣称全组完整还原。','幻境同名共存/替换和数量上限、使用幻境时迅捷与命运螺旋的精确先后、无幻境手牌时余辉可用性及星辰之境离手后的增强变化，仍需当前原版实机核验。']
x['units']['huang']={'huangRealmGrowth':True,'formLifecycle':{},'attack':2,'maxHp':6,'officialAbility':'每当荒造成战斗伤害时，使己方所有幻境获得1耐久。','passive':{'name':'基础能力','text':'每当荒造成战斗伤害时，使己方所有幻境获得1耐久。','hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':'每当荒造成战斗伤害时，使己方所有幻境获得1耐久。每当你使用幻境牌时，荒获得迅捷。','hooks':[]},'sources':sources,'verificationPending':pending}
cards=[
 ('c17801','realm',1,'贯通。己方回合开始时，投射：造成等同于它耐久的伤害，然后自毁。','realm',0,{'realm':{'hp':4,'nativeRealm':'huang-track','trigger':'native-turn-start','avatarLinked':True},'keywords':['pierce','projectile']}),
 ('c17802','spell',2,'弃一张幻境牌，然后抽三张牌。','huang-discard-draw',0,{}),
 ('c17803','realm',1,'瞬发。被消灭时，将此牌回手并失去此能力。','realm',0,{'realm':{'hp':1,'nativeRealm':'huang-sea','trigger':'native-continuous','avatarLinked':True,'returnOnDestroy':True},'keywords':['instant']}),
 ('c17804','realm',2,'己方回合开始时，随机对一个敌方角色造成2点伤害，重复耐久次，然后自毁。','realm',0,{'realm':{'hp':4,'nativeRealm':'huang-meteor','trigger':'native-turn-start','avatarLinked':True}}),
 ('c17805','form',2,'增强：你每有一个幻境，此牌便获得1力量和1生命。','form',{'attack':5,'hp':5,'setBase':True},{'huangBody':True}),
 ('c17806','realm',3,'当此牌获得耐久时，效果+2。己方回合开始时获得3耐久，然后若耐久≥30则自毁并对所有敌方角色造成10点伤害。','realm',0,{'realm':{'hp':15,'nativeRealm':'huang-moon','trigger':'native-turn-start','avatarLinked':True}}),
 ('c17807','form',3,'当你使用幻境牌时，使荒发动攻击且免疫本次战斗伤害。','form',{'attack':5,'hp':8,'setBase':True},{'formRules':{'huangSpiral':True}}),
 ('c17808','awakening',2,'觉醒：每当荒造成战斗伤害时，使己方所有幻境获得1耐久。每当你使用幻境牌时，荒获得迅捷。','huang-awaken',{'attack':1,'hp':1},{})]
for id,t,lv,txt,action,val,extra in cards:
 c={'verifiedRules':True,'huangRules':True,'type':t,'typeLabel':{'realm':'幻境牌','spell':'法术牌','form':'形态牌','awakening':'觉醒牌'}[t],'level':lv,'cost':1,'copies':2,'deckLimit':2,'text':txt,'officialText':txt,'effect':action,'value':val,'target':'auto','effects':[{'condition':'always','action':action,'target':'source' if t in ['form','awakening'] else 'auto','value':val}],'keywords':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':txt if t=='form' else '', 'combatOption':{},'tags':[],'sources':sources,'verificationPending':pending,'ruleFidelity':{'status':'source-backed-pending','pending':pending}}
 c.update(extra);x['cards'][id]=c
v.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
p=Path('scripts/godot-verify.sh');s=p.read_text().replace(' verify_armor_limit ',' verify_huang verify_huang_ui verify_armor_limit ');p.write_text(s)
