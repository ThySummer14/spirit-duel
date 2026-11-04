"""Prepared only. The parent integrates shared files in its own ordered pass."""
from pathlib import Path
root=Path(__file__).resolve().parents[2]
changes={}
def add(path, anchor, replacement, count=1):
 p=root/path
 s=changes.get(path,p.read_text())
 done=s.count(replacement)
 if done==count:return
 if done:raise RuntimeError(f'{path}: partial integration ({done}/{count})')
 if s.count(anchor)!=count:raise RuntimeError(f'{path}: anchor count {s.count(anchor)}, expected {count}: {anchor!r}')
 changes[path]=s.replace(anchor,replacement)
add('godot/scripts/verified_card_rules.gd','const MonkCleaner := preload("res://scripts/monk_cleaner_rules.gd")','const MonkCleaner := preload("res://scripts/monk_cleaner_rules.gd")\nconst RabbitTide := preload("res://scripts/rabbit_tide_rules.gd")')
add('godot/scripts/verified_card_rules.gd','static func event(gs, kind: String, details: Dictionary) -> void:','static func event(gs, kind: String, details: Dictionary) -> void:\n\tRabbitTide.rule_event(gs,kind,details)')
add('godot/scripts/verified_card_rules.gd','static func card_announced(gs, p_idx: int, src: int, card: Dictionary) -> void:','static func card_announced(gs, p_idx: int, src: int, card: Dictionary) -> void:\n\tRabbitTide.card_announced(gs,p_idx,src,card)')
add('godot/scripts/verified_card_rules.gd','static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:','static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n\tif RabbitTide.resolve_action(gs,p_idx,src,card,effect,target,target_id): return true')
add('godot/scripts/game_state.gd','\tif VerifiedRules.MonkCleaner.resolve_frame(self, frame): return','\tif VerifiedRules.RabbitTide.resolve_frame(self,frame): return\n\tif VerifiedRules.MonkCleaner.resolve_frame(self, frame): return')
add('godot/scripts/game_state.gd','\tcard = VerifiedRules.MonkCleaner.describe_card(self, p_idx, inst, card)','\tcard = VerifiedRules.MonkCleaner.describe_card(self, p_idx, inst, card)\n\tcard = VerifiedRules.RabbitTide.describe_card(self,p_idx,card,inst)')
add('godot/scripts/game_state.gd','\tvar t: String = card.get("target", "auto")\n\tvar own := player(p_idx)','\tvar rt_targets=VerifiedRules.RabbitTide.targets(self,p_idx,card)\n\tif rt_targets!=null:return rt_targets\n\tvar t: String = card.get("target", "auto")\n\tvar own := player(p_idx)')
add('godot/scripts/game_state.gd','\tif VerifiedRules.RednightWalnut.before_hit(self,frame,idx):return','\tif VerifiedRules.RabbitTide.before_combat(self,frame):return\n\tif VerifiedRules.RednightWalnut.before_hit(self,frame,idx):return')
add('godot/scripts/game_state.gd','\tVerifiedRules.TreeSakura.turn_start(self, p_idx)','\tVerifiedRules.TreeSakura.turn_start(self, p_idx)\n\tVerifiedRules.RabbitTide.begin_turn(self,p_idx)')
add('godot/scripts/game_state.gd','\tif u.get("dollSummon",false): VerifiedRules.Doll.summoned_knockout(self,victim,u)','\tif u.get("dollSummon",false): VerifiedRules.Doll.summoned_knockout(self,victim,u)\n\tif u.get("rtSpear",false): VerifiedRules.RabbitTide.summoned_knockout(self,victim,u)')
add('godot/scripts/game_state.gd','\t\tVerifiedRules.Whale.remove_departed(self)','\t\tVerifiedRules.Whale.remove_departed(self)\n\t\tVerifiedRules.RabbitTide.remove_departed(self)',count=2)
add('godot/scripts/game_state.gd','\tVerifiedRules.OwlInsect.refresh(self)\n\tVerifiedRules.TreeSakura.sync_power(u)','\tVerifiedRules.OwlInsect.refresh(self)\n\tVerifiedRules.RabbitTide.refresh(self)\n\tVerifiedRules.TreeSakura.sync_power(u)')
add('godot/scripts/weaver_rules.gd','\t\tif old.get("arkFish",false):','\t\tif old.get("rtSpear",false): gs.VerifiedRules.RabbitTide.remove_spear(gs,owner,old,"战斗区被替换")\n\t\tif old.get("arkFish",false):')
add('godot/scripts/combat_keyword_rules.gd','\tif keyword=="veil" and unit.get("chargedVeil",false):return true','\tif keyword=="veil" and unit.get("chargedVeil",false):return true\n\tif keyword=="veil" and unit.get("rtSpearVeil",false) and int(unit.get("hp",0))>0:return true')
add('godot/scripts/light_healer_rules.gd','"fortune-result", {"player": owner, "roll": result','"fortune-result", {"player": owner, "sourceIndex": source, "roll": result')
# can_play_card: add `if not VerifiedRules.RabbitTide.can_use(self,p_idx,card): ...`
# using the surrounding branch's established failure reason convention.
# game_ai._score_card: consult RabbitTide.score_card before the generic scorer.
# battle_status.unit_view: append RabbitTide.marks(gs,owner,unit) to native marks.

# Validate every anchor first, then write each staged shared file exactly once.
for path,value in changes.items():(root/path).write_text(value)
print('RABBIT_TIDE_RUNTIME_INTEGRATED files=%d'%len(changes))
