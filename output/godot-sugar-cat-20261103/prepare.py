from pathlib import Path
import json,hashlib,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).parent
raw=json.load(open(root/'research-data/cards.json'))
sources=[{'id':'sugar-cat-original-20261103','path':'art-reference-official/卡面-按版本/13_喧哗烩战/','evidence':'246/249的18张完整原PNG。c24601瞬发及弹回；糖人大师中文为1勾2/6，以原图优先。'}, {'id':'cat-summon-jp-20261103','url':'https://gamerch.com/onmyojicard/353786','evidence':'三猫补充实体定义；一条3/4食材后抽1、四饼3/4永久全局+1力量、二瞳3/4随机敌式神3伤；353788/353790交叉。'}, {'id':'sugar-summon-jp-20261103','url':'https://gamerch.com/onmyojicard/353926','evidence':'小糖人2/2融合；大糖人4/4融合不屈，与2022年同期攻略相符。'}, {'id':'sugar-feast-pool-gap','url':'https://gamerch.com/onmyojicard/353931','evidence':'甘如暖阳直接佳肴可含普通烹饪没有的追猎/必杀/远程，完整池未取得，不伪造三食材随机替代。'}]
pending=['按中文完整原PNG与基础牌文接入主要机制，指定录像未逐牌核验。三猫与糖人派生基础定义借助日文原卡／同期说明，中文独立原PNG暂缺。融合、多源食物自动使用、死亡及复活的全序仍待原客户端核验。']
units={};cards={};manifest=[]
for uid,role,label in [('maozhanggui',246,'cat'),('yixigong',249,'sugar')]:
 base=next(c for c in raw if str(c['id'])==str(role*100))
 units[uid]={'verifiedRules':True,'sugarCatRole':label,'attack':2,'maxHp':5,'formLifecycle':{},'passive':{'id':f'sc-{label}','name':'猫又屋' if label=='cat' else '烹糖','text':base['desc'].replace('#r','\n'),'hooks':[]},'awakenedPassive':{'id':f'sc-{label}-awake','name':'猫又屋' if label=='cat' else '烹糖','text':'己方回合开始时，随机将一张食材置入手牌。当你的召唤物进场时，随机从手牌对其使用一张食材。' if label=='cat' else '每回合一次，当己方式神使用法术牌时，烹饪。','hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}
 for n in range(1,9):
  c=next(c for c in raw if str(c['id'])==str(role*100+n));id='c'+str(c['id']);form=c['type']=='形态';awake=n==(4 if label=='cat' else 6)
  text=c['desc'].replace('#r','\n');text=text.replace('@2460103','，弹回').replace('&2490204','').replace('&2490806','');text=text.split('$')[0]
  type='form' if form else 'awakening' if awake else 'spell';action='sc-card';target='any-character' if id=='c24901' else 'any-unit' if id=='c24904' else 'auto'
  opts={'c24903':{'sugarMaster':True},'c24905':{'sugarReviveFood':True},'c24608':{'scHouse':True}}
  keywords=['instant'] if id in ['c24601','c24908'] else []
  if id=='c24601':keywords.append('bounce')
  cards[id]={'verifiedRules':True,'sugarCatRules':True,'type':type,'typeLabel':{'form':'形态牌','spell':'法术牌','awakening':'觉醒牌'}[type],'level':int(c['stage']),'cost':1,'copies':2,'deckLimit':2,'target':target,'text':text,'officialText':text,'keywords':keywords,'tags':[],'timing':'main','responseTo':[],'effect':action,'value':0,'effects':[{'action':action,'target':'source','value':0}],'formRules':opts.get(id,{}),'formHooks':[],'formAbility':text if form else '', 'sources':[s['id'] for s in sources],'verificationPending':pending}
  if form:cards[id]['value']=cards[id]['effects'][0]['value']={'attack':int(c['ll']),'hp':int(c['sm']),'setBase':True}
  if id in ['c24901','c24904']:cards[id]['responseAction']='damage'
  if id=='c24908':cards[id].update(verifiedRules=False,implementationStatus='partial',cookingDirectFeastPool=[],verificationPending=pending+['特殊佳肴完整随机词缀池尚无可靠资料：仅保留已知6张阈值永久成长/治疗代码与明确未实现事件，不以普通3食材随机替代；本牌不计主要机制全部接入。'])
  source=next((root/'art-reference-official/卡面-按版本/13_喧哗烩战').rglob(f'{role*100+n}_*.png'));target_path=root/f'godot/assets/official/cards/{id}.png';shutil.copy2(source,target_path)
  manifest.append({'source':str(source.relative_to(root)),'target':str(target_path.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
(out/'new_definitions.json').write_text(json.dumps({'units':[],'cards':[]},ensure_ascii=False,indent=2)+'\n')
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps([c for c in raw if str(c.get('role')) in ['246','249']],ensure_ascii=False,indent=2)+'\n')
print('SUGAR_CAT_PREPARED 16 subjects, c24908 partial')
# Full original derived-card images, retained unmodified (one source is JPEG).
# Definitions own no cards and never enter the constructible shikigami subset.
derived=[('cat-one','one.png','一条',3,4,'当你对一条使用食材时，抽一张牌。','7fzglIhm.png'),('cat-four','four.jpg','四饼',3,4,'当你对四饼使用食材时，本局游戏中猫掌柜的所有召唤物永久获得1力量。','zllnTytC.jpg'),('cat-two','two.png','二瞳',3,4,'当你对二瞳使用食材时，对一个随机敌方式神造成3点伤害。','Yvy08TO2.png'),('sugar-small','small.png','小糖人',2,2,'融合。','JhvV93fy.png'),('sugar-big','big.png','大糖人',4,4,'融合。不屈。','Xpx9kym8.png')]
new_units=[];summon_manifest=[]
for id,file,name,attack,hp,ability,remote_file in derived:
 source=out/'summon-reference'/file
 if not source.is_file():raise FileNotFoundError('Missing original derived reference '+str(source))
 target=root/'godot/assets/official/summons'/file;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
 root_target=root/'assets/official/summons'/file;root_target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,root_target)
 art=str(target.relative_to(root/'godot'))
 new_units.append({'id':id,'name':name,'title':'猫掌柜召唤物' if id.startswith('cat-') else '饴细工召唤物','role':'召唤物','strategy':'','attack':attack,'maxHp':hp,'pack':'wave5','subpack':'xuanhua','art':art,'awakenedArt':art,'color':'#e0b070','token':True,'selectable':False,'summoned':True,'verificationPending':['派生完整原卡为日文补证，中文独立tooltip与原客户端融合、进场及响应全序待核验。'],'countsAsShikigami':True,'passive':{'id':id+'-base','name':'基础能力','text':ability,'hooks':[]},'verifiedRules':True,'sources':['cat-summon-jp-20261103' if id.startswith('cat-') else 'sugar-summon-jp-20261103']})
 summon_manifest.append({'definitionId':id,'source':str(source.relative_to(root)),'sourceUrl':'https://cdn.gamerch.com/contents/wiki/1667/entry/'+remote_file,'target':str(target.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'referenceLanguage':'ja','completeCard':True})
(out/'new_definitions.json').write_text(json.dumps({'units':new_units,'cards':[]},ensure_ascii=False,indent=2)+'\n')
(out/'summon-art-manifest.json').write_text(json.dumps(summon_manifest,ensure_ascii=False,indent=2)+'\n')
print('SUGAR_CAT_DERIVED 5 original images and runtime-only definitions')

for u in new_units:
 units[u['id']]={k:u[k] for k in ['verifiedRules','selectable','summoned','verificationPending','sources']}
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
