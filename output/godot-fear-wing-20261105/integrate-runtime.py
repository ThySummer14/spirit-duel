from pathlib import Path
root=Path(__file__).resolve().parents[2];changes={}
def add(path,anchor,new,count=1):
 p=root/path;s=changes.get(p,p.read_text())
 if s.count(new)==count:return
 assert s.count(anchor)==count,(path,anchor[:110],s.count(anchor),count)
 changes[p]=s.replace(anchor,new)
p='godot/scripts/verified_card_rules.gd'
add(p,'const HairPower := preload("res://scripts/hair_power_rules.gd")','const HairPower := preload("res://scripts/hair_power_rules.gd")\nconst FearWing := preload("res://scripts/fear_wing_rules.gd")')
add(p,'static func event(gs, kind: String, details: Dictionary) -> void:','static func event(gs, kind: String, details: Dictionary) -> void:\n\tFearWing.rule_event(gs,kind,details)')
add(p,'\tif HairPower.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif FearWing.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif HairPower.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
add(p,'\t\tif not MusicFire.can_use(gs,owner,card):continue','\t\tif not FearWing.can_use(gs,owner,card):continue\n\t\tif not MusicFire.can_use(gs,owner,card):continue')
p='godot/scripts/game_state.gd'
add(p,'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif str(pending_choice.get("type","")).begins_with("fw-"):return VerifiedRules.FearWing.resolve_choice(self,p_idx,instance_id)')
add(p,'\tcard = VerifiedRules.HairPower.describe(self,p_idx,card)','\tcard = VerifiedRules.HairPower.describe(self,p_idx,card)\n\tcard = VerifiedRules.FearWing.describe_card(self,p_idx,inst,card)')
add(p,'\tvar mf_targets=VerifiedRules.MusicFire.targets(self,p_idx,card)','\tvar fw_targets=VerifiedRules.FearWing.targets(self,p_idx,card)\n\tif fw_targets!=null:return fw_targets\n\tvar mf_targets=VerifiedRules.MusicFire.targets(self,p_idx,card)')
add(p,'\tif not VerifiedRules.HairPower.can_use(self,p_idx,card):','\tif not VerifiedRules.FearWing.can_use(self,p_idx,card):return {"ok":false,"reason":"天逆每已经觉醒。"}\n\tif not VerifiedRules.HairPower.can_use(self,p_idx,card):')
add(p,'\tif VerifiedRules.HairPower.resolve_frame(self,frame):return','\tif VerifiedRules.FearWing.resolve_frame(self,frame):return\n\tif VerifiedRules.HairPower.resolve_frame(self,frame):return')
add(p,'\tVerifiedRules.HairPower.form_entered(self,p_idx,src,card)','\tVerifiedRules.FearWing.form_entered(self,p_idx,src,card)\n\tVerifiedRules.HairPower.form_entered(self,p_idx,src,card)')
add(p,'\tvar hair_saved:=VerifiedRules.HairPower.knockout_snapshot(victim,u)','\tvar fear_saved:=VerifiedRules.FearWing.knockout_snapshot(self,victim,u)\n\tvar hair_saved:=VerifiedRules.HairPower.knockout_snapshot(victim,u)')
add(p,'\t\tVerifiedRules.HairPower.after_knockout(self,hair_saved)','\t\tVerifiedRules.FearWing.after_knockout(self,fear_saved)\n\t\tVerifiedRules.HairPower.after_knockout(self,hair_saved)',count=2)
add(p,'\tVerifiedRules.knocked_out(u)','\tVerifiedRules.FearWing.after_knockout(self,fear_saved)\n\tVerifiedRules.knocked_out(u)')
add(p,'\tif VerifiedRules.MusicFire.before_attack(self,frame):return','\tif VerifiedRules.MusicFire.before_attack(self,frame):return\n\tif VerifiedRules.FearWing.before_attack(self,frame):return')
add(p,'\tVerifiedRules.HairPower.finished(self,owner,src,defender,options,kills)','\tVerifiedRules.FearWing.combat_finished(self,owner,src,options,kills)\n\tVerifiedRules.HairPower.finished(self,owner,src,defender,options,kills)')
add(p,'\tVerifiedRules.HairPower.begin_turn(self,p_idx)','\tVerifiedRules.HairPower.begin_turn(self,p_idx)\n\tVerifiedRules.FearWing.begin_turn(self,p_idx)')
add(p,'\tif VerifiedRules.HairPower.trigger_realm(self,p_idx,realm):return','\tif VerifiedRules.FearWing.trigger_realm(self,p_idx,realm):return\n\tif VerifiedRules.HairPower.trigger_realm(self,p_idx,realm):return')
p='godot/scripts/sun_smoke_rules.gd'
add(p,'\tgs.VerifiedRules.MusicFire.reset_ledger(target)','\tgs.VerifiedRules.FearWing.reset_character(gs,target)\n\tgs.VerifiedRules.MusicFire.reset_ledger(target)')
p='godot/scripts/game_ai.gd'
add(p,'\tvar hair_score=_gs.VerifiedRules.HairPower.score_card(_gs,p_idx,card,_target)','\tvar fw_score=_gs.VerifiedRules.FearWing.score_card(_gs,p_idx,card,_target)\n\tif fw_score!=null:return int(fw_score)\n\tvar hair_score=_gs.VerifiedRules.HairPower.score_card(_gs,p_idx,card,_target)')
add(p,'\tif gs.pending_choice.get("type")=="moon-hand-top":','\tvar fw_choice=gs.VerifiedRules.FearWing.ai_choice(gs,p_idx)\n\tif fw_choice!=null:return bool(fw_choice)\n\tif gs.pending_choice.get("type")=="moon-hand-top":')
p='godot/scripts/ui/battle_status.gd'
add(p,'\tview.mfMarks=gs.VerifiedRules.MusicFire.marks(gs,owner,view)','\tview.fearWingMarks=gs.VerifiedRules.FearWing.marks(view)\n\tview.mfMarks=gs.VerifiedRules.MusicFire.marks(gs,owner,view)')
add(p,'\tfor detail in unit.get("mfMarks",[]):','\tfor detail in unit.get("fearWingMarks",[]):result.append(mark("fear-wing",str(detail),str(detail),"ae74bb"))\n\tfor detail in unit.get("mfMarks",[]):')
p='godot/scripts/ui/battle_screen.gd'
add(p,'\t\tvar ape_choice_card=gs.VerifiedRules.ApeSleeve.choice_card(gs,PLAYER,str(iid))','\t\tvar fw_choice_card=gs.VerifiedRules.FearWing.choice_card(gs,PLAYER,str(iid))\n\t\tif fw_choice_card!=null:def=fw_choice_card\n\t\tvar ape_choice_card=gs.VerifiedRules.ApeSleeve.choice_card(gs,PLAYER,str(iid))')
for p,s in changes.items():p.write_text(s)
print('FEAR_WING_INTEGRATED',len(changes),'files')
