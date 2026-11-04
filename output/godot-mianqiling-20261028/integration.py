from pathlib import Path
root=Path(__file__).resolve().parents[2]
edits=[]
def edit(path,a,b): edits.append((path,a,b))
edit('godot/scripts/verified_card_rules.gd','const Futakuchi := preload("res://scripts/futakuchi_rules.gd")','const Factions := preload("res://scripts/faction_rules.gd")\nconst Mianqiling := preload("res://scripts/mianqiling_rules.gd")\nconst Futakuchi := preload("res://scripts/futakuchi_rules.gd")')
edit('godot/scripts/verified_card_rules.gd','\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif Mianqiling.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Futakuchi.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
edit('godot/scripts/verified_card_rules.gd','\tFutakuchi.knocked_out(unit)','\tMianqiling.knocked_out(unit)\n\tFutakuchi.knocked_out(unit)')
edit('godot/scripts/game_state.gd','var _card_effect_context: Dictionary = {}','var _card_effect_context: Dictionary = {}\nvar _mianqiling_damage_scope: Dictionary = {}')
edit('godot/scripts/game_state.gd','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type")=="mian-faction":return VerifiedRules.Mianqiling.resolve_choice(self,p_idx,instance_id)\n')
edit('godot/scripts/game_state.gd','\tcard = VerifiedRules.Futakuchi.describe_card(self,p_idx,card)','\tcard = VerifiedRules.Mianqiling.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.Futakuchi.describe_card(self,p_idx,card)')
edit('godot/scripts/game_state.gd','\tvar black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)','\tvar mian_targets=VerifiedRules.Mianqiling.targets(self,p_idx,card)\n\tif mian_targets!=null:return mian_targets\n\tvar black_white_targets=VerifiedRules.BlackWhite.targets(self,p_idx,card)')
edit('godot/scripts/game_state.gd','\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):return {"ok":false,"reason":"二口女已经觉醒。"}','\tif not VerifiedRules.Mianqiling.can_use(self,p_idx,card):return {"ok":false,"reason":"面灵气已经觉醒。"}\n\tif not VerifiedRules.Futakuchi.can_use(self,p_idx,card):return {"ok":false,"reason":"二口女已经觉醒。"}')
edit('godot/scripts/game_state.gd','\tif VerifiedRules.BlackWhite.resolve_frame(self,frame):return','\tif VerifiedRules.Mianqiling.resolve_frame(self,frame):return\n\tif VerifiedRules.BlackWhite.resolve_frame(self,frame):return')
edit('godot/scripts/game_state.gd','\tVerifiedRules.Futakuchi.form_entered(self,p_idx,src,card)','\tVerifiedRules.Mianqiling.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Futakuchi.form_entered(self,p_idx,src,card)')
edit('godot/scripts/game_state.gd','\t\t\tVerifiedRules.KoiFragrance.form_turn_start(self,p_idx,i)','\t\t\tVerifiedRules.Mianqiling.form_turn_start(self,p_idx,i)\n\t\t\tVerifiedRules.KoiFragrance.form_turn_start(self,p_idx,i)')
edit('godot/scripts/game_state.gd','\tVerifiedRules.Susanoo.begin_duel(self,frame)','\tVerifiedRules.Mianqiling.combat_prepare(self,frame)\n\tVerifiedRules.Susanoo.begin_duel(self,frame)')
edit('godot/scripts/game_state.gd','\t\t# First strike is a timing priority, not a posthumous cancellation.','\t\tVerifiedRules.Mianqiling.snapshot_exchange(self,owner,src,victim,idx,options,d_options)\n\t\t# First strike is a timing priority, not a posthumous cancellation.')
edit('godot/scripts/game_state.gd','\tif int(u.hp) <= 0 or amount <= 0:\n\t\tVerifiedRules.TreeSakura.dead_damage','\tif int(u.hp) <= 0 or amount < 0 or (amount == 0 and not VerifiedRules.Mianqiling.positive_zero(self,p_idx,unit_index,_src_player,source_index,combat)):\n\t\tVerifiedRules.TreeSakura.dead_damage')
edit('godot/scripts/game_state.gd','\tpreview = VerifiedRules.Jorogumo.received_damage(u,preview)','\tpreview = VerifiedRules.Jorogumo.received_damage(u,preview)\n\tpreview = VerifiedRules.Mianqiling.modify_damage(self,p_idx,unit_index,preview,_src_player,source_index,combat)')
edit('godot/scripts/game_state.gd','\tunshielded = VerifiedRules.Jorogumo.received_damage(u,unshielded)','\tunshielded = VerifiedRules.Jorogumo.received_damage(u,unshielded)\n\tunshielded = VerifiedRules.Mianqiling.modify_damage(self,p_idx,unit_index,unshielded,_src_player,source_index,combat)')
edit('godot/scripts/game_state.gd','\tvar has_unyielding: bool = VerifiedRules.Glutton.has(u,"unyielding")','\tvar has_unyielding: bool = VerifiedRules.Mianqiling.unyielding(u) or VerifiedRules.Glutton.has(u,"unyielding")')
edit('godot/scripts/game_state.gd','\tif unyielding_save:\n\t\tu.owlUnyielding = false','\tif unyielding_save:\n\t\tVerifiedRules.Mianqiling.consume_unyielding(u)\n\t\tu.owlUnyielding = false')
edit('godot/scripts/game_state.gd','\tVerifiedRules.Glutton.consume_attack_traits(p.units[unit_index])','\tVerifiedRules.Mianqiling.consume_swift(p.units[unit_index])\n\tVerifiedRules.Glutton.consume_attack_traits(p.units[unit_index])')
edit('godot/scripts/combat_keyword_rules.gd','static func has(unit: Dictionary, keyword: String) -> bool:\n','static func has(unit: Dictionary, keyword: String) -> bool:\n\tif preload("res://scripts/mianqiling_rules.gd").has_trait(unit,keyword):return true\n')
edit('godot/scripts/combat_keyword_rules.gd','\tvar susanoo_scope: Dictionary=gs.VerifiedRules.Susanoo.begin_strike(gs,owner,src,options)','\tvar mian_scope: Dictionary=gs.VerifiedRules.Mianqiling.begin_strike(gs,owner,src,victim,idx,options)\n\tvar susanoo_scope: Dictionary=gs.VerifiedRules.Susanoo.begin_strike(gs,owner,src,options)')
old='\t\toverflow = maxi(0, gs.VerifiedRules.OwlInsect.reduced(target,gs.VerifiedRules.Jorogumo.received_damage(target,maxi(0, amount + int(target.armorBreak) - int(target.shield)) * (2 if critical else 1))) - int(target.hp))'
new='\t\tvar unit_damage: int = gs.VerifiedRules.Jorogumo.received_damage(target,maxi(0, amount + int(target.armorBreak) - int(target.shield)) * (2 if critical else 1))\n\t\tunit_damage = gs.VerifiedRules.Mianqiling.modify_damage(gs,victim,idx,unit_damage,owner,src,true)\n\t\toverflow = maxi(0,gs.VerifiedRules.OwlInsect.reduced(target,gs.VerifiedRules.MonkCleaner.reduced(target,unit_damage))-int(target.hp))'
edit('godot/scripts/combat_keyword_rules.gd',old,new)
edit('godot/scripts/combat_keyword_rules.gd','if pierce and idx >= 0 and amount > 0 and not gs.player(victim).units[idx].get("bloodTransfer", false)','if pierce and idx >= 0 and (amount > 0 or gs.VerifiedRules.Mianqiling.positive_zero(gs,victim,idx,owner,src,true)) and not gs.player(victim).units[idx].get("bloodTransfer", false)')
edit('godot/scripts/combat_keyword_rules.gd','\tgs.VerifiedRules.Susanoo.end_strike(gs,owner,src,susanoo_scope)\n\treturn result','\tgs.VerifiedRules.Susanoo.end_strike(gs,owner,src,susanoo_scope)\n\tgs.VerifiedRules.Mianqiling.end_strike(gs,mian_scope)\n\treturn result')
edit('godot/scripts/tomato_fire_rules.gd','var cost := 0 if gs.VerifiedRules.Glutton.has(u,"swift")','var cost := 0 if gs.VerifiedRules.Mianqiling.swift(u) or gs.VerifiedRules.Glutton.has(u,"swift")')
edit('godot/scripts/ui/battle_status.gd','\tview.twoFacesMarks=gs.VerifiedRules.TwoFaces.marks(gs,owner,idx)','\tview.mianMarks=gs.VerifiedRules.Mianqiling.marks(gs,owner,view)\n\tif gs.VerifiedRules.Mianqiling.swift(view):view.swift=true\n\tif gs.VerifiedRules.Mianqiling.unyielding(view):view.unyielding=true\n\tview.twoFacesMarks=gs.VerifiedRules.TwoFaces.marks(gs,owner,idx)')
edit('godot/scripts/ui/battle_status.gd','\tfor detail in unit.get("twoFacesMarks",[]):result.append','\tfor detail in unit.get("mianMarks",[]):result.append(mark("faction-rule",str(detail),str(detail),"8eb9d1"))\n\tfor detail in unit.get("twoFacesMarks",[]):result.append')
edit('godot/scripts/ui/battle_screen.gd','\t\tvar box_choice_card=gs.VerifiedRules.BoxMaiden.choice_card(gs,PLAYER,str(iid))','\t\tvar mian_choice_card=gs.VerifiedRules.Mianqiling.choice_card(gs,PLAYER,str(iid))\n\t\tif mian_choice_card!=null:def=mian_choice_card\n\t\tvar box_choice_card=gs.VerifiedRules.BoxMaiden.choice_card(gs,PLAYER,str(iid))')
edit('godot/scripts/game_ai.gd','\tvar black_white_score=_gs.VerifiedRules.BlackWhite.score_card(_gs,p_idx,card,_target)','\tvar mian_score=_gs.VerifiedRules.Mianqiling.score_card(_gs,p_idx,card,_target)\n\tif mian_score!=null:return int(mian_score)\n\tvar black_white_score=_gs.VerifiedRules.BlackWhite.score_card(_gs,p_idx,card,_target)')
edit('godot/scripts/game_ai.gd','\tvar link_choice=gs.VerifiedRules.Link.ai_choice(gs,p_idx)','\tvar mian_choice=gs.VerifiedRules.Mianqiling.ai_choice(gs,p_idx)\n\tif mian_choice!=null:return bool(mian_choice)\n\tvar link_choice=gs.VerifiedRules.Link.ai_choice(gs,p_idx)')
edit('godot/scripts/armor_break_rules.gd','\tif power <= 0: return empty','\tif power < 0 or (power == 0 and (idx < 0 or not gs.VerifiedRules.Mianqiling.positive_zero(gs,owner,idx,source_owner,src,true))): return empty')
# Numeric resets must remove the same rollback ledger as knockout.
for path,anchor in [('godot/scripts/sun_smoke_rules.gd','"blackWhiteGrowthAttack", "blackWhiteGrowthHp", "futakuchiFearGrowth"'),('godot/scripts/sparrow_rules.gd','"blackWhiteGrowthAttack","blackWhiteGrowthHp","futakuchiFearGrowth"')]:
    before=(root/path).read_text()
    replacement=anchor+(', "mianRedGrowth"' if ', ' in anchor else ',"mianRedGrowth"')
    # The source clone cleanup and target reset both contain this group.
    n=before.count(anchor)
    if n:
        edits.append((path,anchor,replacement))
# Preflight the complete transformation before touching any shared file.
changed={}
for path,a,b in edits:
    text=changed.get(path,(root/path).read_text())
    expected=2 if path.endswith('sun_smoke_rules.gd') and a.startswith('"blackWhiteGrowthAttack"') else 1
    assert text.count(a)==expected,(path,a,text.count(a))
    changed[path]=text.replace(a,b)
for path,text in changed.items():(root/path).write_text(text)
print('MIAN_INTEGRATION',len(edits),'edits',len(changed),'files')
