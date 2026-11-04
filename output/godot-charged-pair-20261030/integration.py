from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
edits = []
def edit(path, old, new, count=1): edits.append((path, old, new, count))
v = 'godot/scripts/verified_card_rules.gd'
g = 'godot/scripts/game_state.gd'
edit(v, 'const MirrorSong := preload("res://scripts/mirror_song_rules.gd")', 'const MirrorSong := preload("res://scripts/mirror_song_rules.gd")\nconst ChargedPair := preload("res://scripts/charged_pair_rules.gd")')
edit(v, '\tif MirrorSong.resolve_action(gs,p_idx,src,card,effect,target_id):return true', '\tif ChargedPair.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif MirrorSong.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
edit(v, '\tYujiazhu.knocked_out(unit)', '\tChargedPair.knocked_out(unit)\n\tYujiazhu.knocked_out(unit)')
edit(g, 'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n', 'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type")=="charged-mode":return VerifiedRules.ChargedPair.resolve_choice(self,p_idx,instance_id)\n')
edit(g, '\tcard = VerifiedRules.Yi.describe_card(self,p_idx,inst,card)', '\tcard = VerifiedRules.ChargedPair.describe(self,p_idx,inst,card)\n\tcard = VerifiedRules.Yi.describe_card(self,p_idx,inst,card)')
edit(g, '\tvar ms_targets=VerifiedRules.MirrorSong.targets(self,p_idx,card)', '\tvar charged_targets=VerifiedRules.ChargedPair.targets(self,p_idx,card)\n\tif charged_targets!=null:return charged_targets\n\tvar ms_targets=VerifiedRules.MirrorSong.targets(self,p_idx,card)')
edit(g, '\tif not VerifiedRules.MirrorSong.can_use(self,p_idx,card):', '\tif not VerifiedRules.ChargedPair.can_use(self,p_idx,card):return {"ok":false,"reason":"该式神已有蓄力，或当前不能蓄力。"}\n\tif not VerifiedRules.MirrorSong.can_use(self,p_idx,card):')
edit(g, '\tif card.get("chargeOnly",false):return VerifiedRules.Lantern.store_card(self,p_idx,hand_index,card,payment)', '\tif card.get("chargedSelected",false):return VerifiedRules.ChargedPair.store_hand(self,p_idx,hand_index,card,payment,target_id)\n\tif card.get("chargeOnly",false):return VerifiedRules.Lantern.store_card(self,p_idx,hand_index,card,payment)')
edit(g, '\tif VerifiedRules.MirrorSong.resolve_frame(self,frame):return', '\tif VerifiedRules.ChargedPair.resolve_frame(self,frame):return\n\tif VerifiedRules.MirrorSong.resolve_frame(self,frame):return')
edit(g, '\t\tVerifiedRules.Headless.completed(self,frame,card)', '\t\tVerifiedRules.ChargedPair.completed(self,frame,card)\n\t\tVerifiedRules.Headless.completed(self,frame,card)')
edit(g, '\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="ms-beauty":', '\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="charged-combat":\n\t\tVerifiedRules.ChargedPair.respond_combat(self,int(frame.combatResponseId),p_idx,src,card);return\n\tif int(frame.get("combatResponseId",-1))>=0 and effects[idx].get("action")=="ms-beauty":')
edit(g, '\tVerifiedRules.MirrorSong.form_entered(self,p_idx,src,card)', '\tVerifiedRules.MirrorSong.form_entered(self,p_idx,src,card)\n\tVerifiedRules.ChargedPair.form_entered(self,p_idx,src,card)')
edit(g, '\tvar lantern_saved:=VerifiedRules.Lantern.death_frames(self,victim,u)', '\tvar charged_saved:=VerifiedRules.ChargedPair.death_frames(self,victim,u)\n\tvar lantern_saved:=VerifiedRules.Lantern.death_frames(self,victim,u)')
edit(g, '\tresolution_stack.append_array(lantern_saved)', '\tresolution_stack.append_array(lantern_saved)\n\tresolution_stack.append_array(charged_saved)')
edit(g, '\tVerifiedRules.SeaButterfly.before_responses(self,frame)', '\tif VerifiedRules.ChargedPair.defend_started(self,frame):return\n\tVerifiedRules.SeaButterfly.before_responses(self,frame)')
edit('godot/scripts/lantern_rules.gd', '\tif not kind.begins_with("lantern-"):return false', '\tif not kind.begins_with("lantern-"):return false\n\tif kind=="lantern-charged-cast" and gs.player(int(f.playerIndex)).units[int(f.sourceIndex)].get("lanternStored",{}).get("chargedPair",false):\n\t\tgs.VerifiedRules.ChargedPair.release(gs,int(f.playerIndex),int(f.sourceIndex));return true')
edit('godot/scripts/combat_keyword_rules.gd', 'static func has(unit: Dictionary, keyword: String) -> bool:\n', 'static func has(unit: Dictionary, keyword: String) -> bool:\n\tif keyword=="veil" and unit.get("randomTargetPreview",false):return false\n\tif keyword=="veil" and unit.get("chargedVeil",false):return true\n')
edit('godot/scripts/movement_rules.gd', 'static func has_veil(unit: Dictionary) -> bool:\n', 'static func has_veil(unit: Dictionary) -> bool:\n if unit.get("randomTargetPreview",false):return false\n')
edit('godot/scripts/pipe_fox_rules.gd', 'static func avatar_veil(gs, owner: int) -> bool:\n', 'static func avatar_veil(gs, owner: int) -> bool:\n\tif gs.player(owner).get("randomTargetPreview",false):return false\n')
edit('godot/scripts/owl_insect_rules.gd', 'static func refresh(gs) -> void:\n', 'static func refresh(gs) -> void:\n\tgs.VerifiedRules.ChargedPair.refresh(gs)\n')
edit('godot/scripts/game_ai.gd', '\tgs.VerifiedRules.Whale.ai_prepare(gs,p_idx)', '\tgs.VerifiedRules.ChargedPair.ai_prepare(gs,p_idx)\n\tgs.VerifiedRules.Whale.ai_prepare(gs,p_idx)')
edit('godot/scripts/game_ai.gd', '\tvar ms_score=_gs.VerifiedRules.MirrorSong.score_card(_gs,p_idx,card,_target)', '\tvar charged_score=_gs.VerifiedRules.ChargedPair.score_card(_gs,p_idx,card,_target)\n\tif charged_score!=null:return int(charged_score)\n\tvar ms_score=_gs.VerifiedRules.MirrorSong.score_card(_gs,p_idx,card,_target)')
edit('godot/scripts/game_ai.gd', '\tvar ms_choice=gs.VerifiedRules.MirrorSong.ai_choice(gs,p_idx)', '\tvar charged_choice=gs.VerifiedRules.ChargedPair.ai_choice(gs,p_idx)\n\tif charged_choice!=null:return bool(charged_choice)\n\tvar ms_choice=gs.VerifiedRules.MirrorSong.ai_choice(gs,p_idx)')
edit('godot/scripts/ui/battle_screen.gd', '\tif not choice_made and gs.VerifiedRules.Movement.request_burst(gs, PLAYER, index):', '\tif not choice_made and gs.VerifiedRules.ChargedPair.request_mode(gs,PLAYER,index):\n\t\t_hide_tooltip();_refresh();return\n\tif not choice_made and gs.VerifiedRules.Movement.request_burst(gs, PLAYER, index):')
edit('godot/scripts/ui/battle_screen.gd', '\t\tvar ms_choice_card=gs.VerifiedRules.MirrorSong.choice_card(gs,PLAYER,str(iid))', '\t\tvar charged_choice_card=gs.VerifiedRules.ChargedPair.choice_card(gs,PLAYER,str(iid))\n\t\tif charged_choice_card!=null:def=charged_choice_card\n\t\tvar ms_choice_card=gs.VerifiedRules.MirrorSong.choice_card(gs,PLAYER,str(iid))')
edit('godot/scripts/ui/battle_screen.gd', '\t\t\t\tif ready<0:ready=gs.VerifiedRules.Movement.ready_hand(gs, PLAYER)', '\t\t\t\tif ready<0:ready=gs.VerifiedRules.ChargedPair.ready_hand(gs,PLAYER)\n\t\t\t\tif ready<0:ready=gs.VerifiedRules.Movement.ready_hand(gs, PLAYER)')
edit('godot/scripts/ui/battle_status.gd', '\tview.msMarks=gs.VerifiedRules.MirrorSong.marks(gs,owner,view)', '\tview.chargedMarks=gs.VerifiedRules.ChargedPair.marks(gs,owner,view)\n\tview.msMarks=gs.VerifiedRules.MirrorSong.marks(gs,owner,view)')
edit('godot/scripts/ui/battle_status.gd', '\tfor detail in unit.get("msMarks",[]):result.append', '\tfor detail in unit.get("chargedMarks",[]):result.append(mark("charged-card",str(detail),str(detail),"97b997"))\n\tfor detail in unit.get("msMarks",[]):result.append')
edit('godot/scripts/yi_rules.gd', '"twoFacesFromDeck"]', '"twoFacesFromDeck", "chargedMode", "chargedReleased", "chargedSelected"]')
for path, needle, count in [('godot/scripts/sun_smoke_rules.gd', '"mianRedGrowth"', 2), ('godot/scripts/sparrow_rules.gd', '"mianRedGrowth"', 1)]:
 edit(path, needle, needle + ',"chargedGrowth","chargedBambooGrowth"', count)
edit('godot/scripts/sparrow_rules.gd', '"chargedBambooGrowth"', '"chargedBambooGrowth","lanternStored","chargedVeil"')
edit('scripts/godot-verify.sh', 'verify_mirror_song verify_yi', 'verify_mirror_song verify_charged_pair verify_yi')
changed = {}
for path, old, new, count in edits:
 s = changed.get(path, (root/path).read_text())
 assert s.count(old) == count, (path, old, s.count(old), count)
 changed[path] = s.replace(old, new)
if '--check' not in sys.argv:
 for path, s in changed.items(): (root/path).write_text(s)
print('CHARGED_PAIR_INTEGRATED', len(edits), 'edits', len(changed), 'files')
