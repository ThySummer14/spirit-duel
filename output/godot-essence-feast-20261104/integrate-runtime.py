from pathlib import Path
root=Path(__file__).resolve().parents[2];changes={}
def add(path,anchor,replacement,count=1):
 p=root/path;s=changes.get(path,p.read_text())
 if replacement in s:return
 if s.count(anchor)!=count:raise RuntimeError((path,s.count(anchor),anchor[:100]))
 changes[path]=s.replace(anchor,replacement)
p='godot/scripts/verified_card_rules.gd'
add(p,'const Cooking := preload("res://scripts/cooking_rules.gd")','const Cooking := preload("res://scripts/cooking_rules.gd")\nconst EssenceFeast := preload("res://scripts/essence_feast_rules.gd")')
add(p,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:','static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n\tif EssenceFeast.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
add(p,'\tArakawa.announced(gs,frame,announced)','\tArakawa.announced(gs,frame,announced)\n\tEssenceFeast.announced(gs,frame,announced)')
add(p,'\tArakawa.announced(gs,frame,card)','\tArakawa.announced(gs,frame,card)\n\tEssenceFeast.announced(gs,frame,card)')
p='godot/scripts/game_state.gd'
add(p,'\tif VerifiedRules.Cooking.resolve_frame(self,frame):return','\tif VerifiedRules.EssenceFeast.resolve_frame(self,frame):return\n\tif VerifiedRules.Cooking.resolve_frame(self,frame):return')
add(p,'\tif not VerifiedRules.Cooking.food_kind(inst).is_empty():','\tif inst.get("definitionId","")=="shengmingjinghua":return VerifiedRules.EssenceFeast.essence_card(self,p_idx,inst)\n\tif not VerifiedRules.Cooking.food_kind(inst).is_empty():')
add(p,'\tcard = VerifiedRules.Cooking.describe_card(self,p_idx,inst,card)','\tcard = VerifiedRules.Cooking.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.EssenceFeast.describe_card(self,p_idx,inst,card)')
add(p,'\tif card.get("neutralFood",false):return VerifiedRules.Cooking.food_targets(self,p_idx,card)','\tif card.get("neutralEssence",false):return VerifiedRules.EssenceFeast.essence_targets(self,p_idx)\n\tvar ef_targets=VerifiedRules.EssenceFeast.targets(self,p_idx,card)\n\tif ef_targets!=null:return ef_targets\n\tif card.get("neutralFood",false):return VerifiedRules.Cooking.food_targets(self,p_idx,card)')
add(p,'\tif card.get("neutralFood",false):\n\t\tif not ignore_hand_restriction','\tif card.get("neutralEssence",false):\n\t\tif not ignore_hand_restriction and VerifiedRules.KoiFragrance.restricted(self,p_idx,card):return {"ok":false,"reason":"缚梦明香：请先使用蚀印牌。"}\n\t\treturn VerifiedRules.EssenceFeast.can_play_essence(self,p_idx,hand_index,target_id)\n\tif card.get("neutralFood",false):\n\t\tif not ignore_hand_restriction')
add(p,'\tif not VerifiedRules.Cooking.can_use(self,p_idx,card):','\tif not VerifiedRules.EssenceFeast.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}\n\tif not VerifiedRules.Cooking.can_use(self,p_idx,card):')
add(p,'func play_card(p_idx: int, hand_index: int, target_id: Variant = null, use_origin: bool = false) -> bool:','func play_card(p_idx: int, hand_index: int, target_id: Variant = null, use_origin: bool = false) -> bool:\n\tif not use_origin and card_instance(p_idx,hand_index).get("definitionId","")=="shengmingjinghua":return VerifiedRules.EssenceFeast.play_essence(self,p_idx,hand_index,target_id)')
add(p,'not card.get("neutralFood",false) and VerifiedRules.ThreeTail.free_first','not card.get("neutralFood",false) and not card.get("neutralEssence",false) and VerifiedRules.ThreeTail.free_first')
add(p,'\tVerifiedRules.SugarCat.form_entered(self,p_idx,src,card)','\tVerifiedRules.SugarCat.form_entered(self,p_idx,src,card)\n\tVerifiedRules.EssenceFeast.form_entered(self,p_idx,src,card)')
add(p,'\tVerifiedRules.SugarCat.begin_turn(self,p_idx)','\tVerifiedRules.SugarCat.begin_turn(self,p_idx)\n\tVerifiedRules.EssenceFeast.begin_turn(self,p_idx)')
add(p,'\t\tVerifiedRules.SugarCat.remove_departed(self)','\t\tVerifiedRules.SugarCat.remove_departed(self)\n\t\tVerifiedRules.EssenceFeast.remove_departed(self)',2)
add(p,'\tVerifiedRules.Jorogumo.before_attack(self,p_idx,unit_index)','\tVerifiedRules.EssenceFeast.attack_started(self,p_idx,unit_index)\n\tVerifiedRules.Jorogumo.before_attack(self,p_idx,unit_index)')
add(p,'\tVerifiedRules.Fortune.before_attacked(self, e_idx, fi)','\tVerifiedRules.EssenceFeast.before_attacked(self,e_idx,fi)\n\tVerifiedRules.Fortune.before_attacked(self, e_idx, fi)')
add(p,'\tVerifiedRules.Susanoo.finish_duel(self,options)','\tVerifiedRules.EssenceFeast.combat_finished(self,owner,src)\n\tVerifiedRules.Susanoo.finish_duel(self,options)')
add(p,'\tif u.get("scSummon",false): VerifiedRules.SugarCat.summoned_knockout(self,victim,u)','\tif u.get("scSummon",false): VerifiedRules.SugarCat.summoned_knockout(self,victim,u)\n\tif u.get("efPowderBoxSummon",false): VerifiedRules.EssenceFeast.remove_box(self,victim,u)')
p='godot/scripts/combat_keyword_rules.gd'
add(p,'\tgs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,idx,result,options)','\tgs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,idx,result,options)\n\tgs.VerifiedRules.EssenceFeast.combat_dealt(gs,owner,src,result)')
add(p,'\t\tgs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)','\t\tgs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)\n\t\tgs.VerifiedRules.EssenceFeast.combat_dealt(gs,owner,src,{"dealt":dealt})')
p='godot/scripts/weaver_rules.gd'
add(p,'\t\tif old.get("scSummon",false):','\t\tif old.get("efPowderBoxSummon",false): gs.VerifiedRules.EssenceFeast.remove_box(gs,owner,old)\n\t\tif old.get("scSummon",false):')
add(p,'\tgs.VerifiedRules.SugarCat.revived(gs,owner,idx)','\tvar ef_fused:int=gs.VerifiedRules.EssenceFeast.fuse_revived(gs,owner,idx)\n\tif ef_fused>=0:return ef_fused\n\tgs.VerifiedRules.SugarCat.revived(gs,owner,idx)')
p='godot/scripts/movement_rules.gd'
add(p,' if unit.get("summoned", false):',' if unit.get("summoned", false):\n  if unit.get("efPowderBoxSummon",false):\n   gs.VerifiedRules.EssenceFeast.remove_box(gs,owner,unit)\n   return true')
p='godot/scripts/game_ai.gd'
add(p,'\tvar cook_score=_gs.VerifiedRules.Cooking.score_card(_gs,p_idx,card,_target)','\tvar ef_score=_gs.VerifiedRules.EssenceFeast.score_card(_gs,p_idx,card,_target)\n\tif ef_score!=null:return int(ef_score)\n\tvar cook_score=_gs.VerifiedRules.Cooking.score_card(_gs,p_idx,card,_target)')
p='godot/scripts/ui/battle_status.gd'
add(p,'\tview.cookingMarks=gs.VerifiedRules.Cooking.marks(gs,owner,view)','\tview.efMarks=gs.VerifiedRules.EssenceFeast.marks(gs,owner,view)\n\tview.cookingMarks=gs.VerifiedRules.Cooking.marks(gs,owner,view)')
add(p,'\tfor detail in unit.get("cookingMarks",[]):','\tfor detail in unit.get("efMarks",[]):result.append(mark("essence-feast",str(detail),str(detail),"d8b0c2"))\n\tfor detail in unit.get("cookingMarks",[]):')
# Parent completes healed/full-life callback, avatar final-damage observer, unit final-damage replacement,
# KO ledger and SunSmoke.paper reset after reviewing common lifecycle integration.
for path,value in changes.items():(root/path).write_text(value)
print('ESSENCE_FEAST_INTEGRATED',len(changes))
