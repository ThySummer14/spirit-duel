from pathlib import Path
import json,re
r=Path.cwd();out=r/'output/godot-box-maiden-20261028';raw={int(c['id']):c for c in json.loads((r/'research-data/cards.json').read_text())};sid='box-maiden-original-20261028'
pending=['按24300–24308完整原PNG和官网基础牌文还原；指定录像尚未逐牌核对，保留原客户端核验。','溢彩卡包的随机稀有度权重/重复规则、多个投骰/重投及召唤物攻击时序仍待实机核验。']
v={'units':{'xiazhongshaonv':{'verifiedRules':True,'boxMaidenRules':True,'nativeCharge':True,'attack':3,'maxHp':4,'passive':{'id':'box-maiden-base','name':'珍藏','text':raw[24300]['desc'],'hooks':[]},'awakenedPassive':{'id':'box-maiden-awaken','name':'珍藏','text':'充能。当你投骰子时，获得与骰子点数等量的能量。','hooks':[]},'formLifecycle':{},'sources':[sid],'verificationPending':pending}},'cards':{},'sources':[{'id':sid,'kind':'official-card-art','path':'research-notes/84-box-maiden-rules.md','url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js'}]}
for n in range(24301,24309):
 d=raw[n];typ={'法术':'spell','形态':'form'}[d['type']];t=re.sub(r'#\[([^]]+)\]',r'\1',d['desc'].replace('#r','\n'))
 c={'verifiedRules':True,'boxMaidenRules':True,'type':typ,'typeLabel':'法术牌' if typ=='spell' else '形态牌','level':d['stage'],'cost':1,'text':t,'officialText':t,'target':'auto','effect':'box-'+str(n),'value':0,'effects':[],'keywords':[],'formRules':{},'formHooks':[],'formAbility':'','timing':'main','responseTo':[],'autoResponse':'','sources':[sid],'verificationPending':pending}
 a={1:'light',2:'form',3:'summon',4:'awaken',5:'form',6:'revive',7:'pack',8:'form'}[n%100]
 if n in [24301,24305,24306,24307]:c['movementRules']=True;c['movementBurstOptions']=[10];c['boxBurstText']={24301:'造成10点伤害',24305:'形态获得5生命',24306:'额外恢复牌手10生命',24307:'获得卡包全部五张牌'}[n]
 if n==24301:c['target']='any-unit';c['value']=3;c['responseAction']='damage'
 if n in [24302,24305,24308]:c['value']={'attack':d['ll'],'hp':d['sm'],'setBase':True};c['formAbility']=t
 if n==24302:c['formRules']={'boxTreasure':True}
 if n==24304:c['value']={'attack':1,'hp':1}
 if n==24307:c['target']='ally-unit-any-state';c['keywords']=['instant']
 if n==24308:c['formRules']={'boxBrilliant':True,'combatKeywords':['penetration']}
 c['effects']=[{'action':'box-'+a,'target':'source','value':c['value']}];v['cards']['c'+str(n)]=c
(out/'overlay.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
