class_name BailangRules
extends RefCounted
## Temporary spell enhancements and private, source-owned delayed shots.

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("archerDamage", false)

static func swift(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and unit.get("untilAttack", {}).get("swift", false)

static func unyielding(unit: Dictionary) -> bool:
	return unit.get("untilAttack", {}).get("unyielding", false)

static func damage_dealt(gs, owner: int, src: int, victim: int, damage: int, combat: bool) -> void:
	if owner < 0 or src < 0 or damage <= 0 or owner == victim or owner != gs.current_player or gs.winner >= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not is_source(unit) or int(unit.hp) <= 0 or int(unit.level) < 1 or (not unit.awakened and not combat): return
	gs.VerifiedRules.base_damage_avatar(gs,owner,src,victim,4 if unit.awakened else 2)
	gs.VerifiedRules.event(gs, "archer-ability", {"player": owner, "uid": unit.uid, "amount": 4 if unit.awakened else 2})

static func after_attack(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not unit.has("untilAttack"): return
	if not unit.get("formRules", {}).get("retainSpellEnhancements", false):
		unit.erase("untilAttack")
		gs._recalc(unit)

static func turn_start(gs, owner: int) -> void:
	# Remove due records before resolving; source death, stun and card counters
	# cannot cancel a spell that already resolved on an earlier turn.
	var p: Dictionary = gs.player(owner)
	var due: Array = p.get("delayedShots", []).duplicate(true)
	p.delayedShots = []
	for shot in due:
		if gs.winner >= 0: break
		var target: int = gs._unit_index_by_uid(1 - owner, shot.target)
		if target < 0 or int(gs.player(1 - owner).units[target].hp) <= 0: continue
		var old: Dictionary = gs._card_effect_context
		gs._card_effect_context = {"playerIndex": owner, "sourceIndex": int(shot.sourceIndex), "cardOverride": shot.card, "affectedUnits": []}
		gs._damage_unit(1 - owner, target, int(shot.damage), owner, int(shot.sourceIndex))
		gs._card_effect_context = old
		gs.VerifiedRules.event(gs, "delayed-shot-resolved", {"player": owner, "uid": p.units[int(shot.sourceIndex)].uid, "target": shot.target, "card": shot.card})

static func unit_view(gs, owner: int, src: int, viewer: int) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[src].duplicate(true)
	if owner == viewer:
		var hints: Array = []
		for shot in gs.player(owner).get("delayedShots", []):
			if int(shot.sourceIndex) != src: continue
			var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, shot.target)
			hints.append("%s · %d伤害" % [str(target.get("name", "目标")), int(shot.damage)])
		if not hints.is_empty(): unit.privateShotHints = hints
	return unit

static func public_command(command: Dictionary, viewer: int) -> Dictionary:
	var view := command.duplicate(true)
	if int(command.p) != viewer and command.c == "play_card" and command.a.get("cardView", {}).get("effect") == "archer-delayed-shot":
		view.a.target = null
	return view

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"archer-enhance":
			var buff: Dictionary = unit.get("untilAttack", {"attack": 0, "keywords": []})
			buff.attack = int(buff.attack) + int(effect.value.get("attack", 0))
			for keyword in effect.value.get("keywords", []):
				if keyword not in buff.keywords: buff.keywords.append(keyword)
			for keyword in ["swift", "unyielding"]:
				if effect.value.get(keyword, false): buff[keyword] = true
			unit.untilAttack = buff
			gs._recalc(unit)
		"archer-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"archer-delayed-shot":
			if target.is_empty(): return true
			var p: Dictionary = gs.player(owner)
			if not p.has("delayedShots"): p.delayedShots = []
			p.delayedShots.append({"target": target.uid, "damage": int(effect.value), "sourceIndex": src, "card": card.duplicate(true)})
			gs._log("白狼拉弓蓄势，将在己方下回合开始时结算「会」。", gs.TONE_CARD)
		"archer-cover":
			var idx: int = gs.front_index(1 - owner)
			if idx >= 0: gs._damage_unit(1 - owner, idx, int(unit.attack), owner, src)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return null
	var unit: Dictionary = gs.player(owner).units[src]
	match str(card.get("effect", "")):
		"archer-enhance": return 55 if gs.can_basic_attack(owner, src).ok or gs.player(owner).hand.any(func(c): return c.definitionId == "c11003") else 8
		"archer-awaken": return 62 if not unit.awakened else 10
		"form": return 70 if not unit.get("formRules", {}).get("retainSpellEnhancements", false) else -100
		"archer-cover":
			var front: Dictionary = gs.front_unit(1 - owner)
			return -100 if front.is_empty() else (60 if int(front.hp) + int(front.shield) <= int(unit.attack) else 28)
		"archer-delayed-shot":
			if gs.player(owner).get("delayedShots", []).any(func(s): return s.target == target_id): return -100
			var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
			return 28 + int(target.get("attack", 0)) * 3 + mini(int(target.get("hp", 0)), 8)
		"assault": return 50 + int(unit.attack) * 2
	return null
