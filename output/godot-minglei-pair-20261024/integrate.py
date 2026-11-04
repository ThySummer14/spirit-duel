from pathlib import Path
import json

def edit(path,a,b):
 p=Path(path);s=p.read_text();assert s.count(a)==1,(path,a,s.count(a));p.write_text(s.replace(a,b))
p='godot/scripts/verified_card_rules.gd'
edit(p,'const Susanoo :=','const HandBlessing := preload("res://scripts/hand_blessing_rules.gd")\nconst KoiFragrance := preload("res://scripts/koi_fragrance_rules.gd")\nconst Susanoo :=')
edit(p,'\tif Susanoo.resolve_action','\tif KoiFragrance.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true\n\tif Susanoo.resolve_action')
edit(p,'static func end_turn(gs, p_idx: int) -> void:\n','static func end_turn(gs, p_idx: int) -> void:\n\tKoiFragrance.end_turn(gs)\n')
edit(p,'static func knocked_out(unit: Dictionary) -> void:\n','static func knocked_out(unit: Dictionary) -> void:\n\tKoiFragrance.knocked_out(unit)\n')
edit(p,'\tBattleSkill.announced(gs,frame,announced)','\tKoiFragrance.announced(gs,frame,announced)\n\tBattleSkill.announced(gs,frame,announced)')
edit(p,'static func card_started(gs, p_idx: int, src: int, card: Dictionary, automatic: bool) -> void:\n','static func card_started(gs, p_idx: int, src: int, card: Dictionary, automatic: bool) -> void:\n\tHandBlessing.started(gs,p_idx,src,card)\n')
p='godot/scripts/game_state.gd'
edit(p,'return VerifiedRules.SpiderLily.describe_card(self, p_idx, inst, card, hand_index == p.hand.size())','return VerifiedRules.HandBlessing.describe_card(self,p_idx,inst,VerifiedRules.SpiderLily.describe_card(self, p_idx, inst, card, hand_index == p.hand.size()))')
edit(p,'func can_play_card(p_idx: int, hand_index: int, target_id: Variant = null, use_origin: bool = false) -> Dictionary:', 'func can_play_card(p_idx: int, hand_index: int, target_id: Variant = null, use_origin: bool = false, ignore_hand_restriction: bool = false) -> Dictionary:')
edit(p,'\tif not VerifiedRules.Susanoo.can_use','\tif not VerifiedRules.HandBlessing.can_use(card): return {"ok":false,"reason":"被蚀印的形态生命不大于0。"}\n\tif not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self,p_idx,card): return {"ok":false,"reason":"缚梦明香：请先使用一张可用的蚀印手牌。"}\n\tif not VerifiedRules.KoiFragrance.can_use(self,p_idx,card): return {"ok":false,"reason":"此式神已经觉醒。"}\n\tif not VerifiedRules.Susanoo.can_use')
edit(p,'for targets in [VerifiedRules.Susanoo.targets','for targets in [VerifiedRules.KoiFragrance.targets(self,p_idx,card),VerifiedRules.Susanoo.targets')
edit(p,'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type")=="hand-blessing": return VerifiedRules.HandBlessing.resolve_choice(self,p_idx,instance_id)\n')
edit(p,'\tif VerifiedRules.Susanoo.resolve_frame','\tif VerifiedRules.HandBlessing.resolve_frame(self,frame): return\n\tif VerifiedRules.KoiFragrance.resolve_frame(self,frame): return\n\tif VerifiedRules.Susanoo.resolve_frame')
edit(p,'\t\tVerifiedRules.SpellReplay.completed(self, frame, card)','\t\tVerifiedRules.HandBlessing.completed(self,p_idx,src,card)\n\t\tVerifiedRules.SpellReplay.completed(self, frame, card)')
edit(p,'\t\tif VerifiedRules.BondDream.drawn(self, p_idx, card):','\t\tvar koi_triggered:=VerifiedRules.KoiFragrance.drawn(self,p_idx)\n\t\tvar bond_triggered:=VerifiedRules.BondDream.drawn(self,p_idx,card)\n\t\tif koi_triggered or bond_triggered:')
edit(p,'\tif int(u.hp) <= 0 or amount <= 0:\n','\tif not shell_modified and not transfer_pending: amount=maxi(0,amount+VerifiedRules.HandBlessing.damage_delta(self,_src_player,source_index,combat))\n\tif int(u.hp) <= 0 or amount <= 0:\n')
edit(p,'func _damage_avatar(p_idx: int, amount: int, _src_player: int = -1, source_index: int = -1, critical: bool = false, combat: bool = false, shell_modified: bool = false) -> int:\n','func _damage_avatar(p_idx: int, amount: int, _src_player: int = -1, source_index: int = -1, critical: bool = false, combat: bool = false, shell_modified: bool = false) -> int:\n\tif not shell_modified: amount=maxi(0,amount+VerifiedRules.HandBlessing.damage_delta(self,_src_player,source_index,combat))\n')
edit(p,'\tVerifiedRules.Movement.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)','\tVerifiedRules.KoiFragrance.avatar_damage(self,_src_player,source_index,p_idx,actual_loss,combat)\n\tVerifiedRules.Movement.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)')
edit(p,'\tVerifiedRules.Susanoo.form_entered(self,p_idx,src,card)','\tVerifiedRules.HandBlessing.form_entered(self,p_idx,src,card)\n\tVerifiedRules.KoiFragrance.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Susanoo.form_entered(self,p_idx,src,card)')
edit(p,'\t_log("%s 部署幻境「%s」。"','\tVerifiedRules.HandBlessing.realm_entered(self,p_idx,card)\n\t_log("%s 部署幻境「%s」。"')
edit(p,'\tVerifiedRules.Glutton.turn_start(self,p_idx)','\tVerifiedRules.KoiFragrance.turn_start(self,p_idx)\n\tVerifiedRules.Glutton.turn_start(self,p_idx)')
edit(p,'\t\t\tVerifiedRules.Susanoo.form_turn_start(self,p_idx,i)','\t\t\tVerifiedRules.KoiFragrance.form_turn_start(self,p_idx,i)\n\t\t\tVerifiedRules.Susanoo.form_turn_start(self,p_idx,i)')
p='godot/scripts/game_ai.gd'
edit(p,'\tvar susanoo_score =','\tvar pair_score = _gs.VerifiedRules.KoiFragrance.score_card(_gs,p_idx,card,_target)\n\tif pair_score != null: return int(pair_score)\n\tvar susanoo_score =')
edit(p,'static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n','static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n\tvar hand_choice=gs.VerifiedRules.HandBlessing.ai_choice(gs,p_idx)\n\tif hand_choice!=null: return bool(hand_choice)\n')
p='godot/scripts/combat_keyword_rules.gd';edit(p,'unit.get("formRules", {}).get("combatKeywords", []),','unit.get("formRules", {}).get("combatKeywords", []), unit.get("formRules",{}).get("handCharmKeywords",[]),')
p='godot/scripts/ui/battle_screen.gd'
edit(p,'\t\tvar divination_choice_card =','\t\tvar hand_choice_card=gs.VerifiedRules.HandBlessing.choice_card(gs,PLAYER,str(iid))\n\t\tif hand_choice_card!=null: def=hand_choice_card\n\t\tvar divination_choice_card =')
edit(p,'gs.pending_choice.get("type")=="goldfish-upgrade":','gs.pending_choice.get("type") in ["goldfish-upgrade","hand-blessing"]:')
edit(p,'ThemeBuilder.dim_label(str(def.get("text","")),14)','ThemeBuilder.dim_label(str(def.get("choiceExplanation",def.get("text",""))),14)')
p='godot/scripts/ui/battle_status.gd';edit(p,'\tview.susanooMarks=','\tview.koiFragranceMarks=gs.VerifiedRules.KoiFragrance.unit_marks(gs,owner,idx)\n\tview.susanooMarks=');edit(p,'\tfor detail in unit.get("susanooMarks",[]):','\tfor detail in unit.get("koiFragranceMarks",[]): result.append(mark("koi-fragrance-rule",str(detail),str(detail),"90c8b8"))\n\tfor detail in unit.get("susanooMarks",[]):')
p='godot/scripts/ui/battle_effect_cues.gd';edit(p,'"whale-tooth-hit",','"whale-tooth-hit", "fragrance-projectile",')
p='godot/scripts/ui/keyword_glossary.gd';edit(p,'const ENTRIES := {','const ENTRIES := {\n\t"ward": ["加护", "从随机展示的两张未加护手牌中选择一张，附上展示的随机增益；与蚀印互相抵消。"],\n\t"erosion": ["蚀印", "从敌方随机展示的两张未蚀印手牌中选择一张，附上展示的随机减益并展示该牌；与加护互相抵消。"],')
p='scripts/godot-verify.sh';edit(p,'verify_susanoo verify_combat','verify_susanoo verify_koi_fragrance verify_combat')
p=Path('godot/content/verified_rules.json');d=json.loads(p.read_text());raw={int(x['id']):x for x in json.load(open('research-data/cards.json'))}
sources=['koi-fragrance-original-faces','koi-fragrance-official-snapshot','hand-marks-official','hand-marks-effect-transcription']
d['sources'] += [{'id':sources[0],'path':'art-reference-official/卡面-按版本/17_鸣雷启蛰','evidence':'28200–28208及28800–28808完整主体PNG；采用现有基础版本，不加入新版寻香行使用蚀印牌投射或赤鲤跃波额外护甲。'},{'id':sources[1],'url':'https://ssr.res.netease.com/pc/zt/20191112204330/js/index_4539655c.js','evidence':'两位角色18个定义与已保存官网响应逐字段比较。'},{'id':sources[2],'url':'https://www.taptap.cn/moment/383678408556548050','evidence':'2023-03-11官方加护/蚀印说明图：随机两张、选择一张和抵消；原图已保存。'},{'id':sources[3],'url':'https://gamerch.com/onmyojicard/217550','evidence':'2023-06效果表转录；与https://www.taptap.cn/moment/467093870207830538交叉核对类型效果、同类不叠、形态零生命不可用、抵消与选中牌展示。'}]
pending=['本批按两位角色基础完整PNG实现主要机制；指定录像逐牌和所有组合尚未完成核验。加护/蚀印随机效果池取补充转录，其中使用后自身治疗的精确定义、抵消是否计入触发、与形态原生特殊关键词/融合/复制/蓄力的全部关系、额外牌候选/双效果的随机分布，以及缚梦明香在响应、起源和多宿主时的全序仍待原客户端确认；不以程序通过冒充全库还原。']
for id,r,atk,hp in [('liyujing','koi',3,4),('xunxiangxing','fragrance',3,4)]:
 n=282 if r=='koi' else 288;basic=raw[n*100]['desc'].replace('#[力量]','力量').replace('#[生命]','生命');awake=raw[n*100+6 if r=='koi' else n*100+5]['desc'].split('觉醒：')[-1].replace('#[力量]','力量').replace('#[生命]','生命')
 d['units'][id]={'verifiedRules':True,'koiFragranceRole':r,'attack':atk,'maxHp':hp,'passive':{'id':r+'-hand-mark','name':'加护' if r=='koi' else '蚀印','text':basic,'hooks':[]},'awakenedPassive':{'id':r+'-hand-mark-awakened','name':'觉醒','text':awake,'hooks':[]},'formLifecycle':{},'sources':sources,'verificationPending':pending}
for role in [282,288]:
 for n in range(1,9):
  id=f'c{role}{n:02}';r=raw[role*100+n];typ='form' if (role==282 and n in [3,8]) or (role==288 and n in [2,8]) else 'realm' if (role==282 and n==4) or (role==288 and n==3) else 'spell';text=r['desc'].replace('#r','\n').replace('#[力量]','力量').replace('#[生命]','生命').replace('#[护甲]','护甲').replace('#[破甲]','破甲');value={'attack':int(r['ll']),'hp':int(r['sm']),'setBase':True} if typ=='form' else 0
  def e(action,val=0,target='source'):return {'action':action,'target':target,'value':val}
  if role==282:
   effects={1:[e('pair-ward')],2:[e('pair-ward'),e('pair-count-heal')],3:[e('form',value)],4:[e('pair-koi-realm')],5:[e('damage',4,'selected-enemy'),e('pair-ward')],6:[e('pair-ward'),e('pair-awaken')],7:[e('draw',2,'ally-player'),e('pair-ward'),e('pair-ward')],8:[e('form',value)]}[n]
   rules={3:{'koiEntryWard':True,'koiExtra':True},8:{'koiEntryDraw':True,'koiDrawWard':True,'koiDouble':True}}.get(n,{})
  else:
   effects={1:[e('pair-erosion')],2:[e('form',value)],3:[e('pair-fragrance-realm')],4:[e('damage',4,'selected-enemy'),e('pair-erosion')],5:[e('pair-erosion'),e('pair-awaken')],6:[e('pair-erosion')],7:[e('pair-erosion'),e('damage',3,'all-enemy-units')],8:[e('form',value)]}[n]
   rules={2:{'combatKeywords':['remote'],'fragranceBattleErosion':True},8:{'fragranceTick':True,'fragranceForce':True}}.get(n,{})
  c={'verifiedRules':True,'koiFragranceRules':True,'type':typ,'typeLabel':{'spell':'法术牌','form':'形态牌','realm':'幻境牌'}[typ],'level':int(r['stage']),'cost':1,'text':text,'officialText':text,'target':'any-unit' if role==282 and n==5 else 'enemy-unit' if role==288 and n==4 else 'auto','effect':effects[0]['action'],'value':value,'effects':effects,'keywords':['battle-skill','ward'] if role==282 and n==1 else ['remote'] if role==288 and n==2 else [],'timing':'main','responseTo':[],'autoResponse':'','formRules':rules,'formHooks':[],'formAbility':text if typ=='form' else '', 'sources':sources,'verificationPending':pending}
  if role==282 and n==1:c['battleSkill']=True
  if role==282 and n==4:c['realm']={'hp':6,'nativeRealm':'koi-stream','trigger':'none','triggerEffect':''}
  if role==288 and n==3:c['realm']={'hp':5,'nativeRealm':'fragrance-pressure','trigger':'none','triggerEffect':''}
  if role==288 and n in [1,6]:c['erosionAfter']={'after':'stun' if n==1 else 'discard'}
  d['cards'][id]=c
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('KOI_FRAGRANCE_INTEGRATED')
