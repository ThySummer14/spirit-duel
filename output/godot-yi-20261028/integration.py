from pathlib import Path

root = Path(__file__).resolve().parents[2]

def edit(name, old, new):
    path = root / name
    text = path.read_text()
    assert text.count(old) == 1, (name, old[:120], text.count(old))
    path.write_text(text.replace(old, new, 1))

edit('godot/scripts/verified_card_rules.gd', 'const Link := preload("res://scripts/link_rules.gd")', 'const Link := preload("res://scripts/link_rules.gd")\nconst Yi := preload("res://scripts/yi_rules.gd")')
edit('godot/scripts/verified_card_rules.gd', '\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true', '\tif Yi.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
edit('godot/scripts/game_state.gd', '\t\tarr[j] = tmp\n\n\nfunc _log', '\t\tarr[j] = tmp\n\tVerifiedRules.Yi.shuffled(self,arr)\n\n\nfunc _log')
edit('godot/scripts/game_state.gd', 'func _draw(p_idx: int, count: int) -> void:\n', 'func _draw(p_idx: int, count: int) -> void:\n\tif VerifiedRules.Yi.defer_draw(self,p_idx,count):return\n')
edit('godot/scripts/game_state.gd', '\twhile resolution_stack.size() > depth and pending_choice.is_empty() and response_window.is_empty() and winner < 0:\n\t\tvar frame:', '\twhile resolution_stack.size() > depth and pending_choice.is_empty() and response_window.is_empty() and winner < 0:\n\t\tVerifiedRules.Yi.promote(self)\n\t\tvar frame:')
edit('godot/scripts/game_state.gd', '\twhile not resolution_stack.is_empty() and winner < 0:\n\t\tvar frame:', '\twhile not resolution_stack.is_empty() and winner < 0:\n\t\tVerifiedRules.Yi.promote(self)\n\t\tvar frame:')
edit('godot/scripts/game_state.gd', 'func _resolve_frame(frame: Dictionary) -> void:\n', 'func _resolve_frame(frame: Dictionary) -> void:\n\tif VerifiedRules.Yi.resolve_frame(self,frame):return\n')
edit('godot/scripts/game_state.gd', 'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n', 'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type") in ["yi-long-think","yi-search"]:return VerifiedRules.Yi.resolve_choice(self,p_idx,instance_id)\n')
edit('godot/scripts/game_state.gd', '\tcard = VerifiedRules.BlackWhite.describe_card(self,p_idx,inst,card)', '\tcard = VerifiedRules.Yi.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.BlackWhite.describe_card(self,p_idx,inst,card)')
edit('godot/scripts/game_state.gd', '\tvar black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)', '\tvar yi_targets=VerifiedRules.Yi.targets(self,p_idx,card)\n\tif yi_targets!=null:return yi_targets\n\tvar black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)')
edit('godot/scripts/game_state.gd', '\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):', '\tif not VerifiedRules.Yi.can_use(self,p_idx,card):return {"ok":false,"reason":"弈已觉醒或没有可选择的真实卡牌。"}\n\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):')
edit('godot/scripts/game_state.gd', '\tcard=VerifiedRules.Focus.automatic(self,p_idx,card,automatic)', '\tcard=VerifiedRules.Focus.automatic(self,p_idx,card,automatic)\n\tcard=VerifiedRules.Yi.prepare_instance(self,p_idx,card,automatic)')
edit('godot/scripts/game_state.gd', '\tVerifiedRules.Puppet.form_installed(self,p_idx,src,card)', '\tVerifiedRules.Puppet.form_installed(self,p_idx,src,card)\n\tVerifiedRules.Yi.form_installed(self,p_idx,src,card)')
edit('godot/scripts/game_state.gd', '\t\t"returnInstance": realm.get("returnInstance", {}).duplicate(true),', '\t\t"returnInstance": realm.get("returnInstance", {}).duplicate(true),\n\t\t"cardInstance": card.get("playedInstance",{}).duplicate(true),')
edit('godot/scripts/game_state.gd', '\tVerifiedRules.BlackWhite.turn_start(self,p_idx)', '\tVerifiedRules.Yi.turn_start(self,p_idx)\n\tVerifiedRules.BlackWhite.turn_start(self,p_idx)')
edit('godot/scripts/bamboo_rules.gd', '\t\trealm.cardId=card.id', '\t\trealm.cardId=card.id\n\t\trealm.cardInstance=card.get("playedInstance",{}).duplicate(true)')
edit('godot/scripts/form_countdown_rules.gd', 'static func remove(gs, owner: int, src: int, reason: String) -> void:', 'static func remove(gs, owner: int, src: int, reason: String, returning_to_deck: bool = false) -> void:')
edit('godot/scripts/form_countdown_rules.gd', '\tgs.VerifiedRules.Garuda.form_removed(gs,owner,src)\n\tgs.VerifiedRules.Puppet.form_removed(gs,owner,src)\n\tgs.VerifiedRules.OniAsura.form_removed(gs,owner,src)', '\tif not returning_to_deck:gs.VerifiedRules.Garuda.form_removed(gs,owner,src)\n\tgs.VerifiedRules.Puppet.form_removed(gs,owner,src,returning_to_deck)\n\tif not returning_to_deck:gs.VerifiedRules.OniAsura.form_removed(gs,owner,src)')
edit('godot/scripts/form_countdown_rules.gd', '\tif not old.is_empty() and ContentLoader.unit_def(unit.id).get("formLifecycle", {}).get("destroyed", false):', '\tif not returning_to_deck and not old.is_empty() and ContentLoader.unit_def(unit.id).get("formLifecycle", {}).get("destroyed", false):')
edit('godot/scripts/puppet_rules.gd', 'static func form_removed(gs, owner: int, src: int) -> void:', 'static func form_removed(gs, owner: int, src: int, returning_to_deck: bool = false) -> void:')
edit('godot/scripts/puppet_rules.gd', '\tif str(entry.get("definitionId",""))!=AWAKEN_FORM or entry.get("puppetComponents",[]).size()>1:', '\tif not returning_to_deck and (str(entry.get("definitionId",""))!=AWAKEN_FORM or entry.get("puppetComponents",[]).size()>1):')
edit('godot/scripts/mask_rules.gd', '\t\t\tif can_top_use(gs, owner, src, "trick"): use_top(gs, owner, src)', '\t\t\tif gs.VerifiedRules.Yi.has_waiting(gs):gs.resolution_stack.append({"kind":"yi-mask-top","playerIndex":owner,"sourceIndex":src})\n\t\t\telif can_top_use(gs, owner, src, "trick"): use_top(gs, owner, src)')
edit('godot/scripts/game_ai.gd', '\tvar futakuchi_score=_gs.VerifiedRules.Futakuchi.score_card(_gs,p_idx,card)', '\tvar yi_score=_gs.VerifiedRules.Yi.score_card(_gs,p_idx,card,_target)\n\tif yi_score!=null:return int(yi_score)\n\tvar futakuchi_score=_gs.VerifiedRules.Futakuchi.score_card(_gs,p_idx,card)')
edit('godot/scripts/game_ai.gd', 'static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n', 'static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n\tvar yi_choice=gs.VerifiedRules.Yi.ai_choice(gs,p_idx)\n\tif yi_choice!=null:return bool(yi_choice)\n')
edit('godot/scripts/ui/battle_screen.gd', '\t\tvar box_choice_card=gs.VerifiedRules.BoxMaiden.choice_card(gs,PLAYER,str(iid))', '\t\tvar yi_choice_card=gs.VerifiedRules.Yi.choice_card(gs,PLAYER,str(iid))\n\t\tif yi_choice_card!=null:def=yi_choice_card\n\t\tvar box_choice_card=gs.VerifiedRules.BoxMaiden.choice_card(gs,PLAYER,str(iid))')
edit('scripts/godot-verify.sh', 'verify_two_faces verify_link_cross', 'verify_two_faces verify_yi verify_link_cross')
print('YI_INTEGRATED')
