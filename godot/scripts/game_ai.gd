class_name GameAI
extends RefCounted
## Simple greedy scorer for the vertical slice AI opponent.

const ContentLoader := preload("res://scripts/content_loader.gd")


static func take_action(gs: GameState, p_idx: int) -> bool:
	## One command per presentation beat; take_turn remains the fast simulation API.
	if gs.action_player() != p_idx:
		return false
	if not gs.pending_choice.is_empty():
		return _resolve_choice(gs, p_idx)
	if not gs.response_window.is_empty():
		var actions: Array = []
		return _try_response(gs, p_idx, actions) or gs.pass_response(p_idx)
	if gs.is_upgrade_pending(p_idx):
		var unit := _best_level_up(gs, p_idx)
		return unit >= 0 and gs.level_up(p_idx, unit)
	var play := _best_card(gs, p_idx)
	if play.ok and gs.play_card(p_idx, play.hand, play.target, bool(play.get("origin", false))):
		return true
	var attack := _best_attack(gs, p_idx)
	if attack.ok and gs.basic_attack(p_idx, attack.unit):
		return true
	return gs.end_turn(p_idx)


static func take_turn(gs: GameState, p_idx: int) -> Array:
	## Returns list of commands performed (already applied).
	var actions: Array = []
	if gs.winner >= 0:
		return actions
	# Only control this side. Human responses and choices must remain pending.
	var guard := 0
	while guard < 32 and gs.winner < 0 and gs.action_player() == p_idx:
		guard += 1
		if not gs.pending_choice.is_empty():
			if _resolve_choice(gs, p_idx):
				actions.append({"cmd": "divination-choice"})
				continue
			break
		if not gs.response_window.is_empty():
			if _try_response(gs, p_idx, actions):
				continue
			if gs.pass_response(p_idx):
				actions.append({"cmd": "pass_response", "player": p_idx})
				continue
			break
		if gs.is_upgrade_pending(p_idx):
			var uidx := _best_level_up(gs, p_idx)
			if uidx >= 0 and gs.level_up(p_idx, uidx):
				actions.append({"cmd": "level_up", "unit": uidx})
				continue
			break
		var play := _best_card(gs, p_idx)
		if play.ok:
			if gs.play_card(p_idx, play.hand, play.target, bool(play.get("origin", false))):
				actions.append({"cmd": "play_card", "hand": play.hand, "target": play.target, "card": play.card_id})
				continue
		var atk := _best_attack(gs, p_idx)
		if atk.ok:
			if gs.basic_attack(p_idx, atk.unit, null):
				actions.append({"cmd": "basic_attack", "unit": atk.unit})
				continue
		break
	if gs.action_player() == p_idx and gs.pending_choice.is_empty() and gs.response_window.is_empty():
		if gs.end_turn(p_idx):
			actions.append({"cmd": "end_turn"})
	return actions


static func _best_level_up(gs: GameState, p_idx: int) -> int:
	var p := gs.player(p_idx)
	var best: int = -1
	var best_score: int = -999999
	var mn: int = gs.min_level(p_idx)
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		if int(u.level) >= int(gs.rules.get("maxUnitLevel", 3)):
			continue
		if int(u.level) != mn:
			continue
		var score: int = int(u.maxHp) * 2 + int(u.attack)
		if int(u.level) == 0:
			score += 40
		if int(u.hp) > 0:
			score += 8
		if score > best_score:
			best_score = score
			best = i
	return best


static func _best_card(gs: GameState, p_idx: int) -> Dictionary:
	var p := gs.player(p_idx)
	var best := {"ok": false, "hand": -1, "target": null, "score": -1, "card_id": ""}
	for h in p.hand.size():
		for origin in [false, true]:
			var card := gs.playable_card(p_idx, h, origin)
			if card.is_empty(): continue
			var targets: Array = [null] if card.get("target", "auto") == "auto" else gs.valid_targets(p_idx, card)
			for t in targets:
				var check2 := gs.can_play_card(p_idx, h, t, origin)
				if check2.ok:
					var score2: int = _score_card(gs, p_idx, card, t)
					if score2 > best.score:
						best = {"ok": true, "hand": h, "target": t, "score": score2, "card_id": card.get("id"), "origin": origin}
	return best


static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:
	for native_score in [_gs.VerifiedRules.Phoenix.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Peach.score_card(_gs, p_idx, card, _target), _gs.VerifiedRules.Firefly.score_card(_gs, p_idx, card, _target)]:
		if native_score != null: return int(native_score)
	# Keep automatic counters in hand with the remaining fire; spending them in
	# the main phase without an opposing response has no benefit.
	if card.has("autoResponse") and not card.get("responseModifiesCombat", false): return -100
	var score: int = 0
	var action: String = str(card.get("effect", ""))
	var effects: Array = card.get("effects", []) if card.get("effects") is Array else []
	if not effects.is_empty():
		action = str(effects[0].get("action", action))
	match action:
		"assault", "damage", "burn-all", "brittle", "projectile-displace", "projectile-draw-on-kill", "random-damage":
			score = 50 + _num(card.get("value"))
		"heal", "shield", "fortify", "grant-unyielding", "revive":
			score = 40 + _num(card.get("value"))
		"draw", "draw-heal", "chain-draw", "focus-draw":
			score = 35
		"form", "awaken":
			score = 45
		"realm":
			score = 30
		"freeze", "apply-brittle":
			score = 42
		_:
			score = 20
	# prefer cheaper
	if action == "projectile-draw-on-kill":
		var front := _gs.front_unit(1 - p_idx)
		if not front.is_empty() and int(front.hp) + int(front.shield) <= _num(card.value): score += 30
	if card.get("combatOption", {}).get("pursuit", false):
		var target := _gs._unit_by_uid(_gs.player(1 - p_idx).units, _target)
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		if not target.is_empty():
			if int(target.hp) + int(target.shield) <= int(source.attack) + _num(card.value): score += 25
			score -= int(target.attack)
	if action == "move-unit":
		var target := _gs._unit_by_uid(_gs.player(p_idx).units, _target)
		if not target.is_empty():
			if int(target.get("spellCountdown", {}).get("remaining", 0)) == 1: score += 30
			if int(target.front) == 1 and int(target.hp) <= 3: score += 12
	if action == "countdown-change":
		var target := _gs._unit_by_uid(_gs._all_units(), _target)
		if effects[0].get("target") == "source": target = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		if not target.is_empty():
			var own := _gs._unit_index_by_uid(p_idx, target.uid) >= 0
			var delta := int(effects[0].value)
			if not _gs.VerifiedRules.has_countdown(target): score = -100
			elif (delta < 0) == own:
				var remaining := int(target.knockout) if int(target.hp) <= 0 else int(_gs.VerifiedRules.Countdown.timer(target).remaining)
				score = 60 + (30 if delta < 0 and remaining <= -delta else 0)
			else: score = -100
	if card.get("dynamicCountdownHistory", false):
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = -100 if source.get("abilityHistory", []).is_empty() else 40 + source.abilityHistory.size() * 15
	if action == "destroy-enemy-units":
		var living: int = _gs.player(1 - p_idx).units.filter(func(u): return int(u.hp) > 0).size()
		score = 70 + living * 15 if living > 0 else -100
	elif action == "generate-own-spell":
		score = 38 if _gs.player(p_idx).hand.size() < int(_gs.rules.maxHandSize) else -100
	elif action == "awaken-spell-replay":
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = 45 + (25 if int(source.get("spellCountdown", {}).get("remaining", 0)) == 1 else 0)
	if action == "destroy-own-form":
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = 32 if _gs.player(p_idx).hand.size() < int(_gs.rules.maxHandSize) - 1 else -100
		if not source.get("formCountdown", {}).is_empty(): score += 20
	elif action == "awaken-form-lifecycle":
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score = 55 if not source.awakened else 25
	var combat: Dictionary = card.get("combatOption", {})
	if not combat.is_empty():
		var foe := _gs.front_unit(1 - p_idx)
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		var marked := int(foe.get("armorBreak", 0)) > 0 if not foe.is_empty() else int(_gs.player(1 - p_idx).get("avatarArmorBreak", 0)) > 0
		if marked and combat.get("immuneAgainstArmorBreak", false): score += 25
		if marked and combat.get("lifeStealAgainstArmorBreak", false): score += 25 + mini(20, int(_gs.player(p_idx).maxAvatarHp) - int(_gs.player(p_idx).avatarHp))
		if combat.get("convertCombatToArmorBreak", false):
			# Keep the response unless a real follow-up can detonate the poison,
			# or the current form converts it directly to damage.
			var can_follow: bool = int(_gs.player(p_idx).energy) > int(card.cost) and not _gs.player(p_idx).attackUsed
			if source.get("formRules", {}).get("armorBreakToDamage", false): score = 70
			else: score = 58 if can_follow else -100
	if card.get("dynamicPoisonHistory", false):
		var source: Dictionary = _gs.player(p_idx).units[_gs._source_index(p_idx, card)]
		score += 20 if not source.awakened else 0
	score -= int(card.get("cost", 0)) * 3
	return score


static func _best_attack(gs: GameState, p_idx: int) -> Dictionary:
	var p := gs.player(p_idx)
	var best := {"ok": false, "unit": -1, "score": -1}
	var e_idx := gs.enemy_index(p_idx)
	var enemy_front_hp: int = 0
	var fi := gs.front_index(e_idx)
	if fi >= 0:
		enemy_front_hp = int(gs.player(e_idx).units[fi].hp) + int(gs.player(e_idx).units[fi].shield)
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		if not gs.can_basic_attack(p_idx, i).ok:
			continue
		var power: int = int(u.attack)
		if power > 0: power += gs.VerifiedRules.ArmorBreak.amount(gs, e_idx, fi)
		var score: int = power * 10
		if enemy_front_hp <= 0:
			score += 80  # free core hit
		elif power >= enemy_front_hp:
			score += 40  # likely knockout
		if int(u.front) == 1:
			score += 5
		if score > best.score:
			best = {"ok": true, "unit": i, "score": score}
	return best


static func _num(v) -> int:
	if v is int or v is float:
		return int(v)
	if v is Dictionary:
		return 1
	return 0


static func _resolve_choice(gs: GameState, p_idx: int) -> bool:
	var ids: Array = gs.pending_choice.get("instanceIds", [])
	if ids.is_empty():
		return false
	# 优先选费用/等级更高、或名字非衍生的展示牌；这里取最后一张（更接近牌库顶）
	return gs.resolve_divination_choice(p_idx, str(ids[ids.size() - 1]))


static func _try_response(gs: GameState, p_idx: int, actions: Array) -> bool:
	if gs.response_window.is_empty() or int(gs.response_window.get("playerIndex", -1)) != p_idx:
		return false
	var p := gs.player(p_idx)
	for h in p.hand.size():
		var card := ContentLoader.card_def(p.hand[h].definitionId)
		if not gs.card_matches_response_window(card):
			continue
		var targets: Array = [null]
		if card.get("target", "auto") != "auto":
			targets = gs.valid_targets(p_idx, card)
		for t in targets:
			if gs.play_card(p_idx, h, t):
				actions.append({"cmd": "play_card", "hand": h, "target": t, "card": card.get("id")})
				return true
	return false
