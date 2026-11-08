from pathlib import Path
import json,hashlib,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent
sources=[{'id':'music-fire-original-20261104','type':'local-original-png','path':'art-reference-official/卡面-按版本/14_空弦绮话','note':'256/263完整中文PNG优先，已逐图目检。'}, {'id':'music-fire-official-20220708','url':'https://www.taptap.cn/moment/294558767473756706','note':'官方公告：两类诡间缚偶、紧那罗生成排除觉醒、铃彦姬无恢复3版本。'}, {'id':'music-fire-related-jp','url':'https://gamerch.com/onmyojicard/381027','note':'神火铃焰0/4，自回1，满血切回和AOE；派生原图原字节。'}, {'id':'music-fire-awake-related-jp','url':'https://gamerch.com/onmyojicard/381117','note':'神火觉醒AOE等于勾玉；不采用日文后来恢复3增强。'}, {'id':'music-fire-switch-order','url':'https://www.taptap.cn/moment/467093870207830538','note':'玩家机制整理：保留灵咒眩晕等，移除护甲破甲，群伤后切换、连击继续命中；复杂客户端边界待核。'}]
pending=['采用完整中文原PNG及基础牌文；指定录像未逐牌核验。神火与缚偶派生基础定义补官方公告和日文原卡，中文派生tooltip与切换/多源反制/群伤/幸运倍增的完整全序仍待原客户端核验。']
texts={25601:'瞬发。入夜1：占卜1，抽一张牌。增强：若你入夜值为0，额外生效一次。',25602:'每回合一次，当敌方式神攻击时，运势6：本回合降低其1力量。你每有2点入夜值，运势所需点数-1。',25603:'对敌方战斗区式神造成4点伤害，运势6：再对敌方牌手造成4点伤害。你每有2点入夜值，运势所需点数-1。',25604:'对一个敌方式神造成5点伤害，运势6：再对敌方所有角色造成1点伤害。你每有2点入夜值，运势所需点数-1。',25605:'进场和己方回合开始时，运势6：随机召唤一个「诡间缚偶」。你每有2点入夜值，运势所需点数-1。',25606:'进场和己方回合开始时，运势6：抽一张牌。你每有2点入夜值，运势所需点数-1。',25607:'运势6：随机将两张紧那罗的其他卡牌置入你的手牌。你每有2点入夜值，运势所需点数-1。觉醒：当紧那罗运势时，随机对一个敌方角色造成3点伤害，然后入夜10：获得1点鬼火。',25608:'消灭一个力量值或生命值不大于你入夜值的角色。若目标为式神，则入夜10：使其气绝倒计时+2。',26301:'攻击后为自己恢复3生命。',26302:'进场和己方回合开始时，为所有己方角色恢复1生命，「神火铃焰」额外恢复1生命。',26303:'追猎。',26304:'进场时对一个敌方式神和铃彦姬各造成4点伤害。己方回合「神火铃焰」受到非战斗伤害时，改为恢复等量生命。',26305:'使铃彦姬永久获得2力量，并额外使用一张「觉醒·神火铃焰」。觉醒：当铃彦姬气绝时，切换为1生命的「神火铃焰」并移回准备区。',26306:'本次战斗受到的战斗伤害改为为自己和你恢复等量生命。响应：当你被敌方攻击时，若「神火铃焰」在场，自动使用并将攻击目标改为「神火铃焰」。',26307:'瞬发，弹回。恢复一个角色5生命。',26308:'己方回合「神火铃焰」获得3力量和免疫战斗伤害。进场或己方回合开始时，使「神火铃焰」发起一次攻击，然后为其恢复全部生命。'}
units={'jinnaluo':{'verifiedRules':True,'musicFireRole':'music','attack':2,'maxHp':5,'passive':{'id':'mf-music','name':'入夜弦音','text':'当紧那罗运势时，入夜X：随机对一个敌方角色造成1点伤害。X为骰子点数。','hooks':[]},'awakenedPassive':{'id':'mf-music-awake','name':'觉醒·紧那罗','text':'当紧那罗运势时，随机对一个敌方角色造成3点伤害，然后入夜10：获得1点鬼火。','hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending},'lingyanji':{'verifiedRules':True,'musicFireRole':'fire','attack':3,'maxHp':4,'passive':{'id':'mf-human','name':'神火铃焰','text':'当铃彦姬气绝时，切换为1生命的「神火铃焰」并移回准备区。','hooks':[]},'awakenedPassive':{'id':'mf-human-awake','name':'觉醒·铃彦姬','text':'当铃彦姬气绝时，切换为1生命的「神火铃焰」并移回准备区。','hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}}
levels={256:[1,1,1,2,2,2,3,3],263:[1,1,1,2,2,2,2,3]}
forms={25602:(3,5,'mfPalace'),25605:(4,5,'mfDollForm'),25606:(4,5,'mfFeatherForm')}
cards={}
for num,text in texts.items():
 c={'verifiedRules':True,'musicFireRules':True,'type':'spell','typeLabel':'法术牌','level':levels[num//100][num%100-1],'cost':1,'copies':2,'deckLimit':2,'target':'auto','text':text,'officialText':text,'keywords':[],'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':[s['id'] for s in sources],'verificationPending':pending}
 a='mf-card';v=0
 if num in forms:
  atk,hp,flag=forms[num];c.update(type='form',typeLabel='形态牌',formRules={flag:True},formAbility=text);a='mf-form';v={'attack':atk,'hp':hp,'setBase':True}
 if num in [26301,26303,26306]:
  c.update(type='combat',typeLabel='战斗牌',responseAction='assault',combatOption={'shield':0});a='mf-combat';v=1 if num==26303 else 0
 if num==26303:c['keywords']=['pursuit'];c['combatOption']['pursuit']=True;c['target']='enemy-unit'
 if num in [26302,26304,26308]:c.update(type='realm',typeLabel='结界牌',realm={'hp':5,'trigger':'native','triggerEffect':'none','triggerValue':0},nativeRealm={26302:'mf-heal',26304:'mf-flame',26308:'mf-eternal'}[num]);a='mf-realm'
 if 'nativeRealm' in c:c['realm']['nativeRealm']=c['nativeRealm']
 if num in [25607,26305]:c.update(type='awakening',typeLabel='觉醒牌')
 if num in [25601,26307]:c['keywords']=['instant']
 if num==26307:c['keywords'].append('bounce')
 if num in [25604,26304]:c['target']='enemy-unit'
 if num in [25608,26307]:c['target']='any-character'
 if num==26306:c.update(autoResponse='avatar-attacked',responseModifiesCombat=True)
 c.update(effect=a,value=v,effects=[{'action':a,'target':'selected' if c['target']!='auto' else 'source','value':v}]);cards['c'+str(num)]=c
new={'units':[],'cards':[]}
for id,name,attack,hp,kws,art in [('mf-fire','神火铃焰',0,4,[],'assets/official/tokens/mf-fire.png'),('mf-fire-awakened','觉醒·神火铃焰',0,4,[],'assets/official/tokens/mf-fire-awakened.png'),('mf-doll-blood','诡间缚偶',2,4,['lifesteal'],'assets/official/tokens/mf-doll-a.png'),('mf-doll-swift','诡间缚偶',4,2,['swift'],'assets/official/tokens/mf-doll-b.png')]:
 u={'id':id,'name':name,'title':'紧那罗召唤物' if 'doll' in id else '铃彦姬切换形态','role':'派生实体','strategy':'','attack':attack,'maxHp':hp,'art':art,'awakenedArt':art,'color':'#dc8060','pack':'wave6','subpack':'kongxian','selectable':False,'token':True,'countsAsShikigami':True,'combatKeywords':kws,'passive':{'id':id+'-passive','name':name,'text':('吸血。' if 'blood' in id else '迅捷。')+'离开战斗区移除。' if 'doll' in id else '己方回合开始时恢复1生命。生命恢复至满时切换为铃彦姬，对所有敌方式神造成'+('等同铃彦姬等级的' if 'awakened' in id else '1点')+'伤害。','hooks':[]},'verifiedRules':True,'sources':[s['id'] for s in sources],'verificationPending':pending}
 new['units'].append(u);units[id]=u
firecard={'id':'mf-fire-awakening','unitId':'lingyanji','name':'觉醒·神火铃焰','type':'awakening','typeLabel':'觉醒牌','level':2,'cost':1,'copies':0,'deckLimit':0,'token':True,'pack':'wave6','keywords':[],'text':'觉醒：己方回合开始时恢复1生命。生命恢复至满时切换为铃彦姬，对所有敌方式神造成等同铃彦姬等级的伤害。','officialText':'觉醒：己方回合开始时恢复1生命。生命恢复至满时切换为铃彦姬，对所有敌方式神造成等同铃彦姬等级的伤害。','target':'auto','effect':'mf-fire-awaken','value':0,'effects':[{'action':'mf-fire-awaken','target':'source','value':0}],'verifiedRules':True,'musicFireRules':True,'sources':[s['id'] for s in sources],'verificationPending':pending}
new['cards'].append(firecard);cards[firecard['id']]=firecard
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n');(out/'new_definitions.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
manifest=[]
for num in texts:
 src=next((root/'art-reference-official/卡面-按版本/14_空弦绮话').glob(f'{num//100}_*/{num}_*.png'));target=root/f'godot/assets/official/cards/c{num}.png';target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target);manifest.append({'source':str(src.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
for item in json.loads((out/'derivative-art-manifest.json').read_text()):
 for rel in [item['target'],item['target'].removeprefix('godot/')]:
  target=root/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/item['source'],target)
print('MUSIC_FIRE_PREPARED main=16 derivedUnits=4 derivedCards=1')
