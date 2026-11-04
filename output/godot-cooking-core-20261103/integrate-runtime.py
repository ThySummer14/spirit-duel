from pathlib import Path
root=Path(__file__).resolve().parents[2];changes={}
def add(file,old,new):
 p=root/file;s=changes.get(p,p.read_text());assert s.count(old)==1,(file,old[:90],s.count(old));changes[p]=s.replace(old,new,1)
p='godot/scripts/game_state.gd'
add(p,'\tcard = VerifiedRules.Zhenjian.describe(self,p_idx,card)','\tcard = VerifiedRules.Zhenjian.describe(self,p_idx,card)\n\tcard = VerifiedRules.Cooking.describe_card(self,p_idx,inst,card)')
add(p,'\t\tVerifiedRules.Zhenjian.completed(self,frame,card)','\t\tVerifiedRules.Cooking.completed(self,frame,card)\n\t\tVerifiedRules.Zhenjian.completed(self,frame,card)')
add(p,'\tVerifiedRules.ApeSleeve.form_entered(self,p_idx,src,card)','\tVerifiedRules.Cooking.form_entered(self,p_idx,src,card)\n\tVerifiedRules.ApeSleeve.form_entered(self,p_idx,src,card)')
add(p,'\tif VerifiedRules.RednightWalnut.trigger_realm(self,p_idx,realm):return','\tif VerifiedRules.Cooking.trigger_realm(self,p_idx,realm):return\n\tif VerifiedRules.RednightWalnut.trigger_realm(self,p_idx,realm):return')
p='godot/scripts/verified_card_rules.gd'
add(p,'\tif Arakawa.resolve_action(gs,p_idx,src,card,effect,target_id):return true','\tif Cooking.resolve_action(gs,p_idx,src,card,effect,target_id):return true\n\tif Arakawa.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
add(p,'\tRednightWalnut.end_turn(gs,p_idx)','\tCooking.end_turn(gs,p_idx)\n\tRednightWalnut.end_turn(gs,p_idx)')
add(p,'\tApeSleeve.knocked_out(unit)','\tCooking.knocked_out(unit)\n\tApeSleeve.knocked_out(unit)')
add('godot/scripts/sun_smoke_rules.gd','\tgs.VerifiedRules.ApeSleeve.reset_ledger(target)','\tgs.VerifiedRules.Cooking.reset_ledger(target)\n\tgs.VerifiedRules.ApeSleeve.reset_ledger(target)')
p='godot/scripts/combat_keyword_rules.gd'
add(p,'\tgs.VerifiedRules.Zhenjian.combat_dealt(gs,owner,src,victim,idx,result,options)','\tgs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,idx,result,options)\n\tgs.VerifiedRules.Zhenjian.combat_dealt(gs,owner,src,victim,idx,result,options)')
add(p,'\t\tgs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)','\t\tgs.VerifiedRules.Cooking.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)\n\t\tgs.VerifiedRules.BlueGreen.combat_dealt(gs,owner,src,victim,-1,{"dealt":dealt},options)')
p='godot/scripts/game_ai.gd'
add(p,'\tvar ark_score=_gs.VerifiedRules.Arakawa.score_card(_gs,p_idx,card,_target)','\tvar cook_score=_gs.VerifiedRules.Cooking.score_card(_gs,p_idx,card,_target)\n\tif cook_score!=null:return int(cook_score)\n\tvar ark_score=_gs.VerifiedRules.Arakawa.score_card(_gs,p_idx,card,_target)')
p='godot/scripts/ui/battle_status.gd'
add(p,'\tview.arkMarks=gs.VerifiedRules.Arakawa.marks(gs,owner,view)','\tview.cookingMarks=gs.VerifiedRules.Cooking.marks(gs,owner,view)\n\tview.arkMarks=gs.VerifiedRules.Arakawa.marks(gs,owner,view)')
add(p,'\tfor detail in unit.get("arkMarks",[]):','\tfor detail in unit.get("cookingMarks",[]):result.append(mark("cooking",str(detail),str(detail),"d2ad7b"))\n\tfor detail in unit.get("arkMarks",[]):')
for p,s in changes.items():p.write_text(s)
print('COOKING_RUNTIME_INTEGRATED',len(changes))
