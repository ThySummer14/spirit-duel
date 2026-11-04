from pathlib import Path
import json,re,shutil,hashlib
root=Path.cwd();out=root/'output/godot-two-faces-20261028';raw={int(x['id']):x for x in json.loads((root/'research-data/cards.json').read_text())}
sid='two-faces-original-20261028';pending=['按23800–23808完整原卡面及基础牌文还原；雷嗔电怒完整PNG为贯通，采用PNG并保留官网旧直击文本差异。','连引候选、出牌前二选一、未选洗回及风雷万象牌库使用已实现；复杂反制/结附/替换与录像全序尚待原客户端核验。']
v={'sources':[{'id':sid,'kind':'official-card-art','path':'research-notes/83-two-faces-rules.md','url':'https://www.bilibili.com/video/BV1TL4y1H7px/'}],'units':{'liangmianfo':{'verifiedRules':True,'twoFacesRules':True,'attack':3,'maxHp':4,'passive':{'id':'two-faces-base','name':'风雷连引','text':raw[23800]['desc'].replace('#r','\n'),'hooks':[]},'awakenedPassive':{'id':'two-faces-awake','name':'风雷连引','text':'风牌连引雷牌，雷牌连引风牌；所有牌的增强未连引也能生效。','hooks':[]},'formLifecycle':{},'sources':[sid],'verificationPending':pending}},'cards':{}}
for n in range(23801,23809):
 r=raw[n];typ={'法术':'spell','战斗':'combat','形态':'form'}[r['type']];txt=re.sub(r'#\[([^]]+)\]',r'\1',r['desc'].replace('#r','\n'));txt=txt.replace('直击','贯通') if n==23804 else txt
 c={'verifiedRules':True,'twoFacesRules':True,'type':typ,'typeLabel':{'spell':'法术牌','combat':'战斗牌','form':'形态牌'}[typ],'level':int(r['stage']),'cost':1,'text':txt,'officialText':txt,'target':'auto','effect':'two-faces-'+str(n%100),'value':0,'effects':[],'keywords':[],'formRules':{},'formHooks':[],'formAbility':'','timing':'main','responseTo':[],'autoResponse':'','sources':[sid],'verificationPending':pending}
 action={1:'two-faces-combat',2:'two-faces-sound',3:'awaken',4:'two-faces-combat',5:'two-faces-wind',6:'two-faces-combat',7:'two-faces-gale',8:'form'}[n%100]
 if n in [23801,23804,23806]:c.update(twoFacesAffinity='thunder',value=int(r['ll'] or 0),combatOption={'shield':int(r['sm'] or 0)},responseAction='assault')
 if n in [23802,23805,23807]:c['twoFacesAffinity']='wind'
 if n in [23802,23807]:c['target']='any-unit' if n==23802 else 'enemy-character';c['responseAction']='damage'
 if n==23803:c['value']={'attack':1,'hp':1}
 if n==23806:c['keywords']=['combo']
 if n==23808:c.update(effect='form',value={'attack':4,'hp':7,'setBase':True},formRules={'twoFacesDeck':True},formAbility=txt)
 c['effects']=[{'action':action,'target':'source','value':c['value']}];v['cards'][f'c{n}']=c
(out/'overlay.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
manifest=[]
for src in sorted((root/'art-reference-official/卡面-按版本/12_浮生方醒/238_两面佛').glob('*.png')):
 n=int(src.name[:5])
 if n==23800:continue
 dest=root/f'godot/assets/official/cards/c{n}.png';assert not dest.exists();shutil.copy2(src,dest);manifest.append({'source':str(src.relative_to(root)),'dest':str(dest.relative_to(root)),'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
(out/'card-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
