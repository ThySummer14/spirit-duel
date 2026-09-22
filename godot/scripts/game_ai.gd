class_name GameAI
extends RefCounted
## Simple greedy scorer for the vertical slice AI opponent.

const ContentLoader := preload("res://scripts/content_loader.gd")


static func take_turn(gs: GameState, p_idx: int) -> Array:
	## Returns list of commands performed (already applied).
	var actions: Array = []
	if gs.winner >= 0:
		return actions
	# 先处理中断型窗口（响应/占卜），避免对局卡死
	var stall := 0
	while stall < 32 and gs.winner < 0:
		stall += 1
		if not gs.pending_choice.is_empty():
			var want_p := int(gs.pending_choice.get("playerIndex", -1))
			if want_p == p_idx and _resolve_choice(gs, p_idx):
				actions.append({"cmd": "divination-choice"})
				continue
			# 对手选择中：不应发生在纯 AI 对刷；保险起见放行第一项
			if _resolve_choice_any(gs):
				actions.append({"cmd": "divination-choice"})
				continue
			break
		if not gs.response_window.is_empty():
			var rp := int(gs.response_window.get("playerIndex", -1))
			if rp == p_idx and _try_response(gs, p_idx, actions):
				continue
			if gs.pass_response(rp):
				actions.append({"cmd": "pass_response", "player": rp})
				continue
			break
		break
	if gs.winner >= 0 or gs.current_player != p_idx:
		return actions
	var guard := 0
	while guard < 32:
		guard += 1
		if gs.winner >= 0 or gs.current_player != p_idx:
			break
		if not gs.pending_choice.is_empty() or not gs.response_window.is_empty():
			var extra := take_turn(gs, p_idx)
			actions.append_array(extra)
			break
		if gs.is_upgrade_pending(p_idx):
			var uidx := _best_level_up(gs, p_idx)
			if uidx >= 0 and gs.level_up(p_idx, uidx):
				actions.append({"cmd": "level_up", "unit": uidx})
				continue
			# force: pick first legal
			for i in gs.player(p_idx).units.size():
				if gs.can_level_up(p_idx, i):
					gs.level_up(p_idx, i)
					actions.append({"cmd": "level_up", "unit": i})
					break
			continue
		var play := _best_card(gs, p_idx)
		if play.ok:
			if gs.play_card(p_idx, play.hand, play.target):
				actions.append({"cmd": "play_card", "hand": play.hand, "target": play.target, "card": play.card_id})
				continue
		var atk := _best_attack(gs, p_idx)
		if atk.ok:
			if gs.basic_attack(p_idx, atk.unit, null):
				actions.append({"cmd": "basic_attack", "unit": atk.unit})
				continue
		break
	if gs.current_player == p_idx and gs.winner < 0:
		gs.end_turn(p_idx)
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
		var card := ContentLoader.card_def(p.hand[h].definitionId)
		var targets := gs.valid_targets(p_idx, card)
		if card.get("target", "auto") == "auto":
			var check := gs.can_play_card(p_idx, h, null)
			if check.ok:
				var score: int = _score_card(gs, p_idx, card, null)
				if score > best.score:
					best = {"ok": true, "hand": h, "target": null, "score": score, "card_id": card.get("id")}
		else:
			for t in targets:
				var check2 := gs.can_play_card(p_idx, h, t)
				if check2.ok:
					var score2: int = _score_card(gs, p_idx, card, t)
					if score2 > best.score:
						best = {"ok": true, "hand": h, "target": t, "score": score2, "card_id": card.get("id")}
	return best


static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:
	var score: int = 0
	var action: String = str(card.get("effect", ""))
	var effects: Array = card.get("effects", []) if card.get("effects") is Array else []
	if not effects.is_empty():
		action = str(effects[0].get("action", action))
	match action:
		"assault", "damage", "burn-all", "brittle":
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


static func _resolve_choice_any(gs: GameState) -> bool:
	if gs.pending_choice.is_empty():
		return false
	var p_idx := int(gs.pending_choice.get("playerIndex", 0))
	return _resolve_choice(gs, p_idx)


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
