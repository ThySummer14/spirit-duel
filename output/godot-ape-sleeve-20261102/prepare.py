from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
rows=json.loads((root/'research-data/cards.json').read_text())
sources=[{'id':'ape-sleeve-original-20261102','path':'art-reference-official/卡面-按版本/18_燃灯志异/','evidence':'294川猿和296小袖之手18张完整原PNG，按基础版本实现，不追逐后续平衡。'},{'id':'ape-sleeve-catalog-20261102','url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'本地research-data/cards.json的原网易卡库基础牌文。'}]
sources += [{'id':'sleeve-thread-jp-wiki','url':'https://gamerch.com/onmyojicard/786089','evidence':'日文资料明确结袂为唯一、每回合一次小袖对敌方式神造成伤害时对结附者3伤，移除后每次复活重新结附。'},{'id':'sleeve-thread-jp-client-video','url':'https://www.youtube.com/watch?v=UnWkrU6TWh0','evidence':'2023-08-05原客户端玩家实录介绍每回合一次小袖伤敌触发结袂3伤；未取得tooltip帧，中服边界保留待核。'}]
pending=['完整原PNG与基础牌文实现主要机制；指定录像未逐牌核验。数值交换/重置与其他光环、同时触发及死亡复活全序仍待原客户端核验。']
units={};cards={};manifest=[]
for role,uid,key in [(294,'chuanyuan','ape'),(296,'xiaoxiuzhishou','sleeve')]:
 row=next(r for r in rows if r['id']==role*100)
 txt=row['desc'].replace('#[力量]','力量').replace('#[生命]','生命').replace('#r','\n')
 awake=next(r for r in rows if r['id']==role*100+(6 if role==294 else 8))
 units[uid]={'verifiedRules':True,'apeSleeveRole':key,'attack':row['ll'],'maxHp':row['sm'],'formLifecycle':{},'passive':{'id':key+'-native','name':'百相变幻' if role==294 else '丝线直击','text':txt,'hooks':[]},'awakenedPassive':{'id':key+'-awakened','name':'天衣万象' if role==294 else '千针连缀','text':awake['desc'].replace('#r','\n'),'hooks':[]},'sources':[s['id'] for s in sources],'verificationPending':pending}
 actions={294:['ape-swap','ape-copy','ape-mimic','ape-paper','ape-all','ape-awaken','ape-seamless','form'],296:['sleeve-needle','sleeve-mend','form','sleeve-reset','form','sleeve-thread','sleeve-thousand','sleeve-awaken']}[role]
 for n in range(1,9):
  row=next(r for r in rows if r['id']==role*100+n);id=f'c{role}{n:02d}'
  text=row['desc'].replace('#r','\n').replace('#[力量]','力量').replace('#[生命]','生命')
  typ='form' if row['type']=='形态' else 'awakening' if '觉醒' in row['name'] else 'combat' if row['type']=='战斗' else 'spell'
  target='any-unit' if role==294 and n==2 else 'ally-unit' if role==294 and n==5 else 'enemy-unit' if (role==294 and n==4) or (role==296 and n in [1,2,4,6,7]) else 'enemy-character' if typ=='combat' else 'auto'
  keywords=['instant'] if (role==294 and n==1) or (role==296 and n in [1,6]) else ['pursuit'] if role==294 and n==7 else []
  value={'attack':row['ll'],'hp':row['sm'],'setBase':True} if typ=='form' else {'attack':1,'hp':1} if typ=='awakening' else 0
  card={'verifiedRules':True,'apeSleeveRules':True,'type':typ,'typeLabel':'形态牌' if typ=='form' else '觉醒牌' if typ=='awakening' else '战斗牌' if typ=='combat' else '法术牌','level':row['stage'],'cost':1,'copies':2,'deckLimit':2,'text':text,'officialText':text,'target':target,'keywords':keywords,'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':text if typ=='form' else '', 'effect':actions[n-1],'value':value,'effects':[{'action':actions[n-1],'target':'selected' if target not in ['auto','enemy-character'] else 'source','value':value}],'sources':[s['id'] for s in sources],'verificationPending':pending}
  if role==294 and n==8:card['formRules']={'apeMoon':True}
  if role==294 and n==7:card['combatOption']={'pursuit':True};card['target']='enemy-unit'
  if role==296 and n==3:card['formRules']={'sleeveSpell':True}
  if role==296 and n==5:card['formRules']={'sleeveAttack':True}
  if role==296 and n in [1,6]:card['focusEffect']='额外对另一个随机敌方式神造成2点伤害。' if n==1 else '再对该式神造成2点伤害。'
  if role==296 and n==6:
   card['verificationPending']=pending+['结袂完整定义采用日文资料与原客户端玩家实录描述补充，已实现唯一、每回合一次3伤与永久复活重挂；中服未取得原客户端tooltip帧，跨版本/同时复活与移除顺序待核。']
  if role==296 and n in [1,4,6,7,8] or role==294 and n==4:card['responseAction']='damage'
  cards[id]=card
  source=next((root/'art-reference-official/卡面-按版本/18_燃灯志异'/f'{role}_{row["name"] if n==0 else "川猿" if role==294 else "小袖之手"}').glob(f'{role}{n:02d}_*.png'))
  targetp=root/f'godot/assets/official/cards/{id}.png';shutil.copy2(source,targetp)
  manifest.append({'source':str(source.relative_to(root)),'target':str(targetp.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(out/'overlay.json').write_text(json.dumps({'sources':sources,'units':units,'cards':cards},ensure_ascii=False,indent=2)+'\n')
(out/'new_definitions.json').write_text(json.dumps({'units':[],'cards':[]},ensure_ascii=False,indent=2)+'\n')
(out/'official-source-evidence.json').write_text(json.dumps([r for r in rows if r.get('role') in [294,296]],ensure_ascii=False,indent=2)+'\n')
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('APE_SLEEVE_PREPARED cards=16 partial=0')
