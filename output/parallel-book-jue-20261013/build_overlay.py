import json,pathlib
out=pathlib.Path(__file__).parent
sources=[{'id':'dog-jue-balance-2021-02-04','url':'https://www.taptap.cn/moment/106165737759969184','evidence':'官方2021-02-04平衡：记仇改为消灭本回合造成过伤害的敌方式神；牌手受到敌方式神伤害时自动对其使用。'},{'id':'book-jue-snapshot','path':'research-data/cards.json','evidence':'11900–11908、12000–12008印刷身材与原版卡文；已被后续公告替换的牌文不直接沿用。'}, {'id':'book-guide-20200322','url':'https://www.taptap.cn/moment/15204895732793606','evidence':'官方攻略账号式神百谈：墨染向下取整、纪行实际牌手伤害、明心检索、云游调度、书翁觉醒按抽牌事件而非牌数且跨气绝。'}, {'id':'jue-guide-20200320','url':'https://www.taptap.cn/moment/15202073024924775','evidence':'官方攻略账号：展示、模仿动态增强、读心包括专属衍生牌、强索三次调度、灵视、记仇先原法术后复制、迷宫对瞬发。该版本觉醒持续展示和成长以2020维护替换。'}, {'id':'jue-balance-20200520-repost','url':'https://m.3839.com/gamehistorylog/109747.htm','evidence':'维护日志转载：觉醒·觉由持续展示改为立即展示以及己方回合开始展示。原官方页检索未获取，保留来源缺口。'}, {'id':'book-ink-20210826','url':'https://www.iyingdi.com/tz/post/5110863','evidence':'阴阳师百闻牌账号发布平衡说明：墨染增加先抽一张牌。'}, {'id':'jue-fix-20240111','url':'https://www.taptap.cn/moment/494265267065455318','evidence':'官方公告：觉醒与心灵迷宫不会重复征收鬼火。'}, {'id':'book-mechanic-20231029','url':'https://www.taptap.cn/moment/467093870207830538','evidence':'玩家实测补充：多张抽牌同一事件只触发10伤一次；明心是检索，空库既不判负也不触发觉醒。'}]
def effect(a,v=None,t='auto'):return {'condition':'always','action':a,'target':t,'value':v}
def card(name,typ,l,txt,a,v=None,t='auto',kw=None,**extra):
 d={'verifiedRules':True,'type':typ,'typeLabel':{'spell':'法术牌','form':'形态牌','combat':'战斗牌'}[typ],'level':l,'cost':1,'timing':'main','responseTo':[],'keywords':kw or [],'target':t,'text':txt,'officialText':txt,'formHooks':[],'formRules':{},'formAbility':'','effect':a,'value':v,'effects':[effect(a,v,t)],'sources':['book-jue-snapshot','book-guide-20200322' if name.startswith('book') else 'jue-guide-20200320']}
 d.update(extra);return d
def form(name,l,txt,atk,hp,**extra):return card(name,'form',l,txt,'form',{'attack':atk,'hp':hp,'setBase':True},formAbility=txt,**extra)
r={'schema':1,'sources':sources,'units':{},'cards':{}}
r['units']['shuweng']={'attack':1,'maxHp':5,'bookOpeningCards':1,'passive':{'id':'book-opening','name':'纪行','text':'起始手牌数量+1。','hooks':[]},'awakenedPassive':{'id':'book-empty-draw','name':'觉醒·书翁','text':'本局游戏剩余时间内，每当你抽牌时若牌库里没有牌，改为对敌方牌手造成10点伤害，你不会因此输掉游戏。','hooks':[]},'sources':['book-jue-snapshot','book-guide-20200322']}
r['units']['jue']={'attack':2,'maxHp':5,'jueReveal':True,'passive':{'id':'jue-reveal','name':'读心','text':'己方回合开始时，随机展示一张敌方手牌。','hooks':[]},'awakenedPassive':{'id':'jue-turn-reveal','name':'觉醒·觉','text':'己方回合开始时，展示敌方所有手牌。','hooks':[]},'sources':['book-jue-snapshot','jue-balance-20200520-repost'],'verificationPending':['2020-05-20觉醒调整只有维护转载，尚未取到原官方页及指定录像该角色片段。']}
c=r['cards']
c['c11901']=card('book','spell',2,'抽两张牌。','draw',2)
c['c11902']=form('book',1,'迅捷。当书翁对敌方牌手造成伤害时，抽一张牌。',2,5,formRules={'bookAvatarDraw':True})
c['c11903']=card('book','spell',2,'抽一张牌，对一个式神造成等同于你手牌数量一半的伤害（向下取整）。','book-ink',None,'any-living-unit',sources=['book-jue-snapshot','book-guide-20200322','book-ink-20210826'])
c['c11904']=form('book',2,'回合开始的抽牌改为检视牌库顶三张牌然后选择一张置入手牌。',4,5,formRules={'bookMindChoice':True},sources=['book-jue-snapshot','book-guide-20200322','book-mechanic-20231029'])
c['c11905']=form('book',3,'每有一张其它手牌，此牌便获得1力量与1生命。',1,1,bookHandForm=True)
c['c11906']=card('book','spell',3,'瞬发。随机将其他己方式神的各一张牌置入手牌。','book-universe',kw=['instant'],verificationPending=['官方快照为自身瞬发；2020攻略文称生成牌本回合瞬发，未取得后续变更公告，当前按官方快照实现，生成牌临时瞬发仍待当前实机核对。','完整候选池的异画权重及非构筑专属衍生牌边界缺当前客户端证据。'])
c['c11907']=card('book','spell',1,'瞬发。调度你的手牌（3次调度次数）。','book-dispatch',kw=['instant'],verificationPending=['调度的逐次选择已实现；退回牌在全部调度后洗回，仍需当前客户端核对分批退回及重复选择新牌的细节。'])
c['c11908']=card('book','spell',3,'觉醒：本局游戏剩余时间内，每当你抽牌时若牌库里没有牌，改为对敌方牌手造成10点伤害，你不会因此输掉游戏。','book-awaken',{'attack':2,'hp':2},deckLimit=2,copies=2,sources=['book-jue-snapshot','book-guide-20200322','book-mechanic-20231029'])
c['c12001']=card('jue','spell',1,'瞬发。选择一个敌方式神，从对方手牌展示所有该式神的专属牌。','jue-read',None,'enemy-unit-any-state',['instant'])
c['c12002']=card('jue','spell',1,'对一个式神造成2点伤害，该式神每有一张已展示的专属牌，伤害+2。','jue-bomb',None,'any-living-unit')
c['c12003']=card('jue','spell',2,'瞬发。调度对手已展示的手牌，抽一张牌（3次调度次数）。','jue-dispatch',kw=['instant'],verificationPending=['新换入牌保持未展示；调度退回牌在全部调度后洗回的细节仍需当前客户端核对。'])
c['c12004']=form('jue',2,'当敌方牌手使用已展示的手牌时，他受到2点伤害且你恢复2点生命。',5,5,formRules={'jueSpiritSight':True})
c['c12005']=card('jue','spell',2,'消灭一个本回合造成过伤害的敌方式神。响应：当你受到敌方式神伤害时，自动对其使用。','jue-grudge',None,'enemy-damaged-unit-this-turn',['response'],autoResponse='enemy-unit-damaged-avatar',sources=['book-jue-snapshot','dog-jue-balance-2021-02-04'])
c['c12006']=form('jue',3,'对手使用已展示的手牌时需额外消耗一点鬼火。增强：若敌方手牌全部已展示，此牌获得瞬发。',5,5,formRules={'jueHandTax':True},jueMazeEnhance=True,sources=['book-jue-snapshot','jue-guide-20200320','jue-fix-20240111'])
c['c12007']=card('jue','spell',3,'展示敌方所有手牌。觉醒：己方回合开始时，展示敌方所有手牌。','jue-awaken',{'attack':1,'hp':1},deckLimit=2,copies=2,sources=['book-jue-snapshot','jue-balance-20200520-repost','jue-fix-20240111'],verificationPending=['旧快照含使用已展示牌成长；2020维护转载的新效果未保留该句，当前按完整替换处理，待原官方牌面及当前实机最终核对。'])
c['c12008']=card('jue','combat',1,'增强：对手每有一张已展示的法术牌，此牌便获得+1护甲。每有一张已展示的其他牌，便获得+1力量。','assault',0,jueMimic=True,combatOption={'shield':0})
(out/'overlay.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
