import json,pathlib
out=pathlib.Path(__file__).parent
sources=[
 ('smoke-official-2020-03-30','烟烟罗官方逐卡介绍','https://www.taptap.cn/moment/15215747550676457','2020-03-30'),
 ('sun-official-tutorial-2020-04-16','官方百闻小课堂日和坊：护甲代替生命、重置与觉醒','https://m.taptap.io/post/304571','2020-04-16'),
 ('sun-original-2020-04-01','日和坊初版逐卡牌文转载','https://www.9game.cn/news/4270201.html','2020-04-01'),
 ('sun-balance-2020-04-23','官方平衡性调整背后隐藏的秘密：阳炎与沐浴阳光','https://www.taptap.cn/moment/15226566611042541','2020-04-23'),
 ('sun-reset-fix-2021-07-15','官方日出有曜生命重置修复','https://www.taptap.cn/moment/164475406232060998','2021-07-15'),
 ('sun-response-fix-2022-03-24','官方阳炎己方回合响应修复','https://www.taptap.cn/moment/255819925879260009','2022-03-24'),
 ('charge-regular-2023-02-23','官方常规充能平衡：三个日和坊形态与无孔不入','https://www.taptap.cn/moment/377573593325767829','2023-02-23'),
 ('charge-balance-explainer-2023-02-23','官方充能平衡说明，附调整前后','https://www.taptap.cn/moment/377553567868781323','2023-02-23'),
 ('smoke-burst-balance-2024-04-25','官方暴躁鬼投射4、击杀能量4','https://www.taptap.cn/moment/532318040168074381','2024-04-25'),
 ('smoke-tutorial-2020-04-15','狸猫会一波啊官方课堂转载：分身继承与负面状态','https://m.ali213.net/news/200415/140575.html','2020-04-15'),
]
base={'verifiedRules':True,'sunSmoke':True,'cost':1,'copies':2,'deckLimit':2,'keywords':[],'tags':[],'timing':'main','responseTo':[],'formHooks':[],'formRules':{},'verificationPending':[],'sources':['official-card-snapshot']}
units={}
for id,role,atk,hp,desc,awake in [
 ('yanyanluo','smoke',2,4,'充能。当烟烟罗获得能量时若能量为0，额外多获得1点。','觉醒：当烟烟罗获得能量时，获得的能量翻倍。'),
 ('rihefang','sun',1,6,'充能。日和坊能量不足时，可以消耗其生命代替。（不能使生命降到0）','觉醒：己方每回合第一个消耗能量的效果无需消耗能量。')]:
 units[id]={'verifiedRules':True,'sunSmokeRole':role,'nativeCharge':True,'attack':atk,'maxHp':hp,'keywords':['charge'],'officialAbility':desc,'passive':{'id':role,'name':desc.split('。')[0],'text':desc,'hooks':[]},'awakenedPassive':{'id':role+'-awake','name':'觉醒','text':awake,'hooks':[]},'sources':['official-card-snapshot',sources[0 if role=='smoke' else 1][0]],'verificationPending':['回合自然复活、充能与其他回合开始能力同优先级时的原版全序仍需指定录像逐帧确认。']}
cards={}
def card(id,typ,level,target,text,action,value,**extra):
 d=dict(base);d.update(type=typ,typeLabel='形态牌' if typ=='form' else '法术牌',level=level,target=target,text=text,officialText=text,effect=action,value=value,effects=[{'condition':'always','action':action,'target':'source' if target=='auto' else 'selected','value':value}]);d.update(extra);cards[id]=d;return d
sm=['smoke-official-2020-03-30'];sun=['sun-original-2020-04-01','sun-official-tutorial-2020-04-16'];new=['charge-regular-2023-02-23','charge-balance-explainer-2023-02-23']
card('c16401','spell',1,'enemy-unit','对一个敌方式神造成2点伤害。爆能X：额外造成X点伤害，X为全部能量。','smoke-hit',2,smokeBurst=True,sources=sm)
card('c16402','form',2,'auto','进场时，在战斗区召唤一个烟烟罗的分身，分身每有1能量便获得1力量。','form',{'attack':2,'hp':4,'setBase':True},formRules={'smokeSummon':'power'},sources=sm+['smoke-tutorial-2020-04-15'])
card('c16403','spell',2,'auto','对敌方战斗区的式神造成3点伤害，恢复己方牌手3生命。爆能X：额外造成X点伤害，X为全部能量。','smoke-hit',3,smokeBurst=True,smokeHeal=3,sources=sm)
card('c16404','spell',1,'auto','在战斗区召唤一个烟烟罗的分身。响应：当你的牌手被攻击时，自动使用此牌。','smoke-summon',1,autoResponse='avatar-attacked',sources=sm+['smoke-tutorial-2020-04-15'])
card('c16405','spell',1,'auto','瞬发。烟烟罗获得3能量。','smoke-charge',3,keywords=['instant'],sources=sm)
card('c16406','spell',2,'auto','烟烟罗获得2能量。觉醒：当烟烟罗获得能量时，获得的能量翻倍。','smoke-awaken',{'attack':1,'hp':1},tags=['觉醒'],sources=sm)
card('c16407','form',3,'auto','进场时，选择一张烟烟罗的爆能牌置入手牌。进场和己方回合开始时，在战斗区召唤一个烟烟罗的分身。烟烟罗的分身会复制她使用的法术牌。','form',{'attack':3,'hp':6,'setBase':True},smokePick=True,formRules={'smokeSummon':'copy'},sources=sm+new+['smoke-tutorial-2020-04-15'],verificationPending=['分身复制的微时序、目标失效及反制时是否仍独立复制，需要指定录像补充验证。'])
card('c16408','spell',3,'auto','投射：造成4点伤害。爆能X：额外造成X点伤害，X为全部能量。消灭式神后，烟烟罗获得4能量。','smoke-hit',4,smokeBurst=True,smokeProjectile=True,smokeKillCharge=4,sources=sm+['smoke-burst-balance-2024-04-25'])
card('c16601','spell',1,'auto','瞬发。使所有己方充能式神恢复所有生命，并获得1能量。','sun-heal',1,keywords=['instant'],sources=sun+['sun-balance-2020-04-23'])
card('c16602','spell',2,'any-living-unit','对一个式神造成1点伤害并使其眩晕。响应：当敌方式神升级时，自动对其使用。','sun-heat',1,autoResponse='enemy-upgraded',sources=sun+['sun-balance-2020-04-23','sun-response-fix-2022-03-24'])
card('c16603','form',1,'auto','进场和己方回合开始时，消耗3能量，抽一张牌。','form',{'attack':1,'hp':7,'setBase':True},formRules={'sunForm':'draw','sunChargeCost':3},sources=sun+new)
card('c16604','spell',2,'auto','所有己方充能式神获得1力量、1生命和2能量。','sun-growth',1,sources=sun)
card('c16605','form',2,'auto','进场和己方回合开始时，消耗2能量，随机使其他一名能量最低的己方充能式神获得2能量。','form',{'attack':2,'hp':7,'setBase':True},formRules={'sunForm':'transfer','sunChargeCost':2},sources=sun+new)
card('c16606','spell',2,'any-living-character','瞬发。重置一个角色的力量和生命。','sun-reset',1,keywords=['instant'],sources=sun+['sun-reset-fix-2021-07-15'],verificationPending=['旧模块中缺少永久标记的attackBonus/maxHpBonus仍无法穷尽分类；已识别觉醒、觉醒桃花治疗、跳弟永久生命及permanentAttack保留。其他未标记永久成长需要继续逐机制迁移。'])
card('c16607','spell',3,'auto','瞬发。觉醒：己方每回合第一个消耗能量的效果无需消耗能量。','sun-awaken',{'attack':0,'hp':3},keywords=['instant'],tags=['觉醒'],sunAwaken=True,sources=sun)
card('c16608','form',3,'auto','当己方其他角色受到伤害时，日和坊恢复3生命。进场和每个回合开始时，消耗3能量，恢复所有其他己方角色3生命。','form',{'attack':3,'hp':8,'setBase':True},formRules={'sunForm':'rain','sunChargeCost':3},sources=sun+new)
for k in ['c16401','c16403','c16408']:cards[k]['verificationPending']=['爆能选项已经真实进入可序列化选择栈；与原版宣告/响应窗口之间的微时序需要指定录像补齐。']
for k in ['c16402','c16404']:cards[k]['verificationPending']=['分身负面状态继承据官方课堂转载；指定录像尚无相同冻结/破甲组合可逐帧确认。']
result={'schema':1,'sources':[{'id':id,'title':title,'url':url,'date':date,'mode':'constructed'} for id,title,url,date in sources],'units':units,'cards':cards}
(out/'overlay.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
