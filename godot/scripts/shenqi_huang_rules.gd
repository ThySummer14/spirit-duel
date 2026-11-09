extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")

const ID := "shenqi-huang"
const TRACK := "shenqi-track"
const HEART := "shenqi-heart"

static func active(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("shenqiHuang", false) and int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func meteors(unit: Dictionary) -> int:
	return int(unit.get("shenqiMeteors", 0))

static func swift(gs, unit: Dictionary) -> bool:
	return active(unit) and int(unit.get("shenqiSwiftTurn", -1)) == gs.turn_counter

static func attach(gs, owner: int, src: int, amount: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.hp) <= 0 or unit.get("removed", false) or unit.get("baseRulesSuppressed", false): return
	var before := meteors(unit)
	var after := before + amount
	if not unit.get("awakened", false) or not active(unit): after = mini(after, 3)
	if after <= before: return
	unit.shenqiMeteors = after
	for realm in gs.player(owner).realms:
		if not active(unit) or realm.get("nativeRealm", "") != HEART or int(realm.hp) <= 0 or int(realm.get("shenqiSwiftUsedTurn", -1)) == gs.turn_counter: continue
		realm.shenqiSwiftUsedTurn = gs.turn_counter
		unit.shenqiSwiftTurn = gs.turn_counter
		gs.VerifiedRules.event(gs, "swift-gained", {"player": owner, "uid": unit.uid})
	gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": unit.uid, "charm": "陨星", "amount": after - before, "count": after})

static func remove(gs, owner: int, src: int, limit: int) -> int:
	var unit: Dictionary = gs.player(owner).units[src]
	var count := mini(meteors(unit), limit)
	if count == 0: return 0
	unit.shenqiMeteors = meteors(unit) - count
	gs.VerifiedRules.event(gs, "shenqi-meteor-removed", {"player": owner, "uid": unit.uid, "count": count})
	return count

static func knocked_out(unit: Dictionary) -> void:
	unit.erase("shenqiMeteors")
	unit.erase("shenqiSwiftTurn")
	unit.erase("shenqiCritTurn")

static func unit_turn_start(gs, owner: int, src: int) -> void:
	if active(gs.player(owner).units[src]): attach(gs, owner, src, 1)

static func form_turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.hp) > 0 and unit.get("formRules", {}).get("shenqiConstellation", false):
		_queue_reveal(gs, owner)

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	match str(card.get("shenqiMode", "")):
		"fall":
			var amount := remove(gs, owner, src, 3)
			if amount == 0: return
			var unit: Dictionary = gs.player(owner).units[src]
			gs.VerifiedRules.Glutton.record_permanent(unit, amount, amount)
			gs._grow_unit(unit, amount, amount)
		"constellation":
			_queue_reveal(gs, owner)

static func _queue_reveal(gs, owner: int, draw: bool = false) -> void:
	gs.resolution_stack.append({"kind": "shenqi-reveal", "playerIndex": owner, "draw": draw})

static func realm_entered(gs, owner: int, realm: Dictionary) -> void:
	if realm.nativeRealm == TRACK: _queue_reveal(gs, owner)
	if realm.nativeRealm == HEART:
		var src: int = gs._source_index(owner, {"unitId": ID})
		if src >= 0: gs._awaken(owner, src, Content.card_def(str(realm.cardId)), {"attack": 0, "hp": 0})

static func _copy_to_bottom(gs, owner: int, card: Dictionary) -> void:
	var original: Dictionary = card.get("playedInstance", {})
	var definition_id := str(original.get("definitionId", card.id))
	for i in 2:
		var copied: Dictionary = original.duplicate(true)
		var fresh: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, definition_id)
		copied.merge(fresh, true)
		gs.player(owner).deck.push_front(copied)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, _effect: Dictionary, target_id) -> bool:
	match str(card.get("shenqiMode", "")):
		"combat":
			var immune := remove(gs, owner, src, 1) > 0
			gs._record("assault", {"unit": src, "target": target_id, "bonus": 2}, owner)
			gs._resolve_combat(owner, src, 2, false, false, false, false, target_id, false, {"immuneCombat": immune, "combatCard": card})
		"fate":
			Fate.offer(gs, owner, owner, {"kind": "shenqi-reveal", "playerIndex": owner, "draw": true})
		"prophecy":
			gs.resolution_stack.append({"kind": "shenqi-prophecy", "playerIndex": owner, "card": card})
			attach(gs, owner, src, 2)
		"barrage":
			var packets := 6 + 2 * remove(gs, owner, src, 5)
			var context: Dictionary = gs._card_effect_context.duplicate(true)
			for i in packets:
				gs.resolution_stack.append({"kind": "shenqi-barrage-packet", "playerIndex": owner, "sourceIndex": src, "context": context})
		_: return false
	return true

static func revealed(gs, details: Dictionary) -> void:
	var owner := int(details.player)
	var src: int = gs._source_index(owner, {"unitId": ID})
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	var card: Dictionary = details.card
	var category := "other"
	if Content.is_spell(card): category = "spell"
	elif card.get("type") == "combat": category = "combat"
	var frame := {"kind": "shenqi-constellation", "playerIndex": owner, "sourceIndex": src, "category": category}
	if owner == gs.current_player and int(unit.hp) > 0 and unit.get("formRules", {}).get("shenqiConstellation", false):
		var used: Dictionary = unit.get("shenqiConstellationUsed", {})
		if int(used.get(category, -1)) != gs.turn_counter:
			used[category] = gs.turn_counter
			unit.shenqiConstellationUsed = used
			gs.resolution_stack.append(frame)
	for realm in gs.player(owner).realms.duplicate():
		if realm.get("nativeRealm", "") == TRACK and int(realm.hp) > 0:
			gs.resolution_stack.append({"kind": "shenqi-track-trigger", "playerIndex": owner, "sourceIndex": src, "matches": card.get("unitId") == ID})

static func _random_hit(gs, owner: int, src: int, amount: int) -> void:
	var victim := 1 - owner
	var foes: Array = ["avatar-%d" % victim]
	for unit in gs.player(victim).units:
		if int(unit.hp) > 0 and not unit.get("removed", false): foes.append(unit.uid)
	var target = foes[int(gs.randf01() * foes.size())]
	gs.VerifiedRules.DragonFlow.hit(gs, owner, src, target, amount)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	var src := int(frame.get("sourceIndex", -1))
	match frame.get("kind"):
		"shenqi-reveal":
			if frame.draw: gs.resolution_stack.append({"kind": "shenqi-draw", "playerIndex": owner})
			Fate.reveal_top(gs, owner, owner)
		"shenqi-draw":
			gs._draw(owner, 1)
		"shenqi-prophecy":
			_copy_to_bottom(gs, owner, frame.card)
			Fate.offer(gs, owner, owner, {"kind": "shenqi-reveal", "playerIndex": owner, "draw": false})
		"shenqi-track-trigger":
			_random_hit(gs, owner, src, 2)
			if frame.matches and gs.winner < 0:
				gs.resolution_stack.append({"kind": "shenqi-track-attach", "playerIndex": owner, "sourceIndex": src})
				gs._draw(owner, 1)
		"shenqi-track-attach":
			attach(gs, owner, src, 1)
		"shenqi-barrage-packet":
			var old: Dictionary = gs._card_effect_context
			gs._card_effect_context = frame.context
			_random_hit(gs, owner, src, 1)
			gs._card_effect_context = old
		"shenqi-constellation":
			var unit: Dictionary = gs.player(owner).units[src]
			match str(frame.category):
				"spell": unit.shenqiCritTurn = gs.turn_counter
				"combat": gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"immuneCombat": true})
				"other": attach(gs, owner, src, 3)
			gs.VerifiedRules.event(gs, "shenqi-constellation", {"player": owner, "uid": unit.uid, "category": frame.category})
		_: return false
	return true

static func before_attack(gs, frame: Dictionary) -> bool:
	if frame.get("shenqiMeteorResolved", false): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	var amount := meteors(unit)
	if amount <= 0 or not gs.VerifiedRules.Samurai.combat_available(unit, frame.options) or gs.winner >= 0: return false
	frame.shenqiMeteorResolved = true
	var depth: int = gs.resolution_stack.size()
	var crit: bool = int(unit.get("shenqiCritTurn", -1)) == gs.turn_counter
	gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, amount, "陨星", crit)
	gs.VerifiedRules.event(gs, "shenqi-meteor-projectile", {"player": owner, "uid": unit.uid, "amount": amount, "critical": crit})
	if gs.resolution_stack.size() <= depth: return false
	gs.resolution_stack.insert(depth, frame)
	return true

static func score_card(gs, owner: int, card: Dictionary):
	var mode := str(card.get("shenqiMode", ""))
	if mode.is_empty(): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var unit: Dictionary = gs.player(owner).units[src]
	var count := meteors(unit)
	match mode:
		"combat": return 49 + (12 if count > 0 else 0)
		"fate": return -100 if gs.player(owner).deck.is_empty() else 63
		"track": return 61
		"prophecy": return 53 + (10 if count < 3 or unit.awakened else 0)
		"fall": return 45 + 6 * mini(count, 3)
		"heart": return 74 if not unit.awakened else 43
		"barrage": return 50 + 6 * mini(count, 5)
		"constellation": return 73
	return null
