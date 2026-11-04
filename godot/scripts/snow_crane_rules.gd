class_name SnowCraneRules
extends RefCounted
## Snow combat conditions and crane attack/hand triggers; no name inference.
static func snow(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("snowCombat", false)
static func crane(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("craneRetreat", false)
static func immune(unit: Dictionary, opponent: Dictionary, attacking: bool) -> bool:
	return snow(unit) and int(opponent.get("frozen", 0)) > 0 and (attacking or not unit.awakened)
static func extra(unit: Dictionary, frozen: bool) -> bool:
	return snow(unit) and unit.awakened and frozen

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.has("snowRule") and not card.has("craneRule"): return card
	var out := card.duplicate(true)
	var n: int = gs.VerifiedRules.Stun.count(gs, 1 - owner)
	var instant := false
	match str(card.get("snowRule", "")):
		"dance": instant = n > 0
		"country":
			out.value.attack = 7 if n > 0 else 5
			out.value.hp = 7 if n > 0 else 5
			out.effects[0].value = out.value.duplicate(true)
		"weave":
			out.value = int(card.value) + n
			out.effects[0].value = out.value
			out.text += "\n当前眩晕敌方角色：%d；本次 +%d力量。" % [n, int(out.value)]
		"thaw":
			var history := int(gs.player(owner).get("enemyStuns", 0))
			out.value.attack = int(card.value.attack) + history
			out.effects[0].value = out.value.duplicate(true)
			out.text += "\n本局眩晕敌人次数：%d；当前 %d/%d。" % [history, int(out.value.attack), int(out.value.hp)]
	match str(card.get("craneRule", "")):
		"ally-instant": instant = int(inst.get("craneInstantTurn", -1)) == gs.turn_counter
		"ambush": instant = owner != gs.current_player
	if instant and "instant" not in out.keywords: out.keywords.append("instant")
	return out

static func before_attack(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	var growth := int(unit.get("formRules", {}).get("beforeAttackPower", 0))
	if growth > 0:
		unit.cranePower = int(unit.get("cranePower", 0)) + growth
		gs._recalc(unit)
		gs.VerifiedRules.event(gs, "crane-growth", {"player": owner, "uid": unit.uid, "amount": growth})

static func after_attack(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	var attacker: Dictionary = p.units[src]
	if crane(attacker) and not attacker.awakened and int(attacker.hp) > 0:
		attacker.front = 0
		gs.VerifiedRules.event(gs, "unit-moved", {"player": owner, "uid": attacker.uid, "front": 0})
	for inst in p.hand:
		var card: Dictionary = ContentLoader.card_def(inst.definitionId)
		if card.get("craneRule") == "ally-instant" and card.unitId != attacker.id:
			inst.craneInstantTurn = gs.turn_counter
	for idx in p.units.size():
		var unit: Dictionary = p.units[idx]
		if idx != src and int(unit.hp) > 0 and int(unit.level) > 0 and unit.get("formRules", {}).get("swiftAfterAllyAttack", false):
			unit.swift = true
			gs.VerifiedRules.event(gs, "swift-gained", {"player": owner, "uid": unit.uid})

static func spread(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	var amount := int(result.get("dealt", result.damage))
	if not options.get("snowSpread", false) or amount <= 0 or gs.winner >= 0: return
	# Snapshot eligible recipients, then give each one independent damage. The
	# propagated damage is not another combat hit and never recursively spreads.
	var targets: Array = []
	if idx >= 0 and int(gs.player(victim).get("avatarFrozen", 0)) > 0: targets.append(-1)
	for i in gs.player(victim).units.size():
		var unit: Dictionary = gs.player(victim).units[i]
		if i != idx and int(unit.hp) > 0 and int(unit.frozen) > 0: targets.append(i)
	for i in targets:
		if gs.winner >= 0: break
		var damage: int = gs._damage_avatar(victim, amount, owner, src) if i < 0 else int(gs._damage_unit(victim, i, amount, owner, src).damage)
		gs.VerifiedRules.event(gs, "snow-spread", {"player": owner, "uid": gs.player(owner).units[src].uid, "victimPlayer": victim, "target": "" if i < 0 else gs.player(victim).units[i].uid, "amount": damage, "blocked": damage == 0, "card": options.get("combatCard", {})})

static func resolve_action(gs, owner: int, src: int, effect: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"snow-stun-front":
			var idx: int = gs.front_index(1 - owner)
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx)
		"snow-stun-empty-avatar":
			if gs.front_index(1 - owner) < 0: gs.VerifiedRules.Stun.apply(gs, 1 - owner, -1)
		_: return false
	return true

static func end_turn(gs, owner: int) -> void:
	if gs.front_index(owner) >= 0: return
	# Each card responds to the same turn-end event at most once. Re-check the
	# front, source and resources after each attack; the first uses instant.
	var limit: int = gs.player(1 - owner).hand.size()
	for i in limit:
		if gs.winner >= 0 or gs.front_index(owner) >= 0: break
		if not gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-empty-turn-end", null, {"kind": "response-complete"}): break
		gs._resolve_resolution_stack()

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.has("snowRule") and not card.has("craneRule"): return null
	var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	if card.type == "form":
		return -100 if unit.get("form", {}).get("cardId") == card.id else 40 + int(card.value.attack) + int(card.value.hp)
	if card.type == "spell": return -100 if unit.awakened else 72
	if card.get("craneRule") == "ambush" and gs.front_index(1 - owner) >= 0: return 15
	var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
	var score := 50 + int(unit.attack) + int(card.value)
	if not target.is_empty():
		score += 30 if int(target.hp) + int(target.shield) <= int(unit.attack) + int(card.value) else 0
		score -= int(target.attack)
	if card.get("snowRule") == "wind" and gs.front_index(1 - owner) < 0: score += 18
	if card.get("snowRule") == "walk" and gs.front_index(1 - owner) >= 0: score += 20
	if card.get("snowRule") == "spread": score += 12 * gs.VerifiedRules.Stun.count(gs, 1 - owner)
	return score + (12 if gs.effective_card_cost(owner, card) == 0 else 0)
