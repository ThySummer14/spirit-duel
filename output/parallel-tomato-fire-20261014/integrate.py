"""Transactional anchor validation, explicit isolated/project Godot root only.
python3 integrate.py <godot-root> [--check]
All anchors, JSON definitions and module paths validate before any write.
"""
import json,sys,shutil
from pathlib import Path
root=Path(sys.argv[1]).resolve();source=Path(__file__).resolve().parents[2]
contents={}
def edit(rel,old,new,count=1):
 s=contents.get(rel,(root/rel).read_text());n=s.count(old)
 if n!=count: raise SystemExit(f'{rel}: expected {count}, got {n}: {old[:100]!r}')
 contents[rel]=s.replace(old,new,count)
def after(rel,old,new):edit(rel,old,old+new)
def before(rel,old,new):edit(rel,old,new+old)
f='scripts/verified_card_rules.gd'
after(f,'const Poison := preload("res://scripts/poison_rules.gd")','\nconst TomatoFire := preload("res://scripts/tomato_fire_rules.gd")')
after(f,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n','\tif TomatoFire.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n')
after(f,'static func end_turn(gs, p_idx: int) -> void:\n','\tTomatoFire.end_turn(gs)\n')
f='scripts/movement_rules.gd'
after(f,' if unit.get("summoned", false):\n','  if unit.get("tomatoFireSummon", false):\n   gs.VerifiedRules.TomatoFire.remove_summon(gs, owner, unit)\n   return true\n')
before(f,'  gs.VerifiedRules.Xuenv.clear_wall(gs, owner)\n','  gs.VerifiedRules.TomatoFire.clear_summons(gs, owner)\n')
f='scripts/game_state.gd'
after(f,'func _apply_encourage(p_idx: int, attack: int, shield: int) -> void:\n','\tvar increased := VerifiedRules.TomatoFire.amplify(self, p_idx, attack, shield)\n\tattack = int(increased.attack)\n\tshield = int(increased.shield)\n')
start=(root/f).read_text();old=start[start.index('func _prepare_encourage('):start.index('\n\nfunc _pay_charge_cost')]
edit(f,old,'func _prepare_encourage(p_idx: int) -> Dictionary:\n\treturn VerifiedRules.TomatoFire.prepare_encourage(self, p_idx)')
edit(f,'"cost": 0 if uses_instant else int(card.get("cost", 0)),','"cost": (0 if uses_instant else int(card.get("cost", 0))) + VerifiedRules.TomatoFire.extra_cost(self, p_idx, card),')
edit(f,'int(p.energy) < (0 if u.get("swift", false) or VerifiedRules.Yaodao.permanent_swift(u) or VerifiedRules.Bailang.swift(u) else 1)','int(p.energy) < VerifiedRules.TomatoFire.basic_cost(self, p_idx, u)')
edit(f,'int(p.energy) - (0 if p.units[unit_index].get("swift", false) or VerifiedRules.Yaodao.permanent_swift(p.units[unit_index]) or VerifiedRules.Bailang.swift(p.units[unit_index]) else 1)','int(p.energy) - VerifiedRules.TomatoFire.basic_cost(self, p_idx, p.units[unit_index])')
after(f,'\t\tVerifiedRules.Xuenv.remove_departed_walls(self)\n','\t\tVerifiedRules.TomatoFire.remove_departed(self)\n')
after(f,'func _resolve_frame(frame: Dictionary) -> void:\n','\tif VerifiedRules.TomatoFire.resolve_frame(self, frame): return\n')
before(f,'\tremote = remote or VerifiedRules.Combat.has(attacker, "remote")\n','\tvar enc := VerifiedRules.TomatoFire.attack_encourage(self, p_idx, options)\n\toptions = VerifiedRules.TomatoFire.merge_traits(options, enc)\n\tremote = remote or options.get("remote", false)\n\tpierce = pierce or options.get("pierce", false)\n\tcombo = combo or options.get("combo", false)\n\tif options.get("basicAttack", false): VerifiedRules.TomatoFire.begin_attack(self, p_idx, unit_index, options)\n')
before(f,'\t\tVerifiedRules.Xuenv.clear_wall(self, p_idx)\n','\t\tif not attacker.get("tomatoFireSummon", false): VerifiedRules.TomatoFire.clear_summons(self, p_idx)\n')
edit(f,'"encourage": _prepare_encourage(p_idx) if options.get("basicAttack", false) else {}','"encourage": enc')
after(f,'\tif int(attacker.hp) <= 0 or winner >= 0:\n','\t\tVerifiedRules.TomatoFire.finish_attack(self, p_idx, unit_index)\n')
before(f,'\tvar fi: int = front_index(e_idx)\n\tif options.get("directAvatar", false): fi = -1','\tif VerifiedRules.TomatoFire.burn_attack(self, frame, power, options): return\n')
after(f,'\tVerifiedRules.Xuenv.after_attack(self, owner, src)\n','\tVerifiedRules.TomatoFire.finish_attack(self, owner, src)\n')
after(f,'\tVerifiedRules.BookJue.avatar_damaged(self, _src_player, source_index, p_idx, amount)\n','\tVerifiedRules.TomatoFire.avatar_damaged(self, _src_player, source_index, p_idx, amount)\n')
before(f,'\tVerifiedRules.Bailang.turn_start(self, p_idx)\n','\tVerifiedRules.TomatoFire.turn_start(self, p_idx)\n')
edit(f,'\treturn out\n\n\nfunc card_matches_response_window','\treturn VerifiedRules.TomatoFire.targets(self, p_idx, out)\n\n\nfunc card_matches_response_window')
f='scripts/combat_keyword_rules.gd'
edit(f,'unit.get("untilAttack", {}).get("keywords", [])]','unit.get("untilAttack", {}).get("keywords", []), unit.get("swanKeywords", {}).keys()]')
after(f,'\tgs.VerifiedRules.Poison.combat_dealt(gs, owner, src, victim, idx, result)\n','\tgs.VerifiedRules.TomatoFire.combat_dealt(gs, owner, src, victim, idx, result, options)\n')
f='scripts/armor_break_rules.gd'
# Movement already installed this shared generalized lifesteal option.
if 'result.lifeSteal = options.get("lifeSteal", false)' not in (root/f).read_text():
 edit(f,'result.lifeSteal = marked and options.get("lifeStealAgainstArmorBreak", false)','result.lifeSteal = options.get("lifeSteal", false) or (marked and options.get("lifeStealAgainstArmorBreak", false))')
f='scripts/game_ai.gd'
after(f,'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','\tvar tomato_fire_score = _gs.VerifiedRules.TomatoFire.score_card(_gs, p_idx, card, _target)\n\tif tomato_fire_score != null: return int(tomato_fire_score)\n')
f='scripts/ui/battle_status.gd'
after(f,'\tview.poisonRetained = gs.VerifiedRules.Poison.preserves(gs, owner, idx)\n','\tview = gs.VerifiedRules.TomatoFire.unit_view(gs, owner, idx, view)\n')
after(f,'\tif active:\n','\t\tif definition.get("tomatoFireRole") == "sister" and not unit.get("awakened", false): result.append(mark("extra-fire", "出击／战斗牌额外1鬼火", "费用已计入合法性与实际支付；气绝复活牌也需要额外1鬼火。", "e06040"))\n\t\tif unit.has("tomatoSplash"): result.append(mark("tomato-splash", "番茄 · 永久力量+%d · 出击叠加%d" % [int(unit.get("tomatoPower", 0)), int(unit.tomatoSplash)], "每次攻击造成伤害，向另一个随机敌方角色造成3伤；每层分别结算。", "e06040"))\n\t\tif unit.get("burnEntity", false): result.append(mark("burn-replacement", "烬染不夜 · 随机两段", "攻击改为两个随机敌方角色各受等同力量的伤害；仍消耗出击次数，可接受鼓舞。", "f08850"))\n')
overlay=json.loads(Path(__file__).with_name('overlay.json').read_text());verified=json.loads((root/'content/verified_rules.json').read_text())
ids={s['id'] for s in verified['sources']}
verified['sources'].extend(s for s in overlay['sources'] if s['id'] not in ids)
for key in ['units','cards']:
 for id,patch in overlay[key].items(): verified[key].setdefault(id,{}).update(patch)
names=['tomato_fire_rules.gd','verify_tomato_fire.gd','verify_tomato_fire_ui.gd']
for name in names:
 if not (source/'godot/scripts'/name).exists():raise SystemExit('missing module: '+name)
if '--check' in sys.argv: print('TOMATO_FIRE_ANCHORS_OK',root);raise SystemExit(0)
for rel,body in contents.items():(root/rel).write_text(body)
(root/'content/verified_rules.json').write_text(json.dumps(verified,ensure_ascii=False,indent=2)+'\n')
for name in names:
 src=source/'godot/scripts'/name;dst=root/'scripts'/name
 if src.resolve()!=dst.resolve():shutil.copy2(src,dst)
print('TOMATO_FIRE_INTEGRATION_OK',root)
