extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const ID := "himiko"
const ECLIPSE := "himiko-eclipse"
const CONQUEST := "w13-himiko-93159"
const GAP := "himiko-gap"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func active(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("himikoRules", false) and int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func extra_instant(gs, owner: int) -> bool:
	var idx := source(gs, owner)
	if idx < 0: return false
	var unit: Dictionary = gs.player(owner).units[idx]
	return active(unit) and unit.awakened

static func _gap_realms(gs, owner: int) -> Array:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm", "") == GAP and int(r.hp) > 0)

static func has_realm_instant(gs, owner: int, card: Dictionary) -> bool:
	if card.is_empty(): return false
	var idx: int = gs._source_index(owner, card)
	if idx < 0: return false
	var uid: String = gs.player(owner).units[idx].uid
	for side in gs.players.size():
		if _gap_realms(gs, side).any(func(r): return r.get("himikoTarget") == uid): return true
	return false

static func describe(gs, owner: int, instance: Dictionary, card: Dictionary) -> Dictionary:
	var realm_instant := has_realm_instant(gs, owner, card)
	var conquest_instant: bool = instance.get("himikoConquestInstant", false)
	if not realm_instant and not conquest_instant: return card
	var view := card.duplicate(true)
	if not gs._kw(view, "instant"): view.keywords.append("instant")
	if conquest_instant and not instance.get("himikoConquestBounced", false):
		view.keywords.append("bounce")
		view.himikoBounce = true
	return view

static func valid_gap_target(gs, owner: int, target_id) -> bool:
	for side in gs.players.size():
		var idx: int = gs._unit_index_by_uid(side, target_id)
		if idx < 0: continue
		var unit: Dictionary = gs.player(side).units[idx]
		return int(unit.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(unit) and (side == owner or (not gs.VerifiedRules.Combat.has(unit, "veil") and not gs.VerifiedRules.Movement.has_veil(unit)))
	return false

static func announced(gs, frame: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var caster := int(frame.sourceIndex)
	if caster < 0: return
	var paid := int(frame.get("paidFire", -1))
	if paid < 0 and frame.get("automatic", false): paid = 0
	if paid != 0: return
	var used_from_hand: bool = frame.get("usedFromHand", false)
	var src := source(gs, owner)
	if src >= 0:
		var unit: Dictionary = gs.player(owner).units[src]
		if active(unit):
			if unit.get("formRules", {}).get("himikoGlory", false):
				gs._apply_encourage(owner, 0, 1, 1)
				if int(unit.get("himikoGloryTurn", -1)) != gs.turn_counter:
					unit.himikoGloryTurn = gs.turn_counter
					gs.player(owner).attackUsed = false
			if used_from_hand and frame.get("definitionId") != ECLIPSE:
				projectile(gs, owner, src)
	if not used_from_hand: return
	for realm in _gap_realms(gs, owner):
		for side in gs.players.size():
			var idx: int = gs._unit_index_by_uid(side, realm.get("himikoTarget", ""))
			if idx < 0: continue
			var unit: Dictionary = gs.player(side).units[idx]
			if int(unit.hp) > 0:
				gs.VerifiedRules.HairPower.give(gs, side, idx, 1)
				gs._grant_unit_armor(unit, 1)
			break
		realm.hp = int(realm.hp) - 2
		gs.VerifiedRules.event(gs, "realm-durability", {"player": owner, "realm": realm.uid, "amount": 2, "remaining": maxi(0, int(realm.hp))})
		if int(realm.hp) <= 0: gs.VerifiedRules.Huang.destroy(gs, owner, realm, "时间之隙结束")

static func projectile(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	gs.resolution_stack.append({"kind": "himiko-projectile", "playerIndex": owner, "sourceIndex": src, "amount": 1 + int(unit.get("himikoEclipseBonus", 0))})

static func revealed(gs, details: Dictionary) -> void:
	var card: Dictionary = details.card
	if card.get("id") != CONQUEST: return
	var owner := int(details.deckPlayer)
	var deck: Array = gs.player(owner).deck
	for i in deck.size():
		if deck[i].instanceId != details.instanceId: continue
		var instance: Dictionary = deck.pop_at(i)
		instance.himikoConquestInstant = true
		instance.erase("himikoConquestBounced")
		gs.VerifiedRules.Baize.put_hand(gs, owner, instance)
		gs.VerifiedRules.event(gs, "himiko-conquest-recovered", {"player": owner, "card": card, "instanceId": instance.instanceId})
		return

static func completed(gs, owner: int, card: Dictionary, frame: Dictionary) -> void:
	if card.get("id") == ECLIPSE and frame.get("usedFromHand", false) and int(frame.get("paidFire", -1)) == 0:
		var src := int(frame.sourceIndex)
		if active(gs.player(owner).units[src]): projectile(gs, owner, src)
	if not card.get("himikoBounce", false): return
	var instance: Dictionary = card.get("playedInstance", {}).duplicate(true)
	if instance.is_empty(): return
	instance.himikoConquestBounced = true
	gs.VerifiedRules.Baize.put_hand(gs, owner, instance)

static func _collectible(card: Dictionary) -> bool:
	return not card.get("token", false) and not card.get("skin", false) and int(card.get("deckLimit", 0)) > 0

static func _specialty_pool(gs, owner: int) -> Array:
	var pool: Array = []
	for unit in gs.player(owner).units:
		if unit.get("summoned", false) or unit.get("removed", false): continue
		for card in Content.cards_for_unit(str(unit.id)):
			if _collectible(card): pool.append(card.id)
	return pool

static func _queen(gs, owner: int) -> void:
	var pool: Array = []
	for card in Content.load_content().cards:
		if not _collectible(card) or card.get("type") == "awakening" or str(card.get("name", "")).begins_with("觉醒"): continue
		if gs.VerifiedRules.Factions.printed({"id": card.unitId}).is_empty(): continue
		if gs._kw(card, "instant"): pool.append(card.id)
	for id in Choice.sample(gs, pool, 3): Choice.give(gs, owner, str(id))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.get("action", "")):
		"himiko-revive":
			Fate.offer(gs, owner, owner, {"kind": "himiko-reveal", "playerIndex": owner, "sourceIndex": src, "deckPlayer": owner})
		"himiko-knockout":
			Fate.offer(gs, owner, 1 - owner, {"kind": "himiko-reveal", "playerIndex": owner, "sourceIndex": src, "deckPlayer": 1 - owner})
		"himiko-gap":
			if not valid_gap_target(gs, owner, target_id): return true
			gs._deploy_realm(owner, card)
			gs.player(owner).realms.back().himikoTarget = target_id
		"himiko-remote":
			gs._apply_encourage(owner, 0, 1, 1)
			gs._record("assault", {"unit": src, "target": target_id, "bonus": 0}, owner)
			gs._resolve_combat(owner, src, 0, false, true, false, false, target_id, false, {"combatCard": card})
		"himiko-awaken":
			Choice.give(gs, owner, ECLIPSE)
			var unit: Dictionary = gs.player(owner).units[src]
			if unit.awakened:
				gs.VerifiedRules.Glutton.record_permanent(unit, 1, 1, true)
				gs._grow_unit(unit, 1, 1)
			else: gs._awaken(owner, src, card, effect.value)
		"himiko-queen":
			_queen(gs, owner)
		"himiko-conquest":
			for target in Choice.live_units(gs, 1 - owner):
				gs._damage_unit(1 - owner, gs._unit_index_by_uid(1 - owner, target.uid), 2, owner, src)
		"himiko-eclipse":
			for id in Choice.sample(gs, _specialty_pool(gs, owner), 1): Choice.give(gs, owner, str(id))
			var unit: Dictionary = gs.player(owner).units[src]
			unit.himikoEclipseBonus = int(unit.get("himikoEclipseBonus", 0)) + 1
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	var src := int(frame.get("sourceIndex", -1))
	match str(frame.get("kind", "")):
		"himiko-projectile":
			gs.VerifiedRules.base_damage_projectile(gs, owner, src, int(frame.amount), "卑弥呼投射")
		"himiko-reveal":
			var deck_owner := int(frame.deckPlayer)
			var deck: Array = gs.player(deck_owner).deck
			if not deck.is_empty():
				var card := Content.card_def(str(deck.back().definitionId))
				var target_idx: int = gs._source_index(deck_owner, card)
				if target_idx >= 0:
					gs.resolution_stack.append({"kind": "himiko-time-effect", "playerIndex": owner, "sourceIndex": src, "deckPlayer": deck_owner, "targetIndex": target_idx})
				Fate.reveal_top(gs, owner, deck_owner)
		"himiko-time-effect":
			var deck_owner := int(frame.deckPlayer)
			var unit: Dictionary = gs.player(deck_owner).units[int(frame.targetIndex)]
			if owner == deck_owner: gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
			else:
				if int(unit.hp) > 0: gs._knockout_unit(unit, owner, src)
				if int(unit.hp) <= 0 and not unit.get("removed", false):
					unit.knockout = 2
					gs.VerifiedRules.event(gs, "himiko-countdown-set", {"player": owner, "uid": unit.uid, "remaining": 2})
		_: return false
	return true

static func _fate_score(gs, owner: int, deck_owner: int, card: Dictionary) -> int:
	var idx: int = gs._source_index(deck_owner, card)
	if idx < 0: return -1
	var unit: Dictionary = gs.player(deck_owner).units[idx]
	if deck_owner == owner:
		return int(unit.knockout) * 8 + int(unit.level) if gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, unit) else -1
	return 15 + int(unit.level) * 5 + int(unit.attack) if int(unit.hp) > 0 else 2 - int(unit.knockout)

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != Fate.KIND or gs.resolution_stack.is_empty() or gs.resolution_stack.back().get("kind") != "himiko-reveal": return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	var deck_owner := int(gs.pending_choice.deckOwner)
	var top: Dictionary = Fate.choice_card(gs, owner, Fate.FOLLOW)
	var bottom: Dictionary = Fate.choice_card(gs, owner, Fate.REVERSE)
	return Fate.choose(gs, owner, Fate.REVERSE if _fate_score(gs, owner, deck_owner, bottom) > _fate_score(gs, owner, deck_owner, top) else Fate.FOLLOW)

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if card.get("unitId") != ID: return null
	match str(card.get("effect", "")):
		"himiko-revive":
			return 63 if gs.player(owner).units.any(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)) else -10
		"himiko-gap":
			if gs._unit_index_by_uid(owner, target_id) < 0: return -40
			var unit: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
			return 45 + int(unit.level) * 4 + int(unit.attack)
		"himiko-awaken": return 74
		"himiko-knockout": return 69 if not gs.player(1 - owner).deck.is_empty() else -10
		"himiko-queen": return 60
		"himiko-eclipse": return 75
	return null
