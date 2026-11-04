from pathlib import Path

def edit(path,old,new):
 p=Path(path);s=p.read_text();assert s.count(old)==1,(path,s.count(old),old[:100]);p.write_text(s.replace(old,new))
base='godot/scripts/'
edit(base+'verified_card_rules.gd','const Toxic :=','const SilkNinja := preload("res://scripts/silk_ninja_rules.gd")\nconst Toxic :=')
edit(base+'verified_card_rules.gd','\tif Toxic.resolve_action','\tif SilkNinja.resolve_action(gs,p_idx,src,card,effect,target): return true\n\tif Toxic.resolve_action')
edit(base+'verified_card_rules.gd','\tSpiderLily.announced(gs,frame,announced)','\tSilkNinja.announced(gs,frame,announced)\n\tSpiderLily.announced(gs,frame,announced)')
edit(base+'verified_card_rules.gd','\t\tvar src: int = gs._source_index(owner, card)\n\t\tif src < 0: continue','\t\tif response=="toxic-enemy-attacking" and (target_id not in SilkNinja.targets(gs,owner,card)):continue\n\t\tvar src: int = gs._source_index(owner, card)\n\t\tif src < 0: continue')
edit(base+'game_state.gd','\tcard = VerifiedRules.Cotton.describe_card(self, p_idx, inst, card)','\tcard = VerifiedRules.Cotton.describe_card(self, p_idx, inst, card)\n\tcard = VerifiedRules.SilkNinja.describe_card(self,p_idx,inst,card)')
edit(base+'game_state.gd','for targets in [VerifiedRules.Toxic.targets','for targets in [VerifiedRules.SilkNinja.targets(self,p_idx,card),VerifiedRules.Toxic.targets')
edit(base+'game_state.gd','\tif not VerifiedRules.Toxic.can_use','\tif not VerifiedRules.SilkNinja.can_use(self,p_idx,card): return {"ok":false,"reason":"此觉醒已使用。"}\n\tif not VerifiedRules.Toxic.can_use')
edit(base+'game_state.gd','\tif VerifiedRules.Toxic.resolve_frame','\tif VerifiedRules.SilkNinja.resolve_frame(self,frame): return\n\tif VerifiedRules.Toxic.resolve_frame')
edit(base+'game_state.gd','\tvar toxic_saved:=','\tvar silk_saved:=VerifiedRules.SilkNinja.death_frames(self,victim,u)\n\tvar silk_extra:=VerifiedRules.SilkNinja.knockout_extra(self,victim,u)\n\tvar toxic_saved:=')
edit(base+'game_state.gd','\tknockout_extra += VerifiedRules.Pine.knockout_extra(u)','\tknockout_extra += VerifiedRules.Pine.knockout_extra(u)+silk_extra')
edit(base+'game_state.gd','\tresolution_stack.append_array(toxic_saved)','\tresolution_stack.append_array(toxic_saved)\n\tresolution_stack.append_array(silk_saved)')
edit(base+'game_state.gd','\tVerifiedRules.KoiFragrance.turn_start(self,p_idx)','\tVerifiedRules.SilkNinja.turn_start(self,p_idx)\n\tVerifiedRules.KoiFragrance.turn_start(self,p_idx)')
# Called before armor/encourage application, so a suspended response does not duplicate either.
edit(base+'game_state.gd','\tif not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0: return\n\tvar bonus := int(frame.bonus)','\tif not VerifiedRules.Samurai.combat_available(attacker,frame.options) or winner >= 0: return\n\tif VerifiedRules.SilkNinja.before_response(self,frame): return\n\tvar bonus := int(frame.bonus)')
edit(base+'game_state.gd','\tVerifiedRules.Susanoo.begin_duel(self,frame)','\tVerifiedRules.SilkNinja.prepare_combat(self,frame)\n\tVerifiedRules.Susanoo.begin_duel(self,frame)')
edit(base+'game_state.gd','\t\td_options.toxicAttack=','\t\td_options.silkCombatId=options.get("silkCombatId",-1)\n\t\td_options.sourceWasPoisoned=defender.get("toxicPoisoned",false)\n\t\td_options.toxicAttack=')
edit(base+'combat_keyword_rules.gd','\tif options.get("removeArmor", false) or has(source, "penetration"):\n\t\tstrip_protection(gs, victim, idx, has(source, "penetration"))','\tif options.get("removeArmor", false) or options.get("penetration",false) or has(source, "penetration"):\n\t\tstrip_protection(gs, victim, idx, options.get("penetration",false) or has(source, "penetration"))\n\timmune=immune or gs.VerifiedRules.SilkNinja.damage_immune(gs,owner,src,victim,idx,amount,options)')
edit(base+'game_ai.gd','\tvar toxic_score=','\tvar silk_score=_gs.VerifiedRules.SilkNinja.score_card(_gs,p_idx,card,_target)\n\tif silk_score!=null:return int(silk_score)\n\tvar toxic_score=')
edit(base+'ui/battle_status.gd','\tview.toxicMarks=gs.VerifiedRules.Toxic.unit_marks(gs,owner,idx)','\tview.toxicMarks=gs.VerifiedRules.Toxic.unit_marks(gs,owner,idx)+gs.VerifiedRules.SilkNinja.marks(gs,owner,idx)')
edit('scripts/godot-verify.sh','verify_toxic_pair.gd','verify_toxic_pair.gd verify_silk_ninja.gd')
print('integrated native rule owners')
