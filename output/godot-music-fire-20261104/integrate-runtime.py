from pathlib import Path
root=Path(__file__).resolve().parents[2];changes={}
def add(path,anchor,new,count=1):
 p=root/path;s=changes.get(p,p.read_text())
 if s.count(new)==count:return
 assert s.count(anchor)==count,(path,anchor[:100],s.count(anchor),count)
 changes[p]=s.replace(anchor,new)
p='godot/scripts/verified_card_rules.gd'
add(p,'const Cooking := preload("res://scripts/cooking_rules.gd")','const Cooking := preload("res://scripts/cooking_rules.gd")\nconst MusicFire := preload("res://scripts/music_fire_rules.gd")')
add(p,'static func event(gs, kind: String, details: Dictionary) -> void:','static func event(gs, kind: String, details: Dictionary) -> void:\n\tMusicFire.rule_event(gs,kind,details)')
add(p,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:','static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n\tif MusicFire.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
add(p,'\tCooking.end_turn(gs,p_idx)','\tMusicFire.end_turn(gs,p_idx)\n\tCooking.end_turn(gs,p_idx)')
add(p,'\t\tif not Zhenjian.can_use(gs,owner,card):continue','\t\tif not MusicFire.can_use(gs,owner,card):continue\n\t\tif not Zhenjian.can_use(gs,owner,card):continue')
p='godot/scripts/game_state.gd'
add(p,'\tif VerifiedRules.Cooking.resolve_frame(self,frame):return','\tif VerifiedRules.MusicFire.resolve_frame(self,frame):return\n\tif VerifiedRules.Cooking.resolve_frame(self,frame):return')
add(p,'\tcard = VerifiedRules.Cooking.describe_card(self,p_idx,inst,card)','\tcard = VerifiedRules.Cooking.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.MusicFire.describe_card(self,p_idx,inst,card)')
add(p,'\tif not VerifiedRules.Cooking.can_use(self,p_idx,card):','\tif not VerifiedRules.MusicFire.can_use(self,p_idx,card):return {"ok":false,"reason":"紧那罗已经觉醒，或当前无神火铃焰可响应。"}\n\tif not VerifiedRules.Cooking.can_use(self,p_idx,card):')
add(p,'\tif card.get("neutralFood",false):return VerifiedRules.Cooking.food_targets(self,p_idx,card)','\tif card.get("neutralFood",false):return VerifiedRules.Cooking.food_targets(self,p_idx,card)\n\tvar mf_targets=VerifiedRules.MusicFire.targets(self,p_idx,card)\n\tif mf_targets!=null:return mf_targets')
add(p,'\tVerifiedRules.TreeSakura.turn_start(self, p_idx)','\tVerifiedRules.TreeSakura.turn_start(self, p_idx)\n\tVerifiedRules.MusicFire.begin_turn(self,p_idx)')
add(p,'\t\tVerifiedRules.Cooking.completed(self,frame,card)','\t\tVerifiedRules.MusicFire.completed(self,frame,card)\n\t\tVerifiedRules.Cooking.completed(self,frame,card)')
add(p,'\tVerifiedRules.Cooking.form_entered(self,p_idx,src,card)','\tVerifiedRules.MusicFire.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Cooking.form_entered(self,p_idx,src,card)')
add(p,'\tif VerifiedRules.Cooking.trigger_realm(self,p_idx,realm):return','\tif VerifiedRules.MusicFire.trigger_realm(self,p_idx,realm):return\n\tif VerifiedRules.Cooking.trigger_realm(self,p_idx,realm):return')
add(p,'\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)','\tunit.attack += VerifiedRules.MusicFire.power_delta(self,unit)\n\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)')
add(p,'\t_log("%s 恢复 %d 点生命。" % [unit.name, healed], TONE_SUCCESS)','\t_log("%s 恢复 %d 点生命。" % [unit.name, healed], TONE_SUCCESS)\n\tVerifiedRules.MusicFire.healed(self,unit)')
add(p,'\tif victim>=0: VerifiedRules.Glutton.mark_hand(self,victim)','\tif victim>=0 and VerifiedRules.MusicFire.before_knockout(self,victim,u):return\n\tif victim>=0: VerifiedRules.Glutton.mark_hand(self,victim)')
add(p,'\tVerifiedRules.knocked_out(u)','\tVerifiedRules.knocked_out(u)\n\tVerifiedRules.MusicFire.after_knockout(self,victim,u)')
add(p,'\tif u.get("scSummon",false): VerifiedRules.SugarCat.summoned_knockout(self,victim,u)','\tif u.get("mfDoll",false): VerifiedRules.MusicFire.summoned_knockout(self,victim,u)\n\tif u.get("scSummon",false): VerifiedRules.SugarCat.summoned_knockout(self,victim,u)')
add(p,'\t\tVerifiedRules.SugarCat.remove_departed(self)','\t\tVerifiedRules.MusicFire.remove_departed(self)\n\t\tVerifiedRules.SugarCat.remove_departed(self)',count=2)
add(p,'\tif not shell_modified and not transfer_pending: amount+=VerifiedRules.Maple.damage_bonus(self,_src_player,source_index,combat)','\tif not shell_modified and not transfer_pending: amount+=VerifiedRules.Maple.damage_bonus(self,_src_player,source_index,combat)\n\tvar mf_conversion=VerifiedRules.MusicFire.damage_replacement(self,p_idx,unit_index,amount,_src_player,source_index,combat)\n\tif mf_conversion!=null:return mf_conversion')
add(p,'func _resolve_combat_entered(frame: Dictionary) -> void:','func _resolve_combat_entered(frame: Dictionary) -> void:\n\tif VerifiedRules.MusicFire.before_attack(self,frame):return')
add(p,'func _finish_combat(owner: int, src: int, defender: Dictionary, from_reserve: bool, options: Dictionary, kills: int) -> void:','func _finish_combat(owner: int, src: int, defender: Dictionary, from_reserve: bool, options: Dictionary, kills: int) -> void:\n\tVerifiedRules.MusicFire.combat_finished(self,owner,src,defender,options)')
add(p,'\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="charged-combat":','\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="mf-combat":\n\t\tif VerifiedRules.MusicFire.respond_combat(self,int(frame.combatResponseId),p_idx,src,card):return\n\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="charged-combat":')
p='godot/scripts/combat_keyword_rules.gd'
add(p,'\timmune=immune or (idx>=0 and gs.VerifiedRules.BlueGreen.combat_immune(gs,victim,idx))','\timmune=immune or gs.VerifiedRules.MusicFire.combat_immune(gs,victim,idx)\n\timmune=immune or (idx>=0 and gs.VerifiedRules.BlueGreen.combat_immune(gs,victim,idx))')
p='godot/scripts/weaver_rules.gd'
add(p,'\t\tif old.get("scSummon",false):','\t\tif old.get("mfDoll",false): gs.VerifiedRules.MusicFire.remove_doll(gs,owner,old)\n\t\tif old.get("scSummon",false):')
p='godot/scripts/movement_rules.gd'
add(p,' if unit.get("summoned", false):',' if unit.get("summoned", false):\n  if unit.get("mfDoll",false):\n   gs.VerifiedRules.MusicFire.remove_doll(gs,owner,unit)\n   return true')
p='godot/scripts/sun_smoke_rules.gd'
add(p,'\tgs.VerifiedRules.Cooking.reset_ledger(target)','\tgs.VerifiedRules.MusicFire.reset_ledger(target)\n\tgs.VerifiedRules.Cooking.reset_ledger(target)')
p='godot/scripts/game_ai.gd'
add(p,'\tvar cook_score=_gs.VerifiedRules.Cooking.score_card(_gs,p_idx,card,_target)','\tvar mf_score=_gs.VerifiedRules.MusicFire.score_card(_gs,p_idx,card,_target)\n\tif mf_score!=null:return int(mf_score)\n\tvar cook_score=_gs.VerifiedRules.Cooking.score_card(_gs,p_idx,card,_target)')
p='godot/scripts/ui/battle_status.gd'
add(p,'\tview.cookingMarks=gs.VerifiedRules.Cooking.marks(gs,owner,view)','\tview.mfMarks=gs.VerifiedRules.MusicFire.marks(gs,owner,view)\n\tview.cookingMarks=gs.VerifiedRules.Cooking.marks(gs,owner,view)')
add(p,'\tfor detail in unit.get("cookingMarks",[]):','\tfor detail in unit.get("mfMarks",[]):result.append(mark("music-fire",str(detail),str(detail),"e49871"))\n\tfor detail in unit.get("cookingMarks",[]):')
for p,s in changes.items():p.write_text(s)
print('MUSIC_FIRE_INTEGRATED',len(changes))
