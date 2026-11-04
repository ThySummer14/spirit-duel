import json,re
from pathlib import Path
raw={str(c['id']):c for c in json.loads(Path('research-data/cards.json').read_text())}
source=[{'id':'movement-official-snapshot','title':'网易官方卡牌制作工具快照（旧版本，逐条覆盖后续更新）','url':'https://ssr.res.netease.com/cardmaker/index.html','local':'research-data/cards.json','scope':'原主体牌；version1003，不据此推断当前版本'},
{'id':'weasel-balance-20200428','title':'官方社区S4平衡说明与调整前后牌面图片','url':'https://www.taptap.cn/moment/15226566611042541','scope':'常规对战，3/5、戟+1甲爆能4、棒爆能7'},
{'id':'deer-self-20230810','title':'官方8月10日平衡性调整说明','url':'https://www.taptap.cn/moment/438417787577175822?group_id=188707','scope':'常规对战，自强之愿每实际回合一次获得1能量1护甲'},
{'id':'weasel-fix-20210715','title':'官方7月15日维护公告','url':'https://www.taptap.cn/moment/164475406232060998','scope':'同生共死可防止暴击致死'},
{'id':'deer-guide-20210610','title':'官方社区小鹿男解析（小果酱渣）','url':'https://www.taptap.cn/moment/151653485677381073','scope':'主体牌/复活/形态；具体数值仍须后续公告核验'},
{'id':'movement-firsthand-20200413','title':'石秋瞳原创实机充能套详解','url':'https://www.sohu.com/a/387647882_120196496','scope':'随机声东击西含牌手、鹿角吸血回复牌手；旧测试版本不据此采用旧爆能档位'},
{'id':'weasel-followup-20210422','title':'2021年4月22日更新后原创天梯周报（待补官方公告）','url':'https://www.iyingdi.com/tz/post/2375203','scope':'同心协力一勾、声东击西二勾+2力量；原公告待核验'},
{'id':'movement-combat-timing-20201229','title':'RR抒情夜莺原创实机战斗流程核验','url':'https://www.iyingdi.com/tz/post/2335072','scope':'额外战斗在战斗结束步骤、戟棒后续在结束后；插入战斗复杂交叉待核验'}]
pending=['用户录像未展示本组三位全部主体牌；2023以后后续公告尚未穷尽，保留版本验收待核对。','随机候选依据牌文与实机资料；均匀分布及少数跨模块插入战斗时序尚缺当前实机验证。']
def clean(t):return re.sub(r'\$（.*?）\$','',t).replace('#r','\n').replace('&#10;','').replace('#[','').replace(']','')
o={'sources':source,'units':{},'cards':{}}
for key,r,name in [('xiaolunan','163','deer'),('lianyou','133','weasel'),('yatiangou','139','crow')]:
 text=clean(raw[r+'00']['desc'])
 o['units'][key]={'verifiedRules':True,'movementRole':name,'nativeCharge':name!='crow','attack':int(raw[r+'00']['ll']),'maxHp':int(raw[r+'00']['sm']),'officialAbility':text,'keywords':['charge'] if name!='crow' else [],'passive':{'id':key+'-native','name':'原生能力','text':text,'hooks':[]},'awakenedPassive':{'id':key+'-awake','name':'觉醒能力','text':clean(raw[r+'08' if r!='133' else '13307']['desc']),'hooks':[]},'sources':[x['id'] for x in source],'verificationPending':pending,'ruleFidelity':{'status':'source-backed-pending','pending':pending}}
for r in ['163','133','139']:
 for i in range(1,9):
  cid='c'+r+f'{i:02d}';d=raw[cid[1:]];typ={'战斗':'combat','法术':'spell','形态':'form'}[d['type']];text=clean(d['desc'])
  v={'verifiedRules':True,'movementRules':True,'type':typ,'level':int(d['stage']),'cost':1,'text':text,'target':'auto','effect':'movement-form' if typ=='form' else 'movement-combat' if typ=='combat' else '', 'keywords':[],'timing':'main','responseTo':[],'formHooks':[],'formRules':{},'formAbility':text if typ=='form' else '', 'sources':[s['id'] for s in source],'verificationPending':pending,'ruleFidelity':{'status':'source-backed-pending','pending':pending},'value':{'attack':int(d['ll'] or 0),'hp':int(d['sm'] or 0)} if typ=='form' else int(d['ll'] or 0),'combatOption':{'shield':int(d['sm'] or 0)} if typ=='combat' else {}}
  if cid in ['c16308','c13307','c13908']:v.update(type='awakening',effect='movement-deer-awaken' if cid=='c16308' else 'movement-awaken',value={'attack':int(d['ll'] or 0),'hp':int(d['sm'] or 0)})
  o['cards'][cid]=v
C=o['cards']
def conf(cid,mode,action=None,**kwargs):
 C[cid]['movementMode']=mode
 if action:C[cid]['effect']=action
 C[cid].update(kwargs)
conf('c16301','deer-blessing',formRules={'deerCombat':'blessing'})
conf('c16302','forest-aid','movement-blessing',target='ally-unit',movementBurstOptions=[2])
conf('c16303','forest-force','movement-forest-force',target='any-unit',movementBurstOptions=[2])
conf('c16304','deer-self',formRules={'deerCombat':'self'},text='每回合一次，当小鹿男攻击或被攻击时，获得1能量和1护甲。',formAbility='每回合一次，当小鹿男攻击或被攻击时，获得1能量和1护甲。')
conf('c16305','deer-veil','movement-veil',target='ally-unit')
conf('c16306','deer-collision',keywords=['pierce'],movementBurstOptions=[2,4,8])
conf('c16307','deer-life',formRules={'deerCombat':'life'})
conf('c16308','deer-awaken',allowKnockedSource=True)
conf('c13301','axe',movementBurstOptions=[3])
conf('c13302','weasel-cooperate','movement-cooperate',keywords=['instant'],level=1)
conf('c13303','weasel-crowd',value={'attack':3,'hp':5},formRules={'chargePower':True})
conf('c13304','spear',combatOption={'shield':1,'movementCombat':'spear'},movementBurstOptions=[4],text='对敌方角色造成伤害后，使其获得2破甲。\n爆能4：额外使用「三太郎之斧」。')
conf('c13305','weasel-redirect',level=2,value=2,autoResponse='source-attacked',responseModifiesCombat=True,text='镰鼬本次交战目标改为另一个敌方角色并免疫战斗伤害。\n响应：当镰鼬被攻击时，自动使用此牌。',keywords=['response'])
conf('c13306','weasel-immortal',formRules={'weaselImmortal':True})
conf('c13307','weasel-awaken')
conf('c13308','club',combatOption={'shield':2,'movementCombat':'club'},movementBurstOptions=[3,7],text='对敌方角色造成伤害后，使其眩晕且本回合力量变为0。\n爆能3：额外使用「二太郎之戟」。\n爆能7：再额外使用「三太郎之斧」。')
conf('c13901','crow-wind','movement-crow-move',value=1,keywords=['instant'])
conf('c13902','crow-justice')
conf('c13903','crow-feather','movement-crow-feather',target='enemy-unit')
conf('c13904','crow-drain',formRules={'crowDrain':True})
conf('c13905','crow-dodge','movement-crow-dodge',autoResponse='source-attacked',responseModifiesCombat=True,keywords=['response'])
conf('c13906','crow-victory')
conf('c13907','crow-hold','movement-crow-hold',target='enemy-unit')
conf('c13908','crow-awaken')
for c in C.values():
 if c['type']=='form':c['value']['setBase']=True
 c['officialText']=c['text'];c['effects']=[{'condition':'always','action':c['effect'],'target':'selected' if c['target']!='auto' else 'source','value':c['value']}]
# Confirmed normal-mode blessing update is a separate backfill of only one card.
base=json.loads(Path('godot/content/verified_rules.json').read_text())['cards']['c12702']
b=base.copy();b.update(target='ally-unit',officialText='使一个己方式神获得1力量与1生命。增强：本局游戏若你骰子投出三次6点，该式神额外获得2力量与2生命和迅捷。',text='使一个己方式神获得1力量与1生命。\n增强：本局游戏若你骰子投出三次6点，该式神额外获得2力量与2生命和迅捷。',effect='fortune-blessing',effects=[{'condition':'always','action':'fortune-blessing','target':'selected-ally','value':{'attack':1,'hp':1}}],sources=base['sources']+['rabbit-blessing-20210330'])
backfill={'sources':[{'id':'rabbit-blessing-20210330','title':'官方2021年3月30日维护公告常规平衡性改动','url':'https://www.taptap.cn/moment/125748579607252242','scope':'送祝福限己方；三次6额外+2/+2和迅捷'}],'units':{},'cards':{'c12702':b}}
Path(__file__).with_name('overlay.json').write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
Path(__file__).with_name('backfill_overlay.json').write_text(json.dumps(backfill,ensure_ascii=False,indent=2)+'\n')
print('OVERLAY',len(o['units']),len(o['cards']))
