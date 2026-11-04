"""Precise integration, explicit Godot root; preserves unrelated changes.
Run once per checkout. All text anchors are validated before any write.
"""
import json,sys,shutil
from pathlib import Path
root=Path(sys.argv[1]).resolve()
source=Path(__file__).resolve().parents[2]
contents={}
def edit(rel,old,new,count=1):
 p=root/rel;s=contents.get(rel,p.read_text());n=s.count(old)
 if n!=count:raise SystemExit(f'{rel}: expected {count}, got {n}: {old[:95]!r}')
 contents[rel]=s.replace(old,new,count)
def after(rel,old,new):edit(rel,old,old+new)
def before(rel,old,new):edit(rel,old,new+old)
f='scripts/verified_card_rules.gd'
after(f,'const ArmorBreak := preload("res://scripts/armor_break_rules.gd")','\nconst Poison := preload("res://scripts/poison_rules.gd")')
after(f,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n','\tif Poison.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n')
after(f,'static func end_turn(gs, p_idx: int) -> void:\n','\tPoison.end_turn(gs, p_idx)\n')
after(f,'static func knocked_out(unit: Dictionary) -> void:\n','\tunit.erase("poisonShieldTurn")\n')
edit(f,'\t\tif card.get("dogGuard", false) and Bingyong.replacement_blocked(gs, owner, unit): continue','\t\tif (card.get("dogGuard", false) or card.get("poisonGuard", false)) and Bingyong.replacement_blocked(gs, owner, unit): continue')
f='scripts/game_state.gd'
after(f,'\tcard = VerifiedRules.Tide.describe_card(self, p_idx, card)\n','\tcard = VerifiedRules.Poison.describe_card(self, p_idx, p.hand[hand_index], card)\n')
after(f,'func _resolve_frame(frame: Dictionary) -> void:\n','\tif VerifiedRules.Poison.resolve_frame(self, frame): return\n')
after(f,'\tvar action := str(effect.get("action", ""))\n','\taction = str(card.get("responseAction", action))\n')
after(f,'\tif int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") == "assault":\n','\t\tif VerifiedRules.Poison.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return\n')
after(f,'\tfor owner in players.size():\n\t\tif player(owner).units.has(unit) and VerifiedRules.Combat.zero_power(self, owner, unit): unit.attack = 0\n','\tfor owner in players.size():\n\t\tif player(owner).units.has(unit):\n\t\t\tunit.poisonAuraReduction = VerifiedRules.Poison.power_reduction(self, owner, unit)\n\t\t\tunit.attack = int(unit.attack) - int(unit.poisonAuraReduction)\n')
after(f,'\tVerifiedRules.DogDemon.form_entered(self, p_idx, src, card)\n','\tVerifiedRules.Poison.form_entered(self, p_idx, src, card)\n')
after(f,'\tif source_index < 0 and int(_card_effect_context.get("playerIndex", -2)) == _src_player:\n\t\tsource_index = int(_card_effect_context.get("sourceIndex", -1))\n','\tif VerifiedRules.Poison.convert_damage(self, _src_player, source_index, p_idx, unit_index, amount):\n\t\t_record_spell_damage(p_idx, str(u.uid), 0, true)\n\t\treturn {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}\n')
after(f,'\tVerifiedRules.Shuten.record_damage(self, p_idx, unit_index, unshielded, _src_player)\n','\tVerifiedRules.Poison.damaged(self, p_idx, unit_index, _src_player, source_index, unshielded, combat)\n')
after(f,'\tVerifiedRules.knocked_out(u)\n','\tVerifiedRules.Poison.refresh_all(self)\n')
after(f,'func _damage_avatar(p_idx: int, amount: int, _src_player: int = -1, source_index: int = -1) -> int:\n\tvar p := player(p_idx)\n\tif amount <= 0 or winner >= 0:\n\t\treturn 0\n','\tif source_index < 0 and int(_card_effect_context.get("playerIndex", -2)) == _src_player: source_index = int(_card_effect_context.get("sourceIndex", -1))\n\tif VerifiedRules.Poison.convert_damage(self, _src_player, source_index, p_idx, -1, amount):\n\t\t_record_spell_damage(p_idx, "", 0, true)\n\t\treturn 0\n')
before(f,'\toptions = VerifiedRules.ArmorBreak.prepare_combat(self, e_idx, fi, options)\n','\tVerifiedRules.Poison.transfer_before_combat(self, p_idx, unit_index, e_idx, fi, options)\n')
after(f,'\toptions = VerifiedRules.ArmorBreak.prepare_combat(self, e_idx, fi, options)\n\tif fi < 0:\n','\t\tif VerifiedRules.Poison.avatar_response(self, frame, power, options): return\n')
edit(f,'\tp.avatarArmorBreak = 0\n','\tif not VerifiedRules.Poison.preserves(self, p_idx, -1): p.avatarArmorBreak = 0\n')
edit(f,'\t\tunit.armorBreak = 0\n','\t\tif not VerifiedRules.Poison.preserves(self, p_idx, i): unit.armorBreak = 0\n')
before(f,'\tVerifiedRules.SpellReplay.begin_turn(self)\n','\tVerifiedRules.Poison.turn_start(self, p_idx)\n')
after(f,'\tif cancelled > 0: VerifiedRules.event(self, "armor-cancelled", {"uid": unit.uid, "amount": cancelled})\n','\tif cancelled > 0: VerifiedRules.Poison.refresh_all(self)\n')
f='scripts/armor_break_rules.gd'
after(f,'\tif value > 0:\n\t\tgs.VerifiedRules.event(gs, "armor-break-consumed", {"player": owner, "target": "" if idx < 0 else gs.player(owner).units[idx].uid, "amount": value})\n','\t\tgs.VerifiedRules.Poison.refresh_all(gs)\n')
after(f,'\tgs.VerifiedRules.event(gs, "armor-break-gained", {"player": source_owner, "uid": source.uid, "target": target, "victimPlayer": owner, "amount": value})\n','\tgs.VerifiedRules.Poison.refresh_all(gs)\n')
after(f,'\tif convert: return give(gs, source_owner, src, owner, idx, power)\n','\tif gs.VerifiedRules.Poison.convert_damage(gs, source_owner, src, owner, idx, power): return empty\n')
f='scripts/combat_keyword_rules.gd'
after(f,'\tgs.VerifiedRules.Light.combat_dealt(gs, owner, src, victim, idx, result)\n','\tgs.VerifiedRules.Poison.combat_dealt(gs, owner, src, victim, idx, result)\n')
f='scripts/form_countdown_rules.gd'
after(f,'\tunit.formAbility = ""\n','\tgs.VerifiedRules.Poison.refresh_all(gs)\n')
f='scripts/game_ai.gd'
after(f,'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','\tvar poison_score = _gs.VerifiedRules.Poison.score_card(_gs, p_idx, card, _target)\n\tif poison_score != null: return int(poison_score)\n')
f='scripts/ui/battle_status.gd'
after(f,'\tview.lightImmune = int(gs.player(owner).get("monkImmuneTurn", -1)) == gs.turn_counter\n','\tview.poisonReduction = gs.VerifiedRules.Poison.power_reduction(gs, owner, view)\n\tview.poisonRetained = gs.VerifiedRules.Poison.preserves(gs, owner, idx)\n')
after(f,'\tif active:\n','\t\tif unit.get("poisonRetained", false): result.append(mark("armor-break-retained", "破甲保留", "己方回合开始不会清除破甲；仍会被护甲抵消或伤害引爆。", "bdacd8"))\n\t\tif int(unit.get("poisonReduction", 0)) > 0: result.append(mark("armor-break-reduction", "火吻之蛇 · 力量 -%d" % int(unit.poisonReduction), "按当前破甲动态降低力量；破甲消耗或形态离场后解除。", "bdacd8"))\n\t\tif int(unit.get("poisonShieldTurn", -1)) == turn and turn >= 0: result.append(mark("poison-shield", "剧毒之盾 · 战斗伤害后3破甲", "仅本回合；须实际对式神造成战斗伤害。", "bdacd8"))\n')
p=json.loads(Path(__file__).with_name('overlay.json').read_text());v=json.loads((root/'content/verified_rules.json').read_text())
v['sources'].extend(p['sources'])
for key in ['units','cards']:v[key].update(p[key])
if '--check' in sys.argv:
 print('POISON_PAIR_ANCHORS_OK',root);raise SystemExit(0)
for rel,body in contents.items():(root/rel).write_text(body)
(root/'content/verified_rules.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
for name in ['poison_rules.gd','verify_poison_pair.gd','verify_poison_pair_ui.gd']:
 src=source/'godot/scripts'/name; dst=root/'scripts'/name
 if src.exists() and src.resolve()!=dst.resolve():shutil.copy2(src,dst)
print('POISON_PAIR_INTEGRATION_OK',root)
