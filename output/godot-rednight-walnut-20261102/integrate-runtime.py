from pathlib import Path
root=Path(__file__).resolve().parents[2]
changes={}
def add(path,anchor,new):
 p=root/path;s=changes.get(p,p.read_text());assert s.count(anchor)==1,(path,anchor,s.count(anchor));changes[p]=s.replace(anchor,new,1)
p='godot/scripts/verified_card_rules.gd'
add(p,'const Arakawa :=','const RednightWalnut := preload("res://scripts/rednight_walnut_rules.gd")\nconst Arakawa :=')
add(p,'static func event(gs, kind: String, details: Dictionary) -> void:\n','static func event(gs, kind: String, details: Dictionary) -> void:\n\tRednightWalnut.rule_event(gs,kind,details)\n')
add(p,'\tif ApeSleeve.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif RednightWalnut.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif ApeSleeve.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
add(p,'\tApeSleeve.end_turn(gs,p_idx)','\tRednightWalnut.end_turn(gs,p_idx)\n\tApeSleeve.end_turn(gs,p_idx)')
add(p,'\tvar announced: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.definitionId)))','\tvar announced: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.definitionId)))\n\tRednightWalnut.announced(gs,frame,announced)')
p='godot/scripts/game_state.gd'
add(p,'\tif pending_choice.get("type")=="ape-mimic":','\tif pending_choice.get("type")=="rw-items":return VerifiedRules.RednightWalnut.resolve_choice(self,p_idx,instance_id)\n\tif pending_choice.get("type")=="ape-mimic":')
add(p,'\tcard = VerifiedRules.Arakawa.describe_card(self,p_idx,card)','\tcard = VerifiedRules.RednightWalnut.describe_card(self,p_idx,card)\n\tcard = VerifiedRules.Arakawa.describe_card(self,p_idx,card)')
add(p,'func valid_targets(p_idx: int, card: Dictionary) -> Array:\n','func valid_targets(p_idx: int, card: Dictionary) -> Array:\n\tvar rw_targets=VerifiedRules.RednightWalnut.targets(self,p_idx,card)\n\tif rw_targets!=null:return rw_targets\n')
add(p,'\tif not VerifiedRules.Zhenjian.can_use(self,p_idx,card):','\tif not VerifiedRules.RednightWalnut.can_use(self,p_idx,card):return {"ok":false,"reason":"式神已经觉醒。"}\n\tif not VerifiedRules.Zhenjian.can_use(self,p_idx,card):')
add(p,'\tif VerifiedRules.ApeSleeve.resolve_frame(self,frame):return','\tif VerifiedRules.RednightWalnut.resolve_frame(self,frame):return\n\tif VerifiedRules.ApeSleeve.resolve_frame(self,frame):return')
add(p,'\tVerifiedRules.ApeSleeve.form_entered(self,p_idx,src,card)','\tVerifiedRules.RednightWalnut.form_entered(self,p_idx,src,card)\n\tVerifiedRules.ApeSleeve.form_entered(self,p_idx,src,card)')
add(p,'\tVerifiedRules.ApeSleeve.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken)','\tVerifiedRules.RednightWalnut.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken,combat)\n\tVerifiedRules.ApeSleeve.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken)')
add(p,'\tvar sleeve_saved:=VerifiedRules.ApeSleeve.death_frames(self,victim,u)','\tvar rw_saved:=VerifiedRules.RednightWalnut.death_frames(self,victim,u)\n\tvar sleeve_saved:=VerifiedRules.ApeSleeve.death_frames(self,victim,u)')
add(p,'\tresolution_stack.append_array(charged_saved)','\tresolution_stack.append_array(charged_saved)\n\tresolution_stack.append_array(rw_saved)')
add(p,'\tif u.get("cannotAttack", false): return {"ok": false, "reason": "冰墙不能攻击。"}','\tif not VerifiedRules.RednightWalnut.can_deploy(u):return {"ok":false,"reason":"锁羚羊：下个己方回合不能出击。"}\n\tif u.get("cannotAttack", false): return {"ok": false, "reason": "冰墙不能攻击。"}')
add(p,'\tif VerifiedRules.StarBear.before_basic_attack(self,p_idx,unit_index,bonus,pierce,remote,combo,first_strike,target_id,crit,options): return','\tif options.get("basicAttack",false) and VerifiedRules.RednightWalnut.replace_basic(self,p_idx,unit_index,target_id):return\n\tif VerifiedRules.StarBear.before_basic_attack(self,p_idx,unit_index,bonus,pierce,remote,combo,first_strike,target_id,crit,options): return')
add(p,'\tif VerifiedRules.SilkNinja.before_response(self,frame): return','\tif VerifiedRules.RednightWalnut.before_attack(self,frame):return\n\tif VerifiedRules.SilkNinja.before_response(self,frame): return')
add(p,'\tif VerifiedRules.Zhenjian.defend_started(self,frame):return','\tif VerifiedRules.RednightWalnut.before_hit(self,frame,idx):return\n\tif VerifiedRules.Zhenjian.defend_started(self,frame):return')
add(p,'\tVerifiedRules.ApeSleeve.combat_finished(self,owner,src,options)','\tVerifiedRules.RednightWalnut.combat_finished(self,owner,src,options)\n\tVerifiedRules.ApeSleeve.combat_finished(self,owner,src,options)')
add(p,'\t\t\t\tVerifiedRules.Fortune.turn_start(self, p_idx, i)','\t\t\t\tVerifiedRules.RednightWalnut.turn_start(self,p_idx,i)\n\t\t\t\tVerifiedRules.Fortune.turn_start(self, p_idx, i)')
add(p,'\t\tif VerifiedRules.RedPurple.trigger_realm(self,p_idx,realm): continue','\t\tif VerifiedRules.RednightWalnut.trigger_realm(self,p_idx,realm):continue\n\t\tif VerifiedRules.RedPurple.trigger_realm(self,p_idx,realm): continue')
p='godot/scripts/combat_keyword_rules.gd'
add(p,'static func strike(gs, owner: int, src: int, victim: int, idx: int, amount: int, options: Dictionary, pierce: bool = false, immune: bool = false) -> Dictionary:\n','static func strike(gs, owner: int, src: int, victim: int, idx: int, amount: int, options: Dictionary, pierce: bool = false, immune: bool = false) -> Dictionary:\n\tif options.get("rwNoDamage",false):return {"damage":0,"dealt":0,"knocked":false,"overkill":0}\n')
p='godot/scripts/game_ai.gd'
add(p,'\tvar ape_score=_gs.VerifiedRules.ApeSleeve.score_card(_gs,p_idx,card,_target)','\tvar rw_score=_gs.VerifiedRules.RednightWalnut.score_card(_gs,p_idx,card,_target)\n\tif rw_score!=null:return int(rw_score)\n\tvar ape_score=_gs.VerifiedRules.ApeSleeve.score_card(_gs,p_idx,card,_target)')
add(p,'\tvar ape_choice=gs.VerifiedRules.ApeSleeve.ai_choice(gs,p_idx)','\tvar rw_choice=gs.VerifiedRules.RednightWalnut.ai_choice(gs,p_idx)\n\tif rw_choice!=null:return bool(rw_choice)\n\tvar ape_choice=gs.VerifiedRules.ApeSleeve.ai_choice(gs,p_idx)')
p='godot/scripts/ui/battle_screen.gd'
add(p,'\t\tvar ape_choice_card=gs.VerifiedRules.ApeSleeve.choice_card(gs,PLAYER,str(iid))','\t\tvar rw_choice_card=gs.VerifiedRules.RednightWalnut.choice_card(gs,PLAYER,str(iid))\n\t\tif rw_choice_card!=null:def=rw_choice_card\n\t\tvar ape_choice_card=gs.VerifiedRules.ApeSleeve.choice_card(gs,PLAYER,str(iid))')
p='godot/scripts/ui/battle_status.gd'
add(p,'\tview.apeSleeveMarks=gs.VerifiedRules.ApeSleeve.marks(gs,owner,view)','\tview.rwMarks=gs.VerifiedRules.RednightWalnut.marks(gs,owner,view)\n\tview.apeSleeveMarks=gs.VerifiedRules.ApeSleeve.marks(gs,owner,view)')
add(p,'\tfor detail in unit.get("apeSleeveMarks",[]):','\tfor detail in unit.get("rwMarks",[]):result.append(mark("rednight-walnut",str(detail),str(detail),"c998a6"))\n\tfor detail in unit.get("apeSleeveMarks",[]):')
for p,s in changes.items():p.write_text(s)
print('REDNIGHT_WALNUT_RUNTIME_INTEGRATED files=',len(changes))
