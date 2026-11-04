class_name WindRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("windCountdown", false) and not unit.get("baseRulesSuppressed", false)

static func active(unit: Dictionary) -> bool:
	return is_source(unit) and int(unit.hp) > 0 and int(unit.level) > 0

static func reduced(gs, owner: int, idx: int, amount: int) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if not active(unit) or not unit.get("formRules", {}).get("windStoredPower", false) or amount <= 0: return
	unit.windStoredPower = int(unit.get("windStoredPower", 0)) + amount
	gs._recalc(unit)
	gs.VerifiedRules.event(gs, "wind-stored-power", {"player": owner, "uid": unit.uid, "amount": amount, "total": unit.windStoredPower})

static func mirror(gs, owner: int, idx: int, amount: int) -> void:
	for src in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[src]
		if src == idx or not is_source(unit) or not unit.awakened or int(unit.level) < 1: continue
		gs.VerifiedRules.reduce_countdown(gs, owner, src, amount)
		gs.VerifiedRules.event(gs, "wind-mirrored-reduction", {"player": owner, "uid": unit.uid, "amount": amount})

static func other_timers(gs, owner: int, source: int) -> int:
	var count := 0
	for i in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[i]
		if i != source and int(unit.hp) > 0 and int(unit.level) > 0 and not gs.VerifiedRules.Countdown.timer(unit).is_empty(): count += 1
	return count

static func total_timers(gs, owner: int) -> int:
	var count := 0
	for unit in gs.player(owner).units:
		count += int(unit.knockout) if int(unit.hp) <= 0 else int(gs.VerifiedRules.Countdown.timer(unit).get("remaining", 0))
	return count

static func after_attack(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.has("windStoredPower"):
		unit.erase("windStoredPower")
		gs._recalc(unit)

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("windOrdinaryPower", 0))
	unit.erase("windOrdinaryPower")
	unit.erase("windStoredPower")

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("windRules", false): return card
	var view := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	if card.get("effect") == "wind-burst":
		var amount := 2 + other_timers(gs, owner, src)
		view.text += "\n当前倒计时减少%d。" % amount
	if card.get("effect") == "wind-storm": view.text += "\n当前倒计时总和%d。" % total_timers(gs, owner)
	return view

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"wind-countdown-attack":
			if not active(unit): return true
			var form: Dictionary = unit.get("formRules", {})
			if form.get("windPermanentGrowth", false):
				unit.permanentAttack = int(unit.get("permanentAttack", 0)) + 1
				unit.windPermanentHp = int(unit.get("windPermanentHp", 0)) + 1
				gs._grow_unit(unit, 0, 1)
			if form.get("windTriggerArmor", false): gs._grant_unit_armor(unit, 4)
			if int(unit.frozen) == 0:
				gs._record("assault", {"unit": src, "bonus": 0, "automatic": true}, owner)
				gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"immuneCombat": bool(unit.awakened), "unyielding": not unit.awakened, "lethal": bool(form.get("windTriggerLethal", false))})
		"wind-quick":
			var count := 2 if card.get("windResponded", false) else 1
			for i in count: gs.resolution_stack.append({"kind": "countdown-change", "playerIndex": owner, "sourceIndex": src, "delta": -2, "cardOwner": owner})
		"wind-burst":
			var amount := 2 + other_timers(gs, owner, src)
			var remaining := int(gs.VerifiedRules.Countdown.timer(unit).get("remaining", 0))
			var excess := maxi(0, amount - remaining)
			gs.VerifiedRules.reduce_countdown(gs, owner, src, amount, owner)
			if excess > 0:
				gs._grow_unit(unit, excess, 0)
				unit.windOrdinaryPower = int(unit.get("windOrdinaryPower", 0)) + excess
				gs._grant_unit_armor(unit, excess)
		"wind-storm":
			gs.resolution_stack.append({"kind": "wind-storm-step", "playerIndex": owner, "sourceIndex": src, "remaining": 1 + total_timers(gs, owner)})
		"wind-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			unit.abilityCountdown.mode = "wind-awakened"
			gs._grow_unit(unit, 1, 1)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "wind-storm-step": return false
	if int(frame.remaining) <= 0 or gs.winner >= 0: return true
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	frame.remaining = int(frame.remaining) - 1
	if int(frame.remaining) > 0: gs.resolution_stack.append(frame)
	gs.VerifiedRules.reduce_countdown(gs, owner, src, 1, owner)
	return true

static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("windRules", false): return null
	var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	match str(card.effect):
		"wind-awaken": return 90 if not unit.awakened else -100
		"wind-storm": return 75 + total_timers(gs, owner) * 3
		"wind-burst", "wind-quick": return 65
		"form": return 60 if unit.get("form", {}).get("cardId") != card.id else -100
	return null
