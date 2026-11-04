"""Prepared only; parent integrates shared files in an ordered pass."""
from pathlib import Path
root=Path(__file__).resolve().parents[2]
changes={}
def add(path,anchor,replacement,count=1):
 p=root/path;s=changes.get(path,p.read_text())
 if s.count(replacement)==count:return
 if s.count(anchor)!=count:raise RuntimeError(f'{path}: anchor count {s.count(anchor)}, expected {count}: {anchor!r}')
 changes[path]=s.replace(anchor,replacement)
add('godot/scripts/verified_card_rules.gd','const MonkCleaner := preload("res://scripts/monk_cleaner_rules.gd")','const MonkCleaner := preload("res://scripts/monk_cleaner_rules.gd")\nconst SugarCat := preload("res://scripts/sugar_cat_rules.gd")')
add('godot/scripts/verified_card_rules.gd','static func event(gs, kind: String, details: Dictionary) -> void:','static func event(gs, kind: String, details: Dictionary) -> void:\n\tSugarCat.rule_event(gs,kind,details)')
add('godot/scripts/verified_card_rules.gd','\tCrab.announced(gs, frame, announced)','\tCrab.announced(gs, frame, announced)\n\tSugarCat.announced(gs,frame,announced)')
add('godot/scripts/verified_card_rules.gd','static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:','static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n\tif SugarCat.resolve_action(gs,p_idx,src,card,effect,target_id):return true')
add('godot/scripts/game_state.gd','\tif VerifiedRules.MonkCleaner.resolve_frame(self, frame): return','\tif VerifiedRules.SugarCat.resolve_frame(self,frame):return\n\tif VerifiedRules.MonkCleaner.resolve_frame(self, frame): return')
add('godot/scripts/game_state.gd','\tcard = VerifiedRules.MonkCleaner.describe_card(self, p_idx, inst, card)','\tcard = VerifiedRules.MonkCleaner.describe_card(self, p_idx, inst, card)\n\tcard = VerifiedRules.SugarCat.describe_card(self,p_idx,inst,card)')
add('godot/scripts/game_state.gd','\tvar t: String = card.get("target", "auto")\n\tvar own := player(p_idx)','\tvar sc_targets=VerifiedRules.SugarCat.targets(self,p_idx,card)\n\tif sc_targets!=null:return sc_targets\n\tvar t: String = card.get("target", "auto")\n\tvar own := player(p_idx)')
add('godot/scripts/game_state.gd','\tVerifiedRules.TreeSakura.turn_start(self, p_idx)','\tVerifiedRules.TreeSakura.turn_start(self, p_idx)\n\tVerifiedRules.SugarCat.begin_turn(self,p_idx)')
add('godot/scripts/game_state.gd','\t\tVerifiedRules.Whale.remove_departed(self)','\t\tVerifiedRules.Whale.remove_departed(self)\n\t\tVerifiedRules.SugarCat.remove_departed(self)',count=2)
add('godot/scripts/game_state.gd','\tif u.get("dollSummon",false): VerifiedRules.Doll.summoned_knockout(self,victim,u)','\tif u.get("dollSummon",false): VerifiedRules.Doll.summoned_knockout(self,victim,u)\n\tif u.get("scSummon",false): VerifiedRules.SugarCat.summoned_knockout(self,victim,u)')
add('godot/scripts/game_state.gd','\t\tVerifiedRules.Headless.completed(self,frame,card)','\t\tVerifiedRules.Headless.completed(self,frame,card)\n\t\tVerifiedRules.SugarCat.completed(self,frame,card)')
add('godot/scripts/game_state.gd','\tVerifiedRules.Forms.attach(self, p_idx, src, card)','\tVerifiedRules.Forms.attach(self, p_idx, src, card)\n\tVerifiedRules.SugarCat.form_entered(self,p_idx,src,card)')
add('godot/scripts/game_state.gd','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type","") in ["sc-ingredient","sc-cat"]:return VerifiedRules.SugarCat.resolve_choice(self,p_idx,instance_id)')
add('godot/scripts/weaver_rules.gd','\t\tif old.get("arkFish",false):','\t\tif old.get("scSummon",false): gs.VerifiedRules.SugarCat.remove_summon(gs,owner,old,"战斗区被替换")\n\t\tif old.get("arkFish",false):')
add('godot/scripts/weaver_rules.gd','\tleave_front(gs,owner,idx)\n\tif u.get("pineSummon",false):','\tif u.get("scCandy",false):\n\t\tvar candy_fused: int=gs.VerifiedRules.SugarCat.fuse_revived(gs,owner,idx)\n\t\tif candy_fused>=0:return candy_fused\n\tgs.VerifiedRules.SugarCat.revived(gs,owner,idx)\n\tleave_front(gs,owner,idx)\n\tif u.get("pineSummon",false):')
add('godot/scripts/movement_rules.gd',' if unit.get("summoned", false):',' if unit.get("summoned", false):\n  if unit.get("scSummon",false):\n   gs.VerifiedRules.SugarCat.remove_summon(gs,owner,unit)\n   return true')
# Parent also integrates can_use, AI score/choice, choice_card UI and battle_status
# using adjacent feature-module call conventions (see integration.md).
for path,value in changes.items():(root/path).write_text(value)
print('SUGAR_CAT_RUNTIME_INTEGRATED files=%d'%len(changes))
