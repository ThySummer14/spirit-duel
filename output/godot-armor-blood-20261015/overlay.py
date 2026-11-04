from pathlib import Path
import json
p=Path('godot/content/verified_rules.json'); v=json.loads(p.read_text())
sources=[
 {'id':'armor-blood-snapshot','path':'research-data/cards.json','evidence':'17300–17308、17900–17908的正式卡库快照。后续公告覆盖旧描述；渴血之时为3/6，早期测试报道3/7不沿用。'},
 {'id':'whale-balance-20210826','url':'https://www.iyingdi.com/tz/post/5110863','evidence':'2021-08-26维护平衡公告转载：鲸骨·开基础+1/+1；觉醒新增回合开始按己方幻境数量获得护甲。尚未找到原始发布页。'},
 {'id':'blood-balance-20220126','url':'https://www.taptap.cn/moment/235144264613364682','evidence':'官方账号常规对战平衡：血怒增强改为任一牌手实际恢复；另调整吸魂灯、幽光之火、两张座敷形态和福满乾坤。'},
 {'id':'blood-damage-order-20201017','url':'https://www.iyingdi.com/tz/post/2309624','evidence':'规则集原作者实测与流程图：血蝠先消耗标记，护甲/破甲修正后转移，再分配贯通；清姬转破甲也会消耗标记。'},
 {'id':'moon-firsthand-20210817','url':'https://www.taptap.cn/moment/176762018076823292','evidence':'原作者攻略：血蝠之盾可施放敌方前排转移伤害到敌牌手；初拥给高攻或多战斗牌队友恢复。'},
 {'id':'realm-firsthand-20231029','url':'https://www.taptap.cn/moment/467093870207830538','evidence':'原作者机制记录：幻境依放置先后承伤；增强只在手牌获得；吸血含友伤，先伤害后恢复。'},
 {'id':'whale-release-analysis','url':'https://www.sohu.com/a/404733118_120099897','evidence':'署名安娜ですよ的2020-06-29逐卡分析转载，白骨之盾仅临时获得基础1力量，守护防多段，秘宝存续保护。'}]
known={s['id'] for s in v['sources']}
v['sources'] += [s for s in sources if s['id'] not in known]
refs=[s['id'] for s in sources]
pending=['指定录像未展示本组完整卡牌结算，后续常规公告尚未穷尽；不能据此宣称完整还原。','白骨之盾复制基础未觉醒能力、初拥跨阵营回复归属及血蝠与复杂减伤的当前版本边界仍待实机核验。','幻境同名副本的共存/替换细则及放置上限尚缺当前原版证据，本批保留按使用顺序独立入场，未宣称全幻境系统已还原。']
for uid,role,atk,hp,base,awake in [
 ('jiuciliang','whale',2,6,'久次良有护甲时获得1力量。','己方回合开始时，久次良获得等同于己方幻境数量的护甲。久次良获得等同于其护甲的力量。'),
 ('xixueji','vampire',3,4,'每当你恢复生命时，吸血姬获得1力量与1护甲。','每当你恢复生命时，吸血姬获得等量力量与护甲，每次最多5。')]:
 v['units'][uid]={'armorBloodRole':role,'formLifecycle':{},'attack':atk,'maxHp':hp,'officialAbility':base,'passive':{'name':'基础能力','text':base,'hooks':[]},'awakenedPassive':{'name':'觉醒能力','text':awake,'hooks':[]},'sources':refs,'verificationPending':pending}
def card(id,type,level,text,action,value=0,target='auto',keywords=None,**extra):
 d={'verifiedRules':True,'armorBloodRules':True,'type':type,'typeLabel':{'combat':'战斗牌','spell':'法术牌','form':'形态牌','realm':'幻境牌'}[type],'level':level,'cost':1,'copies':2,'deckLimit':2,'text':text,'officialText':text,'effect':action,'value':value,'target':target,'effects':[{'condition':'always','action':action,'target':target,'value':value}],'keywords':keywords or [],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','combatOption':{},'sources':refs,'verificationPending':pending,'ruleFidelity':{'status':'source-backed-pending','pending':pending},'tags':[]}
 d.update(extra);v['cards'][id]=d
card('c17301','combat',1,'吸血','assault',0,keywords=['life-steal'],combatOption={'lifeSteal':True})
card('c17302','spell',1,'使一个式神获得「下一次将受到的伤害改由其牌手承受」。\n响应：当你的式神被攻击时，自动对其使用。','blood-shield',target='any-living-unit',keywords=['response'],autoResponse='ally-attacked')
card('c17303','spell',1,'瞬发，吸血\n造成1点伤害。\n增强：每当任一牌手恢复生命时，此牌伤害+1。','blood-rage',1,'any-living-character',['instant','life-steal'],bloodRage=True,responseAction='damage')
card('c17304','spell',2,'瞬发\n对一个式神造成1点伤害，它本回合获得「造成战斗伤害时为你恢复等量生命」。','blood-embrace',1,'any-living-unit',['instant'],responseAction='damage')
card('c17305','form',2,'吸血','form',{'attack':3,'hp':6,'setBase':True},formRules={'combatKeywords':['life-steal']},formAbility='吸血')
card('c17306','combat',2,'增强：若你生命值为30，此牌获得连击。','assault',2,bloodScent=True,combatOption={'shield':1})
card('c17307','spell',3,'+1力量/+1生命。\n觉醒：每当你恢复生命时，吸血姬获得等量力量与护甲（每次最多5）。','armor-blood-awaken',{'attack':1,'hp':1})
card('c17308','form',3,'吸血\n你的法术牌获得吸血。','form',{'attack':5,'hp':8,'setBase':True},formRules={'combatKeywords':['life-steal'],'bloodSpellLifeSteal':True},formAbility='吸血。你的法术牌获得吸血。')
card('c17901','combat',1,'+0力量/+2护甲。','assault',0,combatOption={'shield':2})
card('c17902','realm',1,'每当己方式神受到伤害时，该式神获得1护甲。','realm',realm={'hp':6,'nativeRealm':'whale-guard','trigger':'native-continuous','avatarLinked':True})
card('c17903','spell',1,'使一个己方其他式神获得4护甲，并本回合获得久次良的基础能力。\n响应：当己方其他式神被攻击时，自动对其使用。','whale-shield',4,'ally-unit',['response'],autoResponse='other-ally-attacked',whaleShield=True)
card('c17904','form',2,'进场或己方回合开始时若你有幻境，久次良获得2护甲。','form',{'attack':4,'hp':6,'setBase':True},formRules={'whaleRealmArmor':2},formAbility='进场或己方回合开始时若你有幻境，获得2护甲。')
card('c17905','combat',2,'+1力量/+1护甲。\n增强：你每有一个幻境，此牌便获得+1力量与+1护甲。','assault',1,whaleOpen=True,combatOption={'shield':1})
card('c17906','form',3,'久次良和你的所有幻境获得帷幕。\n进场或己方回合开始时若你有幻境，己方所有式神获得3护甲。','form',{'attack':5,'hp':8,'setBase':True},formRules={'whaleRealmArmor':3,'whaleTeamArmor':True,'whaleRealmVeil':True,'combatKeywords':['veil']},formAbility='自身及己方幻境获得帷幕；有幻境时，进场及己方回合开始为所有己方式神提供3护甲。')
card('c17907','spell',3,'+1力量/+2生命。\n觉醒：己方回合开始时，获得等同己方幻境数量的护甲；久次良获得等同于其护甲的力量。','armor-blood-awaken',{'attack':1,'hp':2})
card('c17908','realm',3,'你的生命不会降到1以下。','realm',realm={'hp':10,'nativeRealm':'whale-treasure','trigger':'native-continuous','avatarLinked':True})
p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
