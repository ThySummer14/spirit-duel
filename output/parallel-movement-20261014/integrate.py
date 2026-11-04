"""Transaction guarded Movement integration. Run once on a Godot directory."""
import json,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve();changes={}
def edit(rel,old,new,n=1):
 p=root/rel;s=changes.get(rel,p.read_text());actual=s.count(old)
 if actual!=n:raise SystemExit(f'{rel}: expected {n}, got {actual}: {old[:100]!r}')
 changes[rel]=s.replace(old,new,n)
def after(rel,old,new):edit(rel,old,old+new)
def before(rel,old,new):edit(rel,old,new+old)
def block(rel,start,end,new):
 p=root/rel;s=changes.get(rel,p.read_text());a=s.index(start);b=s.index(end,a);changes[rel]=s[:a]+new+s[b:]
f='scripts/verified_card_rules.gd'
after(f,'const Fortune := preload("res://scripts/fortune_pair_rules.gd")','\nconst Movement := preload("res://scripts/movement_rules.gd")')
after(f,'static func card_announced(gs, p_idx: int, src: int, card: Dictionary) -> void:\n','\tMovement.announced(gs, p_idx, src)\n')
after(f,'static func resolve_action(gs, p_idx: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:\n','\tif Movement.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true\n')
after(f,'static func end_turn(gs, p_idx: int) -> void:\n','\tMovement.end_turn(gs, p_idx)\n')
after(f,'\t\t\tgs._log("%s 气绝倒计时结束，恢复全部生命。" % unit.name, gs.TONE_SUCCESS)\n','\t\t\tMovement.revived(gs, p_idx, src)\n')
block(f,'static func move_unit(gs, p_idx: int, unit: Dictionary) -> void:\n','static func resolve_action(','''static func move_unit(gs, p_idx: int, unit: Dictionary) -> void:
	if unit.is_empty() or int(unit.hp) <= 0: return
	var idx: int = gs._unit_index_by_uid(p_idx, unit.uid)
	if idx >= 0: Movement.move_to(gs, p_idx, idx, 1 - int(unit.front))

''')
f='scripts/game_state.gd'
after(f,'func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','\tif pending_choice.get("type") == "movement-burst": return VerifiedRules.Movement.resolve_choice(self, p_idx, instance_id)\n')
after(f,'\tcard = VerifiedRules.Fortune.describe_card(self, p_idx, card)\n','\tcard = VerifiedRules.Movement.describe_card(self, p_idx, p.hand[hand_index], card)\n')
before(f,'\tif not VerifiedRules.DogDemon.can_use(self, p_idx, card):\n','\tif not VerifiedRules.Movement.can_use(self, p_idx, card):\n\t\treturn {"ok": false, "reason": "能量不足或爆能档位无效。"}\n')
before(f,'\tif card.get("effect") == "move-unit":\n','\tif card.get("type") != "combat":\n\t\tout = out.filter(func(uid): return _unit_index_by_uid(p_idx, uid) >= 0 or not (VerifiedRules.Combat.has(_unit_by_uid(foe.units, uid), "veil") or VerifiedRules.Movement.has_veil(_unit_by_uid(foe.units, uid))))\n')
after(f,'func _resolve_frame(frame: Dictionary) -> void:\n','\tif VerifiedRules.Movement.resolve_frame(self, frame): return\n')
edit(f,'effects[idx].get("action") in ["assault", "fortune-combat"]:', 'effects[idx].get("action") in ["assault", "fortune-combat", "movement-combat"]:')
after(f,'\tif int(frame.get("combatResponseId", -1)) >= 0 and effects[idx].get("action") in ["assault", "fortune-combat", "movement-combat"]:\n','\t\tif VerifiedRules.Movement.respond_combat(self, int(frame.combatResponseId), p_idx, src, card): return\n')
after(f,'\tunit.attack += VerifiedRules.Fortune.power(self, unit)\n','\tunit.attack += VerifiedRules.Movement.power(unit, turn_counter)\n\tif VerifiedRules.Movement.zero_power(self, unit): unit.attack = 0\n')
before(f,'\tvar dmg := amount + VerifiedRules.ArmorBreak.consume(self, p_idx, unit_index)\n','''	var preview: int = VerifiedRules.Bingyong.limit_damage(u, amount + int(u.armorBreak) + (1 if int(u.brittle) > 0 else 0))
	preview = maxi(0, preview - int(u.shield))
	var preview_cap := int(u.get("formRules", {}).get("damageCap", 0))
	if preview_cap > 0: preview = mini(preview, preview_cap)
	if VerifiedRules.Movement.prevents_lethal(self, p_idx, unit_index, preview):
		_record_spell_damage(p_idx, str(u.uid), 0, true)
		return {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
''')
before(f,'\tVerifiedRules.DogDemon.knocked_out(u)\n','\tVerifiedRules.Movement.knocked_out(self, u)\n')
after(f,'\tVerifiedRules.BookJue.avatar_damaged(self, _src_player, source_index, p_idx, amount)\n','\tVerifiedRules.Movement.avatar_damaged(self, _src_player, source_index, p_idx, actual_loss)\n')
edit(f,'\tif p.attackUsed:\n\t\treturn {"ok": false, "reason": "本回合已经出击过。"}\n','\tif p.attackUsed and (unit_index < 0 or unit_index >= p.units.size() or not VerifiedRules.Movement.extra_attack(self, p_idx, p.units[unit_index])):\n\t\treturn {"ok": false, "reason": "本回合已经出击过。"}\n')
edit(f,'\tif int(p.energy) < (0 if u.get("swift", false) or VerifiedRules.Yaodao.permanent_swift(u) or VerifiedRules.Bailang.swift(u) else 1):','\tif not VerifiedRules.Movement.extra_attack(self, p_idx, u) and int(p.energy) < (0 if u.get("swift", false) or VerifiedRules.Yaodao.permanent_swift(u) or VerifiedRules.Bailang.swift(u) else 1):')
edit(f,'\tp.energy = int(p.energy) - (0 if p.units[unit_index].get("swift", false) or VerifiedRules.Yaodao.permanent_swift(p.units[unit_index]) or VerifiedRules.Bailang.swift(p.units[unit_index]) else 1)\n','\tif VerifiedRules.Movement.extra_attack(self, p_idx, p.units[unit_index]):\n\t\tif not VerifiedRules.Movement.pay_extra_attack(self, p_idx, unit_index): return false\n\telse:\n\t\tp.energy = int(p.energy) - (0 if p.units[unit_index].get("swift", false) or VerifiedRules.Yaodao.permanent_swift(p.units[unit_index]) or VerifiedRules.Bailang.swift(p.units[unit_index]) else 1)\n')
edit(f,'\tif remote: attacker.front = 0\n','')
before(f,'\tif not remote:\n\t\tVerifiedRules.Xuenv.clear_wall(self, p_idx)\n','\tvar movement_depth := resolution_stack.size()\n\tvar movement_old: Array = p.units.map(func(u): return int(u.front))\n')
before(f,'\tvar entry := {"kind": "combat-entered",','\tif not remote:\n\t\tfor i in p.units.size(): VerifiedRules.Movement.moved(self, p_idx, i, int(movement_old[i]))\n')
before(f,'\t# The entering response finishes before attack power is read.','\tif resolution_stack.size() > movement_depth:\n\t\tentry.kind = "movement-combat-entry"\n\t\tresolution_stack.insert(movement_depth, entry)\n\t\treturn\n')
after(f,'\tVerifiedRules.Fortune.before_attack(self, p_idx, unit_index)\n','\tVerifiedRules.Movement.before_attack(self, p_idx, unit_index)\n\tif int(attacker.hp) <= 0 or winner >= 0: return\n')
before(f,'\tVerifiedRules.Poison.transfer_before_combat(self, p_idx, unit_index, e_idx, fi, options)\n','\tif options.get("movementRedirect", false): fi = VerifiedRules.Movement.redirect_target(self, p_idx, fi)\n\tif fi >= 0: VerifiedRules.Movement.deer_combat(self, e_idx, fi)\n\tif fi >= 0 and int(foe.units[fi].hp) <= 0: fi = front_index(e_idx)\n\tif int(attacker.hp) <= 0 or winner >= 0: return\n')
after(f,'\tVerifiedRules.Fortune.combat_finished(self, owner, src, options)\n','\tVerifiedRules.Movement.combat_finished(self, owner, src, options)\n')
after(f,'func _resolve_combat_hit(frame: Dictionary) -> void:\n','\tif frame.get("movementCancelled", false): return\n')
# Shared counterstrike wrapper preserves source and real retargeted impact cues.
edit(f,'\t\t\tvar early := VerifiedRules.Combat.strike(self, victim, idx, owner, src, counter_power, d_options, bool(frame.get("defenderPierce", false)), bool(options.get("immuneCombat", false)))\n\t\t\t_record_combat_strike(victim, idx, owner, src, early, visual_step, frame.get("defenderCombatCard", {}))\n','\t\t\tframe.movementVisualStep = visual_step\n\t\t\tVerifiedRules.Movement.counterstrike(self, frame, counter_power, d_options)\n')
edit(f,'\t\t\tvar counter := VerifiedRules.Combat.strike(self, victim, idx, owner, src, counter_power, d_options, bool(frame.get("defenderPierce", false)), bool(options.get("immuneCombat", false)))\n\t\t\t_record_combat_strike(victim, idx, owner, src, counter, visual_step, frame.get("defenderCombatCard", {}))\n','\t\t\tif VerifiedRules.Movement.zero_power(self, defender): counter_power = 0\n\t\t\tframe.movementVisualStep = visual_step\n\t\t\tVerifiedRules.Movement.counterstrike(self, frame, counter_power, d_options)\n')
after(f,'\t\t\t\t_log("%s 自行归队，生命回复至满。" % u.name, TONE_SUCCESS)\n','\t\t\t\tVerifiedRules.Movement.revived(self, p_idx, _unit_index_by_uid(p_idx, u.uid))\n')
after(f,'\t\t\t_log("%s 从战斗区返回准备区。" % u.name, TONE_NEUTRAL)\n','\t\t\tVerifiedRules.Movement.moved(self, p_idx, _unit_index_by_uid(p_idx, u.uid), 1)\n')
before(f,'\tif not VerifiedRules.BookJue.turn_draw(self, p_idx): _draw(p_idx, 1)\n','\t_resolve_resolution_stack()\n\tif winner >= 0: return\n')
# Remaining shared explicit movements also notify displaced Crow abilities.
f='scripts/game_state.gd'
edit(f,'\t\t\t\tplayer(e_idx).units[idx].front = 0\n','\t\t\t\tVerifiedRules.Movement.move_to(self, e_idx, idx, 0)\n')
# A legacy revival still represents a real revival, without changing its growth.
after(f,'\t\t\t\t\t_log("%s 被余辉唤回，恢复全部生命。" % u.name, TONE_SUCCESS)\n','\t\t\t\t\tVerifiedRules.Movement.revived(self, p_idx, _unit_index_by_uid(p_idx, u.uid))\n')
f='scripts/dog_demon_rules.gd'
after(f,'\t\tfor ally in gs.player(owner).units: ally.front = 1 if ally.uid == unit.uid else 0\n','\t\tfor old in movement_old: gs.VerifiedRules.Movement.moved(gs, owner, int(old.idx), int(old.front))\n')
before(f,'\t\tfor ally in gs.player(owner).units: ally.front = 1 if ally.uid == unit.uid else 0\n','\t\tvar movement_old: Array = []\n\t\tfor i in gs.player(owner).units.size(): movement_old.append({"idx": i, "front": int(gs.player(owner).units[i].front)})\n')
after(f,'\t\t\ttarget.front = 1\n','\t\t\tgs.VerifiedRules.Movement.moved(gs, 1 - owner, gs._unit_index_by_uid(1 - owner, target.uid), 0)\n')
f='scripts/poison_rules.gd'
before(f,'\t\tfor unit in gs.player(owner).units: unit.front = 1 if unit.uid == source.uid else 0\n','\t\tvar movement_old: Array = []\n\t\tfor i in gs.player(owner).units.size(): movement_old.append({"idx": i, "front": int(gs.player(owner).units[i].front)})\n')
after(f,'\t\tfor unit in gs.player(owner).units: unit.front = 1 if unit.uid == source.uid else 0\n','\t\tfor old in movement_old: gs.VerifiedRules.Movement.moved(gs, owner, int(old.idx), int(old.front))\n')
f='scripts/sun_smoke_rules.gd'
after(f,'static func summon(gs, owner: int, src: int, mode: String = "") -> void:\n','\tvar movement_old: Array = gs.player(owner).units.map(func(u): return int(u.front))\n')
after(f,'\tp.units.append(clone)\n','\tfor i in movement_old.size(): gs.VerifiedRules.Movement.moved(gs, owner, i, int(movement_old[i]))\n')
f='scripts/ui/battle_status.gd'
after(f,'\t\tif int(unit.get("frozen", 0)) > 0: result.append(mark("stun", "眩晕 ×%d" % int(unit.frozen), "不能主动出击或使用所属牌；仍能反击。持续至持有者下个回合结束。", "b39ce6", int(unit.frozen)))\n','\t\tif unit.has("movementHolders"): result.append(mark("crow-stun-hold", "英雄无畏 · 保持眩晕", "直到施放此牌的鸦天狗使用牌、攻击或气绝；其他眩晕独立保留。", "b39ce6"))\n')
f='scripts/combat_keyword_rules.gd'
after(f,'static func has(unit: Dictionary, keyword: String) -> bool:\n','\tif keyword == "veil" and unit.get("movementVeil", false) and int(unit.hp) > 0: return true\n')
edit(f,'\treturn 0 if zero_power(gs, owner, unit) else maxi(0, int(unit.attack) + bonus)','\treturn 0 if zero_power(gs, owner, unit) or gs.VerifiedRules.Movement.zero_power(gs, unit) else maxi(0, int(unit.attack) + bonus)')
after(f,'\tgs.VerifiedRules.Poison.combat_dealt(gs, owner, src, victim, idx, result)\n','\tgs.VerifiedRules.Movement.combat_dealt(gs, owner, src, victim, idx, result, options)\n')
f='scripts/armor_break_rules.gd'
edit(f,'\tresult.lifeSteal = marked and options.get("lifeStealAgainstArmorBreak", false)','\tresult.lifeSteal = options.get("lifeSteal", false) or (marked and options.get("lifeStealAgainstArmorBreak", false))')
f='scripts/peach_rules.gd'
after(f,'\tgs.VerifiedRules.event(gs, "peach-revive", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": target.uid})\n','\tgs.VerifiedRules.Movement.revived(gs, owner, gs._unit_index_by_uid(owner, target.uid))\n')
f='scripts/stun_rules.gd'
after(f,'\tvar remaining := duration + (1 if owner == gs.current_player else 0)\n','\tif idx >= 0 and target.has("movementHolders"): target.movementBaseFrozen = maxi(int(target.get("movementBaseFrozen", 0)), remaining)\n')
edit(f,'\tfor unit in p.units: unit.frozen = maxi(0, int(unit.frozen) - 1)','\tfor unit in p.units:\n\t\tif unit.has("movementHolders"):\n\t\t\tunit.movementBaseFrozen = maxi(0, int(unit.get("movementBaseFrozen", 0)) - 1)\n\t\t\tunit.frozen = maxi(1, int(unit.movementBaseFrozen))\n\t\telse: unit.frozen = maxi(0, int(unit.frozen) - 1)')
f='scripts/game_ai.gd'
after(f,'static func _best_card(gs: GameState, p_idx: int) -> Dictionary:\n','\tgs.VerifiedRules.Movement.ai_prepare(gs, p_idx)\n')
after(f,'static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n','\tif gs.pending_choice.get("type") == "movement-burst": return gs.VerifiedRules.Movement.ai_choice(gs, p_idx)\n')
after(f,'static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','\tvar movement_score = _gs.VerifiedRules.Movement.score_card(_gs, p_idx, card, _target)\n\tif movement_score != null: return int(movement_score)\n')
f='scripts/ui/battle_screen.gd'
before(f,'\tif card.has("originCard") and not choice_made:\n','\tif not choice_made and gs.VerifiedRules.Movement.request_burst(gs, PLAYER, index):\n\t\t_refresh()\n\t\treturn\n')
after(f,'\t\tif book_jue_choice_card != null: def = book_jue_choice_card\n','\t\tvar movement_choice_card = gs.VerifiedRules.Movement.choice_card(gs, PLAYER, str(iid))\n\t\tif movement_choice_card != null: def = movement_choice_card\n')
edit(f,'\t\t\t\t_refresh()\n\t\t\t\t_check_auto_ai()\n\t\t, Vector2(168, 262))','\t\t\t\t_refresh()\n\t\t\t\tvar ready := gs.VerifiedRules.Movement.ready_hand(gs, PLAYER)\n\t\t\t\tif ready >= 0: _on_hand_clicked(ready, gs.hand_card_def(PLAYER, ready), false, true)\n\t\t\t\t_check_auto_ai()\n\t\t, Vector2(168, 262))')
# Normal card may be unaffordable while its burst instant alternative is legal.
after(f,'func _hand_playability(index: int, use_origin: Variant = null) -> Dictionary:\n','\tif gs != null and gs.VerifiedRules.Movement.has_playable_burst(gs, PLAYER, index): return {"ok": true, "reason": ""}\n')
# Merge only these IDs and sources. Every anchor is checked before any write.
v=json.loads((root/'content/verified_rules.json').read_text())
for name in ['overlay.json','backfill_overlay.json']:
 o=json.loads(Path(__file__).with_name(name).read_text());known={s['id'] for s in v['sources']};v['sources'].extend(s for s in o['sources'] if s['id'] not in known)
 for group in ['units','cards']:v[group].update(o[group])
changes['content/verified_rules.json']=json.dumps(v,ensure_ascii=False,indent=2)+'\n'
if '--check' not in sys.argv:
 for rel,s in changes.items():(root/rel).write_text(s)
print('MOVEMENT_INTEGRATION_CHECK_OK' if '--check' in sys.argv else 'MOVEMENT_INTEGRATION_OK',root,len(changes))
