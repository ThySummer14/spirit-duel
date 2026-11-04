from pathlib import Path
import json,hashlib,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
raw=json.loads((root/'research-data/cards.json').read_text());old={c['id']:c for c in json.loads((root/'godot/content/content.json').read_text())['cards']}
sources=[{'id':'cooking-original-20261103','path':'art-reference-official/卡面-按版本/13_喧哗烩战/','evidence':'五丸/食灵完整中文原PNG各9张。猫咪日和包含进场烹饪；快速烹饪含瞬发、弹回。'}, {'id':'cooking-cn-20220409','url':'https://www.sohu.com/a/536525662_268907','evidence':'同期NGA作者实战说明：按勾玉取得食材，烹饪时从右侧合成三个食材；佳肴保留其效果。'}, {'id':'cooking-jp-glossary','url':'https://gamerch.com/onmyojicard/217550','evidence':'日文补充：食品是费用1的中立牌，生成者气绝仍可使用；时蔬按等级扩展随机关键词，合成先于手牌上限。'}, {'id':'cooking-20220414-keyword-uniqueness','url':'https://www.gamedog.cn/news/3143818.html','evidence':'2022-04-14维护公告：时蔬优先不与手中其他食材重复关键词；无法避免时改山珍/海味。'}, {'id':'cooking-unknown-dark-jp','url':'https://gamerch.com/onmyojicard/354060','evidence':'日文争食补充定义：不明食材4破甲，参与合成改黑暗料理，黑暗料理瞬发6破甲。'}]
pending=['按完整中文原PNG和基础牌文实现主要机制，指定录像未逐牌核验。烹饪食材随机权重、CN右向左与JP随机选2旧食材差异、多源额外使用与触发的完整全序待原客户端核验。','普通食材/佳肴使用友方式神，中立法术不绑生成者；日文补充定义用于未有独立本地原图的食品。黑暗料理在用过佳肴条件计数而不计正常佳肴获得历史，特殊组合待中服实机核验。']
units={};cards={};manifest=[]
for number,uid,role,atk,hp in [(252,'wuwu','cat',3,4),(253,'shiling','chef',2,6)]:
 row=next(r for r in raw if r['id']==number*100)
 awake='连击。当五丸造成战斗伤害时，烹饪。' if number==252 else '每当己方式神烹饪时，食灵获得1力量。每当你获得「佳肴」时，复活食灵。'
 units[uid]={'verifiedRules':True,'cookingRole':role,'attack':atk,'maxHp':hp,'formLifecycle':{},'passive':{'id':f'cooking-{role}','name':'料理','text':row['desc'].replace('#[力量]','力量'),'hooks':[]},'awakenedPassive':{'id':f'cooking-{role}-awake','name':'觉醒·料理','text':awake,'hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}
 if number==252:units[uid]['awakenedCombatKeywords']=['combo']
 for n in range(1,9):
  id=f'c{number}{n:02d}';r=next(r for r in raw if r['id']==number*100+n);typ={'法术':'spell','形态':'form','战斗':'combat','结界':'realm'}[r['type']]
  if id in ['c25208','c25304']:typ='awakening'
  text=r['desc'].replace('#r','\n').replace('#[力量]','力量').replace('#[护甲]','护甲').replace('@2530602','')
  if id=='c25205':text='进场时烹饪。\n'+text
  if id=='c25306':text='瞬发，弹回\n烹饪'
  value={'attack':int(r['ll'] or 0),'hp':int(r['sm'] or 0),'setBase':True} if typ=='form' else {'attack':1,'hp':1} if typ=='awakening' else int(r['ll'] or 0)
  action='cooking-cat-combat' if typ=='combat' and number==252 else 'cooking-chef-combat' if typ=='combat' else 'cooking-form' if typ=='form' else 'cooking-awaken' if typ=='awakening' else 'cooking-realm' if typ=='realm' else 'cooking-play-feast' if id=='c25203' else 'cooking-cook'
  effects=[{'action':action,'target':'source','value':value}]
  if id in ['c25302','c25304']:effects.insert(0,{'action':'cooking-cook','target':'source','value':0})
  fr={'cookingCatDay':True} if id=='c25205' else {'cookingCatWork':True} if id=='c25207' else {'cookingOnEndFront':True} if id=='c25301' else {'cookingHotChef':True} if id=='c25305' else {'cookingDivinity':True} if id=='c25308' else {}
  c={'verifiedRules':True,'cookingRules':True,'type':typ,'typeLabel':{'spell':'法术牌','combat':'战斗牌','form':'形态牌','realm':'幻境牌','awakening':'觉醒牌'}[typ],'level':int(r['stage']),'cost':1,'copies':2,'deckLimit':2,'target':'enemy-unit' if id=='c25307' else 'auto','text':text,'officialText':text,'keywords':['instant'] if id in ['c25203','c25306'] else ['pierce'] if id=='c25206' else ['pursuit'] if id=='c25307' else ['firstStrike'] if id=='c25204' else [],'timing':'main','responseTo':[],'tags':[],'effect':action,'value':value,'effects':effects,'formRules':fr,'formHooks':[],'formAbility':text if typ=='form' else '', 'sources':[s['id'] for s in sources],'verificationPending':pending}
  if typ=='combat':c['combatOption']={'shield':int(r['sm'] or 0),'firstStrike':id=='c25204','pierce':id=='c25206','pursuit':id=='c25307'};c['responseAction']='assault'
  if id=='c25306':c['bounce']=True
  if typ=='realm':c['realm']={'hp':int(r['sm']),'nativeRealm':'cooking-dream','trigger':'native-continuous'}
  cards[id]=c
  source=next((root/'art-reference-official/卡面-按版本/13_喧哗烩战').glob(f'{number}_*/*{number}{n:02d}_*.png'));target=root/f'godot/assets/official/cards/{id}.png';shutil.copy2(source,target);manifest.append({'source':str(source.relative_to(root)),'target':str(target.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
new=[]
for id,name,kind in [('cooking-mountain','山珍','ingredient'),('cooking-sea','海味','ingredient'),('cooking-vegetable','时蔬','ingredient'),('shi-cai','不明食材','unknown'),('jia-yao','佳肴','feast'),('cooking-dark','黑暗料理','dark')]:
 c={'id':id,'unitId':'','name':name,'type':'spell','typeLabel':'中立法术牌','level':0,'cost':1,'copies':0,'deckLimit':0,'token':True,'neutralFood':True,'text':name+'：中立法术，效果由生成时的真实食材实例保留。','officialText':name+'：中立法术，效果由生成时的真实食材实例保留。','target':'food-target','keywords':['instant'] if kind=='dark' else [],'timing':'main','responseTo':[],'tags':[],'effect':'cooking-food','value':0,'effects':[{'action':'cooking-food','target':'selected','value':0}],'verifiedRules':True,'sources':[s['id'] for s in sources],'verificationPending':pending}
 cards[id]=c
 if id.startswith('cooking-'):new.append(c)
for name,obj in [('overlay.json',{'sources':sources,'units':units,'cards':cards}),('new_definitions.json',{'units':[],'cards':new}),('card-art-manifest.json',manifest),('official-source-evidence.json',[r for r in raw if r.get('role') in [252,253]])]:(out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print('COOKING_CORE_PREPARED cards16 foods6 new',len(new))
