from pathlib import Path
import json,re
r=Path.cwd();o=r/'output/godot-black-white-20261028';raw={int(x['id']):x for x in json.loads((r/'research-data/cards.json').read_text())};sid='black-white-original-20261028';pending=['按24000–24108完整原卡面和官网基础牌文还原黑白童子；不逐赛季追改，指定录像未逐牌核验。','连引与来源能力/响应全序、羁绊互相自动使用、连斩受控后的第二攻击与同时伤害成长仍待原客户端核验。'];v={'units':{},'cards':{},'sources':[{'id':sid,'kind':'official-card-art','path':'research-notes/82-black-white-rules.md','url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js'}]}
def text(n):return re.sub(r'#\[([^]]+)\]',r'\1',raw[n]['desc']).replace('#r','\n')
for role,uid,name in [(240,'heitongzi','black'),(241,'baitongzi','white')]:
 v['units'][uid]={'verifiedRules':True,'blackWhiteRole':name,'attack':raw[role*100]['ll'],'maxHp':raw[role*100]['sm'],'passive':{'id':name+'-link','name':'羁绊','text':text(role*100),'hooks':[]},'awakenedPassive':{'id':name+'-link-awake','name':'羁绊','text':text(role*100+6).split('觉醒：')[-1],'hooks':[]},'formLifecycle':{},'sources':[sid],'verificationPending':pending}
 for n in range(role*100+1,role*100+9):
  row=raw[n];typ={'战斗':'combat','法术':'spell','形态':'form'}[row['type']];c={'verifiedRules':True,'blackWhiteRules':True,'type':typ,'typeLabel':{'combat':'战斗牌','spell':'法术牌','form':'形态牌'}[typ],'level':int(row['stage']),'cost':1,'text':text(n),'officialText':text(n),'target':'auto','effect':'black-white-'+str(n),'value':0,'effects':[],'keywords':[],'formRules':{},'formHooks':[],'formAbility':'','timing':'main','responseTo':[],'autoResponse':'','sources':[sid],'verificationPending':pending}
  if typ=='combat':
   c['value']=int(row['ll'] or 0);c['combatOption']={'shield':int(row['sm'] or 0)};c['effects']=[{'action':'black-white-combat','target':'source','value':c['value']}];c['responseAction']='assault'
   if n==24001:c['combatOption']['pierce']=True;c['keywords']=['pierce']
   if n==24101:c['combatOption']['lifeSteal']=True;c['keywords']=['lifesteal']
  elif typ=='form':
   c['effect']='form';c['value']={'attack':int(row['ll']),'hp':int(row['sm']),'setBase':True};c['effects']=[{'action':'form','target':'source','value':c['value']}];c['formAbility']=text(n)
   if n in [24004,24104]:c['formRules']['blackWhiteHurt']=name
   if n in [24007,24107]:c['formRules']['combatKeywords']=['pierce' if role==240 else 'lifesteal']
  elif n in [24006,24106]:c['value']={'attack':1,'hp':1};c['effects']=[{'action':'black-white-awaken','target':'source','value':c['value']}]
  else:
   action={24002:'black-white-move',24102:'black-white-revive',24105:'black-white-pray'}[n];c['effects']=[{'action':action,'target':'source','value':0}]
   if n in [24002,24102]:c['keywords']=['instant'];c['target']='ally-unit' if n==24002 else 'knocked-ally';c['effects'][0]['target']=c['target'];c['responseAction']='move-unit' if n==24002 else 'revive'
  v['cards']['c'+str(n)]=c
(o/'overlay.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
