from pathlib import Path
import json,hashlib,shutil
root=Path(__file__).resolve().parents[2];folder=Path(__file__).parent
raw={str(c['id']):c for c in json.loads((root/'research-data/cards.json').read_text())}
roles={'603':('fenpopo','powder'),'606':('jiao','pearl'),'638':('fansi','feast')}
source='essence-feast-original-20261104'
pending=['采用本地中文完整原PNG与基础牌文；指定录像未逐牌核验。过量治疗/伤害转移/自动用牌/多来源同时触发与融合的完整全序仍待原客户端核验。']
overlay={'units':{},'cards':{},'sources':[{'id':source,'type':'local-original-card-png','title':'粉婆婆、椒图、饭笥完整原PNG','path':'art-reference-official/卡面-按版本/','checked':'2026-11-04'}, {'id':'essence-feast-derived-20261104','type':'mechanics-reference','url':'https://www.taptap.cn/moment/452866432946933284','title':'同期生命精华堆叠10、治疗层数及粉盒3/3融合'}, {'id':'fansi-satiety-video-20261104','type':'video-card-tooltip','url':'https://www.bilibili.com/video/BV1e7CXYWETR/','title':'饭笥实机解析04:20饱足完整tooltip','path':'output/godot-essence-feast-20261104/satiety-video-260sec.png'}]}
manifest=[]
forms={'60302':(3,5,{'efPaint':True}),'60304':(3,6,{'efPowderBox':True}),'60601':(2,5,{'efTorrent':True}),'60603':(5,7,{'efSpring':True}),'60607':(5,7,{'efPearlSplit':True}),'63802':(3,6,{'efChef':True}),'63806':(3,7,{'efDivine':True})}
realms={'60306':('ef-grudge',5),'60604':('ef-moist',4),'63805':('ef-divine-meal',4)}
for role,(uid,kind) in roles.items():
 base=raw[role+'00'];overlay['units'][uid]={'verifiedRules':True,'essenceFeastRole':kind,'attack':int(base['ll']),'maxHp':int(base['sm']),'passive':{'id':'ef-'+kind,'name':base['name'],'text':base['desc'].replace('#r','\n'),'hooks':[]},'awakenedPassive':{'id':'ef-'+kind+'-awake','name':'觉醒','text':'觉醒能力按对应觉醒牌原文生效。','hooks':[]},'sources':[source],'verificationPending':pending}
 paths=list((root/'art-reference-official/卡面-按版本').glob(f'*/*{role}_*'))
 for n in range(1,9):
  oid=role+f'{n:02d}';id='c'+oid;c=raw[oid];typ={'法术':'spell','战斗':'combat','形态':'form','结界':'realm','幻境':'realm'}[c['type']]
  text=c['desc'].replace('#r','\n');level=int(c['stage']);keywords=[]
  for cn,key in [('瞬发','instant'),('贯通','pierce'),('穿刺','penetration'),('追猎','pursuit')]:
   if cn in text:keywords.append(key)
  target='auto'
  if oid in ['60301']:target='enemy-unit'
  if oid in ['60303','60602']:target='ally-knocked'
  if oid in ['60307','60606']:target='any-living-unit'
  if oid in ['63801','63807']:target='ally-unit'
  if oid=='60608':target='enemy-character'
  p={'verifiedRules':True,'essenceFeastRules':True,'type':typ,'typeLabel':{'spell':'法术牌','combat':'战斗牌','form':'形态牌','realm':'幻境牌'}[typ],'level':level,'cost':1,'copies':2,'deckLimit':2,'target':target,'text':text,'officialText':text,'effect':'ef-card','value':0,'effects':[{'action':'ef-card','target':'selected' if target!='auto' else 'source','value':0}],'keywords':keywords,'tags':[],'timing':'main','responseTo':[],'formRules':{},'formHooks':[],'formAbility':'','sources':[source],'verificationPending':pending}
  if typ=='combat':p['value']=int(c.get('ll') or 0);p['combatOption']={'shield':int(c.get('sm') or 0)}
  if oid in forms:
   a,h,rules=forms[oid];p['value']={'attack':a,'hp':h,'setBase':True};p['formRules']=rules;p['formAbility']=text
  if oid in realms:
   realm,h=realms[oid];p['realm']={'hp':h,'nativeRealm':realm,'trigger':'native-continuous'}
  if oid in ['63803','63804','63807']:p['value']=1;p['combatOption']['shield']=1
  if oid=='63804':
   p['text']=p['officialText']='贯通。增强：本回合若饭笥曾被其他牌选择为目标，此牌获得追猎。'
   p['keywords']=['pierce']
  if oid=='63807':p['text']=p['officialText']='选择一个本回合曾被其他牌选择过的己方式神，本次战斗后使其发起一次攻击。'
  if oid=='60303':p['allowKnockedSource']=True
  if oid=='63808':
   p['efSoleSource']=True
   p['text']=p['officialText']='觉醒：当己方使用的手牌仅以己方单一式神为目标时，该式神+2力量/+2生命。每回合一次，以饭笥为目标使用手牌后，获得1鬼火。戏法：随机获得一张「食材」和一张「生命精华」。'
  if oid in ['60308','60605','63808']:
   p['value']={'attack':2,'hp':2} if oid=='60308' else {'attack':1,'hp':1}
  if oid in ['60307','60606','60608','63808']:p['efTrick']=True
  # Keywords printed only after the trick divider are not native main-mode abilities.
  if oid=='60608':p['keywords']=[]
  overlay['cards'][id]=p
  orig=next(paths[0].glob(oid+'_*'));targetpath=root/'godot/assets/official/cards'/f'{id}.png';targetpath.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(orig,targetpath)
  manifest.append({'source':str(orig.relative_to(root)),'target':str(targetpath.relative_to(root)),'sha256':hashlib.sha256(orig.read_bytes()).hexdigest()})
overlay['cards']['shengmingjinghua']={'verifiedRules':True,'neutralEssence':True,'unitId':'','type':'spell','typeLabel':'中立法术牌','level':0,'cost':1,'copies':0,'deckLimit':0,'target':'ef-essence-target','text':'瞬发。堆叠（最大10）。为一个角色恢复等同于堆叠层数的生命。','officialText':'瞬发。堆叠（最大10）。为一个角色恢复等同于堆叠层数的生命。','keywords':['instant'],'effect':'ef-essence','effects':[{'action':'ef-essence','target':'selected','value':1}],'token':True,'sources':['essence-feast-derived-20261104'],'verificationPending':['生命精华据同期2023卡包机制文本补证，中文独立派生完整原PNG暂缺，复杂复制/堆叠原客户端待核。']}
(folder/'overlay.json').write_text(json.dumps(overlay,ensure_ascii=False,indent=2)+'\n');(folder/'new_definitions.json').write_text(json.dumps({'units':[{'id':'ef-powder-box','name':'粉盒','title':'粉婆婆召唤物','attack':3,'maxHp':3,'art':'assets/wave7/fenpopo.svg','awakenedArt':'assets/wave7/fenpopo.svg','color':'#d8a6ba','pack':'wave7','selectable':False,'token':True,'summoned':True,'countsAsShikigami':True,'passive':{'id':'ef-box-fusion','name':'融合','text':'融合。离开战斗区时移除。','hooks':[]},'verifiedRules':True,'sources':['essence-feast-derived-20261104'],'verificationPending':['采用同期2023粉盒3/3融合说明，中文独立派生完整tooltip及美术暂缺；离场/融合/复活全序待原客户端核验。']}],'cards':[]},ensure_ascii=False,indent=2)+'\n');(folder/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('ESSENCE_FEAST_PREPARED',len(overlay['cards']),len(manifest))
