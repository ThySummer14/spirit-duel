from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
edits = []
changed = {}

def edit(path, old, new, count=1):
    edits.append((path, None, old, new, count))

def function(path, name, old, new, count=1):
    edits.append((path, name, old, new, count))

gs = 'godot/scripts/game_state.gd'
verified = 'godot/scripts/verified_card_rules.gd'
edit(verified, 'const MirrorSong := preload("res://scripts/mirror_song_rules.gd")', 'const MirrorSong := preload("res://scripts/mirror_song_rules.gd")\nconst RedPurple := preload("res://scripts/red_purple_rules.gd")')
edit(verified, '\tif MirrorSong.resolve_action(gs,p_idx,src,card,effect,target_id):return true', '\tif RedPurple.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif MirrorSong.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
function(verified, 'announce_card', '\tYujiazhu.announced(gs,frame,announced)', '\tRedPurple.announced(gs,frame,announced)\n\tYujiazhu.announced(gs,frame,announced)')
function(verified, 'end_turn', '\tYujiazhu.end_turn(gs)', '\tRedPurple.end_turn(gs,p_idx)\n\tYujiazhu.end_turn(gs)')
function(verified, 'knocked_out', '\tToxic.knocked_out(unit)', '\tRedPurple.knocked_out(unit)\n\tToxic.knocked_out(unit)')
function(gs, 'describe_card_instance', '\tcard = VerifiedRules.Mianqiling.describe_card(self,p_idx,card)', '\tcard = VerifiedRules.RedPurple.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.Mianqiling.describe_card(self,p_idx,card)')
function(gs, 'valid_targets', '\tvar ms_targets=VerifiedRules.MirrorSong.targets(self,p_idx,card)', '\tvar rp_targets=VerifiedRules.RedPurple.targets(self,p_idx,card)\n\tif rp_targets!=null:return rp_targets\n\tvar ms_targets=VerifiedRules.MirrorSong.targets(self,p_idx,card)')
function(gs, 'resolve_divination_choice', '\tif pending_choice.get("type")=="ms-beauty":', '\tif pending_choice.get("type") in ["rp-fox-mode","rp-fox-target"]:return VerifiedRules.RedPurple.resolve_choice(self,p_idx,instance_id)\n\tif pending_choice.get("type")=="ms-beauty":')
function(gs, '_recalc', '\tunit.attack += VerifiedRules.Glutton.power(self,unit)', '\tunit.attack += VerifiedRules.Glutton.power(self,unit)\n\tunit.attack += VerifiedRules.RedPurple.aura_bonus(self,unit,"attack") + VerifiedRules.RedPurple.power_bonus(self,unit)')
function(gs, '_recalc', '\tnew_max += VerifiedRules.Crocodile.bonus(self,unit,"hp")', '\tnew_max += VerifiedRules.Crocodile.bonus(self,unit,"hp")\n\tnew_max += VerifiedRules.RedPurple.aura_bonus(self,unit,"hp")')
function(gs, '_grow_unit', '\t_recalc(unit)', '\t_recalc(unit)\n\tVerifiedRules.RedPurple.refresh(self)')
function(gs, '_knockout_unit', '\t_recalc(u)', '\t_recalc(u)\n\tVerifiedRules.RedPurple.refresh(self)')
function(gs, '_install_form', '\tVerifiedRules.Mianqiling.form_entered(self,p_idx,src,card)', '\tVerifiedRules.RedPurple.form_entered(self,p_idx,src,card)\n\tVerifiedRules.Mianqiling.form_entered(self,p_idx,src,card)')
function(gs, '_deploy_realm', '\tVerifiedRules.HandBlessing.realm_entered(self,p_idx,card)', '\tVerifiedRules.HandBlessing.realm_entered(self,p_idx,card)\n\tVerifiedRules.RedPurple.realm_entered(self,p_idx,card)')
function(gs, '_trigger_realms', '\t\tif VerifiedRules.Sparrow.trigger_realm(self,p_idx,realm): continue', '\t\tif VerifiedRules.RedPurple.trigger_realm(self,p_idx,realm): continue\n\t\tif VerifiedRules.Sparrow.trigger_realm(self,p_idx,realm): continue')
function(gs, '_resolve_combat_hit', '\t\tVerifiedRules.Mianqiling.snapshot_exchange(self,owner,src,victim,idx,options,d_options)', '\t\tVerifiedRules.RedPurple.snapshot_exchange(self,owner,src,victim,idx,options,d_options)\n\t\tVerifiedRules.Mianqiling.snapshot_exchange(self,owner,src,victim,idx,options,d_options)')
function('godot/scripts/movement_rules.gd', 'revived', ' gs.VerifiedRules.Lantern.revived(gs,owner,idx)', ' gs.VerifiedRules.RedPurple.refresh(gs)\n gs.VerifiedRules.Lantern.revived(gs,owner,idx)')
function('godot/scripts/mianqiling_rules.gd', 'set_faction', '\treturn true', '\tgs.VerifiedRules.RedPurple.refresh(gs)\n\treturn true')
function('godot/scripts/owl_insect_rules.gd', 'refresh', 'static func refresh(gs) -> void:\n', 'static func refresh(gs) -> void:\n\tgs.VerifiedRules.RedPurple.refresh(gs)\n')
function('godot/scripts/tomato_fire_rules.gd', 'attack_encourage', 'options.get("basicAttack", false) or ', 'options.get("basicAttack", false) or options.get("rpNightRaid", false) or ')
function('godot/scripts/combat_keyword_rules.gd', 'has', 'static func has(unit: Dictionary, keyword: String) -> bool:\n', 'static func has(unit: Dictionary, keyword: String) -> bool:\n\tif keyword=="pursuit" and preload("res://scripts/red_purple_rules.gd").has_pursuit(unit):return true\n')
function('godot/scripts/combat_keyword_rules.gd', 'strike', '\tgs.VerifiedRules.TwoFaces.combat_dealt(gs,owner,src,victim,idx,result,options)', '\tgs.VerifiedRules.RedPurple.combat_dealt(gs,owner,src,victim,idx,result,options)\n\tgs.VerifiedRules.TwoFaces.combat_dealt(gs,owner,src,victim,idx,result,options)')
function('godot/scripts/combat_keyword_rules.gd', 'strike', '\t\tgs.VerifiedRules.TwoFaces.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)', '\t\tgs.VerifiedRules.RedPurple.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)\n\t\tgs.VerifiedRules.TwoFaces.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)')
function('godot/scripts/sun_smoke_rules.gd', 'has_charge', 'return bool(def.get("nativeCharge", false))', 'return bool(unit.get("formRules",{}).get("rpCopiedCharge",false)) or bool(def.get("nativeCharge", false))')
for path, count, anchor in [
    ('godot/scripts/sun_smoke_rules.gd', 2, '"mianRedGrowth"'),
    ('godot/scripts/sparrow_rules.gd', 1, '"mianRedGrowth"'),
]:
    edit(path, anchor, anchor+', "rpGrowthAttack", "rpGrowthHp", "rpRenxiaAttack"', count)
edit('godot/scripts/game_ai.gd', '\tvar ms_choice=gs.VerifiedRules.MirrorSong.ai_choice(gs,p_idx)', '\tvar rp_choice=gs.VerifiedRules.RedPurple.ai_choice(gs,p_idx)\n\tif rp_choice!=null:return bool(rp_choice)\n\tvar ms_choice=gs.VerifiedRules.MirrorSong.ai_choice(gs,p_idx)')
edit('godot/scripts/game_ai.gd', '\tvar ms_score=_gs.VerifiedRules.MirrorSong.score_card(_gs,p_idx,card,_target)', '\tvar rp_score=_gs.VerifiedRules.RedPurple.score_card(_gs,p_idx,card,_target)\n\tif rp_score!=null:return int(rp_score)\n\tvar ms_score=_gs.VerifiedRules.MirrorSong.score_card(_gs,p_idx,card,_target)')
edit('godot/scripts/ui/battle_screen.gd', '\t\tvar ms_choice_card=gs.VerifiedRules.MirrorSong.choice_card(gs,PLAYER,str(iid))', '\t\tvar rp_choice_card=gs.VerifiedRules.RedPurple.choice_card(gs,PLAYER,str(iid))\n\t\tif rp_choice_card!=null:def=rp_choice_card\n\t\tvar ms_choice_card=gs.VerifiedRules.MirrorSong.choice_card(gs,PLAYER,str(iid))')
edit('godot/scripts/ui/battle_status.gd', '\tview.msMarks=gs.VerifiedRules.MirrorSong.marks(gs,owner,view)', '\tview.rpMarks=gs.VerifiedRules.RedPurple.marks(gs,owner,idx)\n\tview.msMarks=gs.VerifiedRules.MirrorSong.marks(gs,owner,view)')
edit('godot/scripts/ui/battle_status.gd', '\tfor detail in unit.get("msMarks",[]):result.append', '\tfor detail in unit.get("rpMarks",[]):result.append(mark("red-purple",str(detail),str(detail),"c1a5bc"))\n\tfor detail in unit.get("msMarks",[]):result.append')
edit('scripts/godot-verify.sh', 'verify_mirror_song ', 'verify_red_purple verify_mirror_song ')

for path, name, old, new, count in edits:
    text = changed.get(path, (root/path).read_text())
    if name:
        match = re.search(r'(?m)^(?:static )?func '+re.escape(name)+r'\(', text)
        assert match, (path, name)
        end = re.search(r'(?m)^(?:static )?func ', text[match.end():])
        stop = match.end()+end.start() if end else len(text)
        block = text[match.start():stop]
        assert block.count(old) == count, (path, name, old, block.count(old))
        text = text[:match.start()]+block.replace(old,new)+text[stop:]
    else:
        assert text.count(old) == count, (path, old, text.count(old))
        text = text.replace(old,new)
    changed[path] = text

if '--check' not in sys.argv:
    for path, text in changed.items():
        (root/path).write_text(text)
print('RED_PURPLE_SHARED_HOOKS',len(edits),'edits',len(changed),'files')
