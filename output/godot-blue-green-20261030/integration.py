from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
edits = []
def edit(path, old, new, expected=1):
    edits.append((path, old, new, expected))

vr = 'godot/scripts/verified_card_rules.gd'
gs = 'godot/scripts/game_state.gd'
combat = 'godot/scripts/combat_keyword_rules.gd'
edit(vr, 'const Factions := preload("res://scripts/faction_rules.gd")', 'const Factions := preload("res://scripts/faction_rules.gd")\nconst BlueGreen := preload("res://scripts/blue_green_rules.gd")')
edit(vr, '\tSunSmoke.rule_event(gs, kind, details)', '\tBlueGreen.rule_event(gs, kind, details)\n\tSunSmoke.rule_event(gs, kind, details)')
edit(vr, '\tYujiazhu.announced(gs,frame,announced)', '\tBlueGreen.announced(gs,frame,announced)\n\tYujiazhu.announced(gs,frame,announced)')
edit(vr, '\tif Yujiazhu.resolve_action(gs,p_idx,src,card,effect,target_id):return true', '\tif BlueGreen.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Yujiazhu.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
edit(vr, '\tYujiazhu.end_turn(gs)', '\tBlueGreen.end_turn(gs,p_idx)\n\tYujiazhu.end_turn(gs)')
edit(vr, '\tMianqiling.knocked_out(unit)', '\tBlueGreen.knocked_out(unit)\n\tMianqiling.knocked_out(unit)')
edit(gs, '\tcard = VerifiedRules.Mianqiling.describe_card(self,p_idx,card)', '\tcard = VerifiedRules.BlueGreen.describe_card(self,p_idx,inst,card)\n\tcard = VerifiedRules.Mianqiling.describe_card(self,p_idx,card)')
edit(gs, '\tvar mian_targets=VerifiedRules.Mianqiling.targets(self,p_idx,card)', '\tvar bg_targets=VerifiedRules.BlueGreen.targets(self,p_idx,card)\n\tif bg_targets!=null:return bg_targets\n\tvar mian_targets=VerifiedRules.Mianqiling.targets(self,p_idx,card)')
edit(gs, 'func _resolve_frame(frame: Dictionary) -> void:\n', 'func _resolve_frame(frame: Dictionary) -> void:\n\tif VerifiedRules.BlueGreen.resolve_frame(self,frame):return\n')
edit(gs, '\t\tVerifiedRules.HandBlessing.completed(self,p_idx,src,card)', '\t\tVerifiedRules.BlueGreen.completed(self,frame,card)\n\t\tVerifiedRules.HandBlessing.completed(self,p_idx,src,card)')
edit(gs, '\tVerifiedRules.Mianqiling.form_entered(self,p_idx,src,card)', '\tVerifiedRules.BlueGreen.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Mianqiling.form_entered(self,p_idx,src,card)')
edit(gs, '\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)', '\tunit.attack += VerifiedRules.BlueGreen.aura_bonus(self,unit,"attack")\n\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)')
edit(gs, '\tvar gain := new_max - int(unit.maxHp)', '\tnew_max += VerifiedRules.BlueGreen.aura_bonus(self,unit,"hp")\n\tvar gain := new_max - int(unit.maxHp)')
edit(gs, '\t\tVerifiedRules.MonkCleaner.refresh(self)', '\t\tVerifiedRules.MonkCleaner.refresh(self)\n\t\tVerifiedRules.BlueGreen.refresh(self)', 2)
edit(gs, '\tVerifiedRules.SunSmoke.begin_turn_charge(self, p_idx)', '\tVerifiedRules.BlueGreen.refresh(self)\n\tVerifiedRules.SunSmoke.begin_turn_charge(self, p_idx)')
edit(gs, 'func _advance_turn(p_idx: int) -> void:\n', 'func _advance_turn(p_idx: int) -> void:\n\tVerifiedRules.BlueGreen.expire(self)\n')
edit(gs, 'if VerifiedRules.Glutton.has(player(p_idx).units[unit_index],"direct"):', 'if VerifiedRules.Combat.has(player(p_idx).units[unit_index],"direct"):')
edit(gs, 'if VerifiedRules.Glutton.has(attacker,"direct"):', 'if VerifiedRules.Combat.has(attacker,"direct"):')
edit(gs, '\t\tVerifiedRules.Mianqiling.snapshot_exchange(self,owner,src,victim,idx,options,d_options)', '\t\toptions.bgSnowStun=VerifiedRules.BlueGreen.snow_stun(self,owner,src)\n\t\td_options.bgSnowStun=VerifiedRules.BlueGreen.snow_stun(self,victim,idx)\n\t\tVerifiedRules.Mianqiling.snapshot_exchange(self,owner,src,victim,idx,options,d_options)')
edit(gs, '\tif not shell_modified: amount+=VerifiedRules.Maple.damage_bonus(self,_src_player,source_index,combat)\n\tif not shell_modified:\n\t\tvar special = VerifiedRules.MonkCleaner.special_damage(self, p_idx, -1', '\tif not shell_modified: amount+=VerifiedRules.Maple.damage_bonus(self,_src_player,source_index,combat)\n\tamount+=VerifiedRules.BlueGreen.avatar_bonus(self,_src_player,source_index)\n\tif not shell_modified:\n\t\tvar special = VerifiedRules.MonkCleaner.special_damage(self, p_idx, -1')
edit('godot/scripts/sun_smoke_rules.gd', 'return bool(def.get("nativeCharge", false)) or role(unit)', 'return bool(def.get("nativeCharge", false)) or bool(unit.get("formRules",{}).get("nativeCharge",false)) or role(unit)')
edit(combat, 'static func has(unit: Dictionary, keyword: String) -> bool:\n', 'static func has(unit: Dictionary, keyword: String) -> bool:\n\tif preload("res://scripts/blue_green_rules.gd").has_trait(unit,keyword):return true\n')
edit(combat, '\timmune=immune or (idx>=0 and gs.VerifiedRules.BlackWhite.combat_immune', '\timmune=immune or (idx>=0 and gs.VerifiedRules.BlueGreen.combat_immune(gs,victim,idx))\n\timmune=immune or (idx>=0 and gs.VerifiedRules.BlackWhite.combat_immune')
edit(combat, '\tgs.VerifiedRules.Tide.combat_dealt(gs, owner, src, result, tide_traits)', '\tgs.VerifiedRules.Tide.combat_dealt(gs, owner, src, result, tide_traits)\n\tgs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,idx,result,options)')
edit(combat, '\t\tvar dealt: int = gs._damage_avatar(victim, overflow, owner, src, false, true)', '\t\tvar dealt: int = gs._damage_avatar(victim, overflow, owner, src, false, true)\n\t\tgs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)')
edit('godot/scripts/game_ai.gd', '\tvar mian_score=_gs.VerifiedRules.Mianqiling.score_card(_gs,p_idx,card,_target)', '\tvar bg_score=_gs.VerifiedRules.BlueGreen.score_card(_gs,p_idx,card,_target)\n\tif bg_score!=null:return int(bg_score)\n\tvar mian_score=_gs.VerifiedRules.Mianqiling.score_card(_gs,p_idx,card,_target)')
edit('godot/scripts/ui/battle_status.gd', '\tview.mianMarks=gs.VerifiedRules.Mianqiling.marks(gs,owner,view)', '\tview.blueGreenMarks=gs.VerifiedRules.BlueGreen.marks(gs,owner,idx)\n\tview.mianMarks=gs.VerifiedRules.Mianqiling.marks(gs,owner,view)')
edit('godot/scripts/ui/battle_status.gd', '\tfor detail in unit.get("mianMarks",[]):', '\tfor detail in unit.get("blueGreenMarks",[]):result.append(mark("blue-green-rule",str(detail),str(detail),"8eb9d1"))\n\tfor detail in unit.get("mianMarks",[]):')
edit('godot/scripts/sun_smoke_rules.gd', '"mianRedGrowth",', '"mianRedGrowth", "bgGreenTemporary",', 2)
edit('godot/scripts/sparrow_rules.gd', '"mianRedGrowth",', '"mianRedGrowth","bgGreenTemporary",')

changed = {}
for path, before, after, expected in edits:
    text = changed.get(path, (root / path).read_text())
    assert text.count(before) == expected, (path, before, text.count(before), expected)
    changed[path] = text.replace(before, after)
if '--check' not in sys.argv:
    for path, text in changed.items(): (root / path).write_text(text)
print('BLUE_GREEN_INTEGRATION_PREFLIGHT' if '--check' in sys.argv else 'BLUE_GREEN_INTEGRATED', len(edits), 'edits', len(changed), 'files')
