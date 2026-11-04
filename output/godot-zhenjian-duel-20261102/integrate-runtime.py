from pathlib import Path
root = Path(__file__).resolve().parents[2]
changes = {}
def rep(file, old, new, n=1):
    p = root / file
    s = changes.get(p, p.read_text())
    assert s.count(old) == n, (file, old[:120], s.count(old), n)
    changes[p] = s.replace(old,new)

v='godot/scripts/verified_card_rules.gd'
rep(v,'const ChargedPair := preload("res://scripts/charged_pair_rules.gd")','const Zhenjian := preload("res://scripts/zhenjian_duel_rules.gd")\nconst ChargedPair := preload("res://scripts/charged_pair_rules.gd")')
rep(v,'static func event(gs, kind: String, details: Dictionary) -> void:\n','static func event(gs, kind: String, details: Dictionary) -> void:\n\tZhenjian.rule_event(gs,kind,details)\n')
rep(v,'\tif ChargedPair.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif Zhenjian.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif ChargedPair.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
rep(v,'\t\tif not Yitiao.can_use(gs,owner,card): continue','\t\tif not Zhenjian.can_use(gs,owner,card):continue\n\t\tif not Yitiao.can_use(gs,owner,card): continue')

g='godot/scripts/game_state.gd'
rep(g,'\tif pending_choice.get("type")=="charged-mode":return VerifiedRules.ChargedPair.resolve_choice(self,p_idx,instance_id)','\tif pending_choice.get("type")=="zd-whirl":return VerifiedRules.Zhenjian.resolve_choice(self,p_idx,instance_id)\n\tif pending_choice.get("type")=="charged-mode":return VerifiedRules.ChargedPair.resolve_choice(self,p_idx,instance_id)')
rep(g,'\tcard = VerifiedRules.ChargedPair.describe(self,p_idx,inst,card)','\tcard = VerifiedRules.ChargedPair.describe(self,p_idx,inst,card)\n\tcard = VerifiedRules.Zhenjian.describe(self,p_idx,card)')
rep(g,'\treturn VerifiedRules.Focus.quote(self,p_idx,card,payment)','\tpayment=VerifiedRules.Zhenjian.payment(self,p_idx,card,payment)\n\treturn VerifiedRules.Focus.quote(self,p_idx,card,payment)')
rep(g,'\tif not VerifiedRules.ChargedPair.can_use(self,p_idx,card):','\tif not VerifiedRules.Zhenjian.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}\n\tif not VerifiedRules.ChargedPair.can_use(self,p_idx,card):')
rep(g,'\tcard=VerifiedRules.ChargedPair.prepare_card(self,p_idx,src,card)','\tcard=VerifiedRules.ChargedPair.prepare_card(self,p_idx,src,card)\n\tcard=VerifiedRules.Zhenjian.prepare_card(self,p_idx,src,card)')
rep(g,'\tif VerifiedRules.ChargedPair.resolve_frame(self,frame):return','\tif VerifiedRules.Zhenjian.resolve_frame(self,frame):return\n\tif VerifiedRules.ChargedPair.resolve_frame(self,frame):return')
rep(g,'\t\tVerifiedRules.ChargedPair.completed(self,frame,card)','\t\tVerifiedRules.Zhenjian.completed(self,frame,card)\n\t\tVerifiedRules.ChargedPair.completed(self,frame,card)')
rep(g,'\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)','\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)\n\tunit.attack += VerifiedRules.Zhenjian.power(unit)')
rep(g,'\tVerifiedRules.ChargedPair.form_entered(self,p_idx,src,card)','\tVerifiedRules.Zhenjian.form_entered(self,p_idx,src,card)\n\tVerifiedRules.ChargedPair.form_entered(self,p_idx,src,card)')
rep(g,'\tif u.get("crabCombatImmune", false) or (combat and VerifiedRules.BlackWhite.combat_immune(u)):','\tif VerifiedRules.Zhenjian.prevents_damage(self,p_idx,unit_index,amount,combat):\n\t\t_record_spell_damage(p_idx,str(u.uid),0,true)\n\t\treturn {"damage":0,"dealt":0,"knocked":false,"overkill":0}\n\tif u.get("crabCombatImmune", false) or (combat and VerifiedRules.BlackWhite.combat_immune(u)):')
rep(g,'\tpreview = VerifiedRules.Jorogumo.received_damage(u,preview)','\tpreview = VerifiedRules.Zhenjian.reduce_damage(u,preview,combat)\n\tpreview = VerifiedRules.Jorogumo.received_damage(u,preview)')
rep(g,'\tunshielded = VerifiedRules.Jorogumo.received_damage(u,unshielded)','\tunshielded = VerifiedRules.Zhenjian.reduce_damage(u,unshielded,combat)\n\tunshielded = VerifiedRules.Jorogumo.received_damage(u,unshielded)')
rep(g,'\tif VerifiedRules.ChargedPair.defend_started(self,frame):return','\tif VerifiedRules.Zhenjian.defend_started(self,frame):return\n\tif VerifiedRules.ChargedPair.defend_started(self,frame):return')
rep(g,'\tVerifiedRules.MirrorSong.combat_finished(self,owner,src,options)','\tVerifiedRules.MirrorSong.combat_finished(self,owner,src,options)\n\tVerifiedRules.Zhenjian.combat_finished(self,owner,src,options,defender)')
rep(g,'\tVerifiedRules.Lantern.turn_start(self,p_idx)','\tVerifiedRules.Zhenjian.turn_start(self,p_idx)\n\tVerifiedRules.Lantern.turn_start(self,p_idx)')
rep(g,'func basic_attack_ex(p_idx: int, unit_index: int, bonus: int, uses_action: bool, target_id = null) -> void:', '''func release_charge(p_idx: int, unit_index: int) -> bool:
	if winner >= 0 or is_resolving or not resolution_stack.is_empty() or is_upgrade_pending(p_idx): return false
	if not VerifiedRules.Zhenjian.can_manual_release(self,p_idx,unit_index): return false
	_record("release_charge", {"unit":unit_index}, p_idx)
	if not VerifiedRules.Zhenjian.release(self,p_idx,unit_index): return false
	_resolve_resolution_stack()
	state_changed.emit()
	return true


func basic_attack_ex(p_idx: int, unit_index: int, bonus: int, uses_action: bool, target_id = null) -> void:''')

cp='godot/scripts/charged_pair_rules.gd'
rep(cp,'\tvar result := _stored(gs, owner, src, card, instance, target_id)','\tgs.VerifiedRules.Zhenjian.consume_card(gs,owner,src,card)\n\tvar result := _stored(gs, owner, src, card, instance, target_id)')
rep(cp,'\tc.chargedReleased = true; c.chargedSelected = false; c.playedInstance = clean(record.instance)','\tc.chargedReleased = true; c.chargedSelected = false; c.playedInstance = clean(record.instance)\n\tc=gs.VerifiedRules.Zhenjian.prepare_release(gs,owner,src,c,record)')
rep(cp,'static func marks(_gs, _owner: int, u: Dictionary) -> Array:', 'static func marks(gs, _owner: int, u: Dictionary) -> Array:')
rep(cp,'result.append("蓄力 · " + str(record.card.get("name", "")) + " · 下个己方回合使用")','result.append("蓄力 · " + str(record.card.get("name", "")) + (" · 可主动释放" if not gs.VerifiedRules.Zhenjian.auto_release(u) else " · 下个己方回合使用"))')
rep('godot/scripts/lantern_rules.gd','and int(u.lanternStored.turn)<gs.turn_counter:stored.append(idx)','and int(u.lanternStored.turn)<gs.turn_counter and gs.VerifiedRules.Zhenjian.auto_release(u):stored.append(idx)')
rep('godot/scripts/panguan_rules.gd','\tif int(target.hp) <= 0: return false\n\tgs._knockout_unit(target, owner, src, extra)','\tif int(target.hp) <= 0 or gs.VerifiedRules.Zhenjian.prevent_destroy(target): return false\n\tgs._knockout_unit(target, owner, src, extra)')
rep('godot/scripts/combat_keyword_rules.gd','\tgs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,idx,result,options)','\tgs.VerifiedRules.Zhenjian.combat_dealt(gs,owner,src,victim,idx,result,options)\n\tgs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,idx,result,options)')

ai='godot/scripts/game_ai.gd'
rep(ai,'\tgs.VerifiedRules.ChargedPair.ai_prepare(gs,p_idx)','\tgs.VerifiedRules.ChargedPair.ai_prepare(gs,p_idx)\n\tgs.VerifiedRules.Zhenjian.ai_prepare(gs,p_idx)')
rep(ai,'\tvar charged_score=_gs.VerifiedRules.ChargedPair.score_card(_gs,p_idx,card,_target)','\tvar zd_score=_gs.VerifiedRules.Zhenjian.score_card(_gs,p_idx,card,_target)\n\tif zd_score!=null:return int(zd_score)\n\tvar charged_score=_gs.VerifiedRules.ChargedPair.score_card(_gs,p_idx,card,_target)')
rep(ai,'\tvar charged_choice=gs.VerifiedRules.ChargedPair.ai_choice(gs,p_idx)','\tvar zd_choice=gs.VerifiedRules.Zhenjian.ai_choice(gs,p_idx)\n\tif zd_choice!=null:return bool(zd_choice)\n\tvar charged_choice=gs.VerifiedRules.ChargedPair.ai_choice(gs,p_idx)')
rep(ai,'\tvar play := _best_card(gs, p_idx)\n\tif play.ok and','\tfor idx in gs.player(p_idx).units.size():\n\t\tif gs.VerifiedRules.Zhenjian.can_manual_release(gs,p_idx,idx) and gs.release_charge(p_idx,idx):return true\n\tvar play := _best_card(gs, p_idx)\n\tif play.ok and')
rep(ai,'\t\tvar play := _best_card(gs, p_idx)\n\t\tif play.ok:', '''		var released := false
		for idx in gs.player(p_idx).units.size():
			if gs.VerifiedRules.Zhenjian.can_manual_release(gs,p_idx,idx) and gs.release_charge(p_idx,idx):
				actions.append({"cmd":"release_charge", "unit":idx}); released=true; break
		if released: continue
		var play := _best_card(gs, p_idx)
		if play.ok:''')

ui='godot/scripts/ui/battle_screen.gd'
rep(ui,'\t\tvar charged_choice_card=gs.VerifiedRules.ChargedPair.choice_card(gs,PLAYER,str(iid))','\t\tvar zd_choice_card=gs.VerifiedRules.Zhenjian.choice_card(gs,PLAYER,str(iid))\n\t\tif zd_choice_card!=null:def=zd_choice_card\n\t\tvar charged_choice_card=gs.VerifiedRules.ChargedPair.choice_card(gs,PLAYER,str(iid))')
rep(ui,'\tif _has_any_action():\n\t\t_prompt("打出发光手牌，或拖动式神到交战区出击", ThemeBuilder.PAPER)', '''	for idx in gs.player(PLAYER).units.size():
		if gs.VerifiedRules.Zhenjian.can_manual_release(gs,PLAYER,idx):
			_small_button("释放蓄力 · " + str(gs.player(PLAYER).units[idx].name), _on_release_charge.bind(idx), true)
	if _has_any_action():
		_prompt("打出发光手牌，或拖动式神到交战区出击", ThemeBuilder.PAPER)''')
rep(ui,'func _has_any_action() -> bool:\n\tif gs == null or gs.current_player != PLAYER: return false','func _has_any_action() -> bool:\n\tif gs == null or gs.current_player != PLAYER: return false\n\tfor idx in gs.player(PLAYER).units.size():\n\t\tif gs.VerifiedRules.Zhenjian.can_manual_release(gs,PLAYER,idx):return true')
rep(ui,'func _on_core_clicked(owner: int = AI) -> void:', '''func _on_release_charge(unit_index: int) -> void:
	if gs == null or _input_locked(): return
	_hide_tooltip()
	_cancel_target_selection()
	_selected_attacker=-1
	if gs.release_charge(PLAYER,unit_index):
		_refresh()
		_check_auto_ai()


func _on_core_clicked(owner: int = AI) -> void:''')
status='godot/scripts/ui/battle_status.gd'
rep(status,'\tview.chargedMarks=gs.VerifiedRules.ChargedPair.marks(gs,owner,view)','\tview.zdMarks=gs.VerifiedRules.Zhenjian.marks(gs,owner,view)\n\tview.chargedMarks=gs.VerifiedRules.ChargedPair.marks(gs,owner,view)')
rep(status,'\tfor detail in unit.get("chargedMarks",[]):','\tfor detail in unit.get("zdMarks",[]):result.append(mark("zhenjian-rule",str(detail),str(detail),"d6b273"))\n\tfor detail in unit.get("chargedMarks",[]):')

for p,s in changes.items(): p.write_text(s)
print('ZHENJIAN_RUNTIME_INTEGRATED', len(changes))
