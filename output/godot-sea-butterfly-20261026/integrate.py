from pathlib import Path
import json,re
root=Path('.');out=root/'output/godot-sea-butterfly-20261026'
vpath=root/'godot/content/verified_rules.json';v=json.loads(vpath.read_text());raw={int(c['id']):c for c in json.load(open('research-data/cards.json'))}
source='sea-butterfly-original-20261026';pending=['按28700–28708基础完整卡面和官方海灵词条接入；指定录像未逐牌覆盖，仍待原客户端核验。','觉醒主动移动与能力替换先后、迁溯对存活目标的移动、海灵与多重响应/连击/即时复活的全序及月珊瑚复制增强边界仍待核验。']
v['sources'].append({'id':source,'url':'https://www.taptap.cn/moment/385126671985936324','note':'官方2023-03-15曝光图确认海灵不能叠加、眩晕/2破甲/本次战斗-2力量；主体以本地完整PNG与官网基础数据为准，碧海之蝶用正式基础PNG2/6，非预览2/7。'})
def clean(t):return re.sub(r'#\[([^]]+)\]',r'\1',t.replace('#r','\n'))
v['units']['linghaidie']={'verifiedRules':True,'seaButterflyRules':True,'attack':2,'maxHp':5,'passive':{'id':'sea-butterfly-base','name':'海灵','text':clean(raw[28700]['desc']),'hooks':[]},'awakenedPassive':{'id':'sea-butterfly-awake','name':'海灵','text':'当己方式神移入战斗区时，使其结附「海灵」。己方式神重复结附「海灵」时，投射2点伤害。','hooks':[]},'formLifecycle':{},'sources':[source],'verificationPending':pending}
def effect(action,target='source',value=0):return {'action':action,'target':target,'value':value}
for n in range(1,9):
 c=raw[28700+n];kind={'法术':'spell','形态':'form','结界':'realm'}[c['type']];text=clean(c['desc']);card={'verifiedRules':True,'seaButterflyRules':True,'type':kind,'typeLabel':{'spell':'法术牌','form':'形态牌','realm':'幻境牌'}[kind],'level':int(c['stage']),'cost':1,'text':text,'officialText':text,'target':'ally','effect':'sea-attach','value':0,'effects':[],'keywords':[],'formRules':{},'formHooks':[],'formAbility':'','timing':'main','responseTo':[],'autoResponse':'','sources':[source],'verificationPending':pending}
 if n==1:card.update(target='enemy',effect='sea-wave',effects=[effect('sea-enter'),effect('sea-enrage')])
 if n==2:card.update(keywords=['instant'],effects=[effect('sea-attach'),effect('sea-divination',value=2)])
 if n in [3,6]:
  body={'attack':int(c['ll']),'hp':int(c['sm']),'setBase':True};card.update(target='auto',effect='form',value=body,effects=[effect('form',value=body)],formAbility=text,formRules={'seaDouble':n==3,'seaAttackTrigger':n==6,'combatKeywords':['pursuit'] if n==6 else []})
 if n==4:card.update(effect='sea-awaken',value={'attack':1,'hp':1},effects=[effect('sea-move'),effect('sea-awaken',value={'attack':1,'hp':1})])
 if n==5:card.update(effect='sea-revive',allowKnockedSource=True,effects=[effect('sea-revive'),effect('sea-move')])
 if n==7:card.update(target='unit',effect='sea-coral',value=3,effects=[effect('sea-coral')])
 if n==8:card.update(effect='sea-realm',realm={'hp':10,'nativeRealm':'sea-heart','trigger':'none'},effects=[effect('sea-realm'),effect('sea-attach'),effect('sea-attack')])
 v['cards']['c'+str(c['id'])]=card
vpath.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def edit(name,old,new):
 p=Path(name);s=p.read_text();assert s.count(old)==1,(name,s.count(old),old[:90]);p.write_text(s.replace(old,new))
b='godot/scripts/'
edit(b+'verified_card_rules.gd','const SilkNinja :=','const SeaButterfly := preload("res://scripts/sea_butterfly_rules.gd")\nconst SilkNinja :=')
edit(b+'verified_card_rules.gd','\tif SilkNinja.resolve_action','\tif SeaButterfly.resolve_action(gs,p_idx,src,card,effect,target): return true\n\tif SilkNinja.resolve_action')
edit(b+'verified_card_rules.gd','\tunit.erase("spiderMark")','\tunit.erase("seaSpirit")\n\tunit.erase("spiderMark")')
edit(b+'game_state.gd','\tcard = VerifiedRules.SilkNinja.describe_card','\tcard = VerifiedRules.SeaButterfly.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.SilkNinja.describe_card')
edit(b+'game_state.gd','for targets in [VerifiedRules.SilkNinja.targets','for targets in [VerifiedRules.SeaButterfly.targets(self,p_idx,card),VerifiedRules.SilkNinja.targets')
edit(b+'game_state.gd','\tif not VerifiedRules.SilkNinja.can_use','\tif not VerifiedRules.SeaButterfly.can_use(self,p_idx,card): return {"ok":false,"reason":"灵海蝶已经觉醒。"}\n\tif not VerifiedRules.SilkNinja.can_use')
edit(b+'game_state.gd','func _fire_hooks(p_idx: int, src: int, event: String, ctx: Dictionary) -> void:\n','func _fire_hooks(p_idx: int, src: int, event: String, ctx: Dictionary) -> void:\n\tif src>=0 and event=="unit-entered-front": VerifiedRules.SeaButterfly.entered(self,p_idx,src)\n')
edit(b+'game_state.gd','\tif VerifiedRules.Cotton.before_attacked(self,frame): return','\tVerifiedRules.SeaButterfly.before_responses(self,frame)\n\tif VerifiedRules.Cotton.before_attacked(self,frame): return')
edit(b+'game_state.gd','\t\tif options.get("lightZeroAttack", false): power = 0','\t\tpower = maxi(0,power-int(options.get("seaAttackPenalty",0)))\n\t\tif options.get("lightZeroAttack", false): power = 0')
edit(b+'game_state.gd','\t\tvar d_options := {"convertCombatToArmorBreak"','\t\tcounter_power=maxi(0,counter_power-int(options.get("seaDefenderPenalty",0)))\n\t\tvar d_options := {"convertCombatToArmorBreak"')
edit(b+'game_ai.gd','\tvar silk_score=','\tvar sea_score=_gs.VerifiedRules.SeaButterfly.score_card(_gs,p_idx,card,_target)\n\tif sea_score!=null:return int(sea_score)\n\tvar silk_score=')
edit(b+'ui/battle_status.gd','\tview.toxicMarks=','\tview.seaSpiritMarks=gs.VerifiedRules.SeaButterfly.unit_marks(gs,owner,idx)\n\tview.toxicMarks=')
edit(b+'ui/battle_status.gd','\tfor detail in unit.get("toxicMarks",[]):','\tfor detail in unit.get("seaSpiritMarks",[]): result.append(mark("sea-spirit",str(detail),str(detail),"80cfce"))\n\tfor detail in unit.get("toxicMarks",[]):')
edit(b+'pipe_fox_rules.gd','\t\tif not unit.get("spiderMark",{}).is_empty()', '\t\tif not unit.get("seaSpirit",{}).is_empty() and int(unit.seaSpirit.sourceOwner)!=owner: var e:=base.duplicate(); e.key="seaSpirit"; out.append(e)\n\t\tif not unit.get("spiderMark",{}).is_empty()')
edit(b+'pipe_fox_rules.gd','"whaleTooth", "whaleBody", "spiderMark", "garudaFeather":','"whaleTooth", "whaleBody", "spiderMark", "garudaFeather", "seaSpirit":')
edit('scripts/godot-verify.sh','verify_silk_ninja verify_combat','verify_silk_ninja verify_sea_butterfly verify_combat')
print('sea butterfly overlay and entry points installed')
