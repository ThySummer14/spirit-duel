class_name ArmorBreakRules
extends RefCounted
## Poison is a character status. Conversion replaces an effect; it must never
## recurse through the same combat conversion or fabricate a second attack.

static func amount(gs, owner: int, idx: int) -> int:
	return int(gs.player(owner).get("avatarArmorBreak", 0)) if idx < 0 else int(gs.player(owner).units[idx].get("armorBreak", 0))

static func consume(gs, owner: int, idx: int) -> int:
	var value := amount(gs, owner, idx)
	if idx < 0: gs.player(owner).avatarArmorBreak = 0
	else: gs.player(owner).units[idx].armorBreak = 0
	if value > 0:
		gs.VerifiedRules.event(gs, "armor-break-consumed", {"player": owner, "target": "" if idx < 0 else gs.player(owner).units[idx].uid, "amount": value})
	return value

static func give(gs, source_owner: int, source_idx: int, owner: int, idx: int, value: int, convert: bool = true) -> Dictionary:
	var empty := {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if value <= 0 or gs.winner >= 0: return empty
	if idx >= 0 and int(gs.player(owner).units[idx].hp) <= 0: return empty
	var source: Dictionary = gs.player(source_owner).units[source_idx]
	var target := "" if idx < 0 else str(gs.player(owner).units[idx].uid)
	if convert and int(source.hp) > 0 and source.get("formRules", {}).get("armorBreakToDamage", false):
		gs.VerifiedRules.event(gs, "armor-break-converted", {"player": source_owner, "uid": source.uid, "target": target, "victimPlayer": owner, "amount": value})
		# Direct damage is already the replacement result. Do not run the combat
		# damage-to-poison conversion again (碧羽散华 + 毒蚀).
		if idx < 0:
			var dealt: int = gs._damage_avatar(owner, value, source_owner, source_idx)
			return {"damage": dealt, "dealt": dealt, "knocked": false, "overkill": 0}
		return gs._damage_unit(owner, idx, value, source_owner)
	if idx < 0: gs.player(owner).avatarArmorBreak = amount(gs, owner, idx) + value
	else: gs.player(owner).units[idx].armorBreak = amount(gs, owner, idx) + value
	gs._log("%s 获得%d破甲。" % [gs.player(owner).name + "的牌手" if idx < 0 else gs.player(owner).units[idx].name, value], gs.TONE_DANGER)
	gs.VerifiedRules.event(gs, "armor-break-gained", {"player": source_owner, "uid": source.uid, "target": target, "victimPlayer": owner, "amount": value})
	if idx >= 0:
		var victim: Dictionary = gs.player(owner).units[idx]
		# 'This turn's first gain' belongs to each enemy, including gains before
		# the form entered. Replacing the form cannot reset that fact.
		var first: bool = int(victim.get("armorBreakGainedTurn", -1)) != gs.turn_counter
		victim.armorBreakGainedTurn = gs.turn_counter
		if first:
			for i in gs.player(1 - owner).units.size():
				var observer: Dictionary = gs.player(1 - owner).units[i]
				var reduction := int(observer.get("formRules", {}).get("firstEnemyArmorBreakCountdown", 0))
				if int(observer.hp) > 0 and reduction > 0:
					gs.resolution_stack.append({"kind": "countdown-change", "playerIndex": 1 - owner, "sourceIndex": i, "delta": -reduction})
	return empty

static func prepare_combat(gs, enemy: int, idx: int, options: Dictionary) -> Dictionary:
	var result := options.duplicate(true)
	var marked := amount(gs, enemy, idx) > 0
	result.immuneCombat = marked and options.get("immuneAgainstArmorBreak", false)
	result.lifeSteal = marked and options.get("lifeStealAgainstArmorBreak", false)
	return result

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> void:
	if int(gs.player(owner).units[src].hp) <= 0: return
	var continuation: Dictionary = {}
	for frame in gs.resolution_stack:
		if frame.get("kind") == "combat-hit" and int(frame.get("combatId", -1)) == combat_id: continuation = frame
	if continuation.is_empty(): return
	continuation.defenderBonus = int(continuation.get("defenderBonus", 0)) + int(card.value)
	if card.get("combatOption", {}).get("convertCombatToArmorBreak", false):
		continuation.options.convertCombatToArmorBreak = true
	gs.VerifiedRules.event(gs, "combat-response-applied", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": card})

static func combat_damage(gs, source_owner: int, src: int, owner: int, idx: int, power: int, convert: bool, immune: bool = false) -> Dictionary:
	var empty := {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if power <= 0: return empty
	if convert: return give(gs, source_owner, src, owner, idx, power)
	if immune:
		# A real damage event first consumes a barrier, then combat immunity
		# prevents damage without consuming armor or existing poison.
		if idx >= 0 and gs.player(owner).units[idx].get("barrier", false):
			return gs._damage_unit(owner, idx, power, source_owner)
		gs.VerifiedRules.event(gs, "combat-immune", {"player": owner, "uid": "" if idx < 0 else gs.player(owner).units[idx].uid})
		return empty
	if idx < 0:
		var dealt: int = gs._damage_avatar(owner, power, source_owner, src)
		return {"damage": dealt, "dealt": dealt, "knocked": false, "overkill": 0}
	return gs._damage_unit(owner, idx, power, source_owner)

static func after_combat_damage(gs, owner: int, src: int, victim_owner: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	var dealt := int(result.get("dealt", result.damage))
	if dealt <= 0: return
	if options.get("lifeSteal", false) and gs.winner < 0:
		gs._heal_avatar(owner, dealt)
	if options.get("halfRemainingHpArmorBreak", false):
		var hp := int(gs.player(victim_owner).avatarHp) if idx < 0 else int(gs.player(victim_owner).units[idx].hp)
		give(gs, owner, src, victim_owner, idx, int(floor(hp / 2.0)))

static func resolve_action(gs, owner: int, src: int, effect: Dictionary, target: Dictionary) -> bool:
	var source: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"poison-countdown":
			var history := int(source.get("poisonTriggers", 0))
			var value := int(effect.value) + (history if effect.get("growsWithHistory", false) else 0)
			source.poisonTriggers = history + 1
			give(gs, owner, src, 1 - owner, -1, value)
		"apply-armor-break":
			match str(effect.get("target", "")):
				"enemy-avatar", "enemy-player": give(gs, owner, src, 1 - owner, -1, int(effect.value))
				"all-enemy-units":
					for i in gs.player(1 - owner).units.size(): give(gs, owner, src, 1 - owner, i, int(effect.value))
				"enemy-front":
					var idx: int = gs.front_index(1 - owner)
					if idx >= 0: give(gs, owner, src, 1 - owner, idx, int(effect.value))
				"source": give(gs, owner, src, owner, src, int(effect.value))
				_:
					if not target.is_empty():
						for p in 2:
							var idx: int = gs._unit_index_by_uid(p, target.uid)
							if idx >= 0: give(gs, owner, src, p, idx, int(effect.value))
		_: return false
	return true
