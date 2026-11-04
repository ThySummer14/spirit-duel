class_name UpgradeBlessingRules
extends RefCounted
## 惠比寿的赐福跟随真实升级，不把升级替换为回合开始治疗。
const ContentLoader := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func overlevel_realms(gs, owner: int) -> int:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm") == "ebisu-overlevel" and int(r.hp) > 0).size()

static func can_raise(gs, owner: int, unit: Dictionary) -> bool:
	return not unit.get("summoned", false) and not unit.get("removed", false) and (int(unit.level) < int(gs.rules.maxUnitLevel) or overlevel_realms(gs, owner) > 0)

static func grow(gs, unit: Dictionary, attack: int, hp: int, permanent: bool = false) -> void:
	gs._grow_unit(unit, attack, hp)
	var prefix := "blessingPermanent" if permanent else "blessingGrowth"
	unit[prefix + "Attack"] = int(unit.get(prefix + "Attack", 0)) + attack
	unit[prefix + "Hp"] = int(unit.get(prefix + "Hp", 0)) + hp

static func draw_owned(gs, owner: int, target: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	var indices: Array = []
	for i in p.deck.size():
		if ContentLoader.card_def(str(p.deck[i].definitionId)).get("unitId") == target.id: indices.append(i)
	if indices.is_empty(): return
	var index := int(indices[int(floor(gs.randf01() * indices.size()))])
	var inst: Dictionary = p.deck.pop_at(index)
	inst.blessingInstant = true
	p.hand.append(inst)
	if p.hand.size() > int(gs.rules.maxHandSize): p.hand.pop_back()
	gs.VerifiedRules.event(gs, "blessing-search", {"player": owner, "uid": target.uid, "count": 1})

static func overlevel(gs, owner: int, target: Dictionary) -> void:
	for i in overlevel_realms(gs, owner):
		grow(gs, target, 5, 5, true)
		var cards: Array = ContentLoader.cards_for_unit(str(target.id)).filter(func(c): return int(c.level) == 3 and not c.get("token", false))
		if not cards.is_empty():
			var card: Dictionary = cards[int(floor(gs.randf01() * cards.size()))]
			var p: Dictionary = gs.player(owner)
			p.hand.append({"instanceId": "%s-ebisu-%d" % [p.id, gs.next_card_id], "definitionId": card.id})
			gs.next_card_id += 1
			if p.hand.size() > int(gs.rules.maxHandSize): p.hand.pop_back()
		gs.VerifiedRules.event(gs, "blessing-overlevel", {"player": owner, "uid": target.uid, "attack": 5, "hp": 5})

static func raise_level(gs, owner: int, idx: int, temporary: bool = false) -> bool:
	var target: Dictionary = gs.player(owner).units[idx]
	if not can_raise(gs, owner, target): return false
	var was_alive := int(target.hp) > 0
	var before := int(target.level)
	if before < int(gs.rules.maxUnitLevel):
		target.level = before + 1
		if temporary:
			if not target.has("blessingTempLevels"): target.blessingTempLevels = []
			target.blessingTempLevels.append({"turn": gs.turn_counter, "amount": 1})
	else: overlevel(gs, owner, target)
	gs.VerifiedRules.DogDemon.level_up(gs, owner, idx)
	upgraded(gs, owner, idx, was_alive)
	gs.VerifiedRules.event(gs, "blessing-level-raised", {"player": owner, "uid": target.uid, "before": before, "after": int(target.level), "temporary": temporary})
	gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-upgraded", target.uid, {"kind": "response-complete"})
	return true

static func upgraded(gs, owner: int, idx: int, was_alive: bool = true) -> void:
	var target: Dictionary = gs.player(owner).units[idx]
	if target.get("summoned", false): return
	gs.VerifiedRules.IronMouse.upgraded(gs, owner, idx)
	gs.VerifiedRules.Yitiao.upgraded(gs, owner, idx)
	gs.VerifiedRules.Crocodile.upgraded(gs,owner,idx)
	for src in gs.player(owner).units.size():
		var source: Dictionary = gs.player(owner).units[src]
		if not active(source): continue
		if source.get("formRules", {}).get("blessingRevive", false) and int(target.hp) <= 0:
			gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false)
		if was_alive and ContentLoader.runtime_unit_def(source).get("upgradeBlessing", false):
			var awakened: bool = source.awakened
			grow(gs, target, 1 if awakened else 0, 1)
			if awakened: gs.VerifiedRules.Combat.grant_inspired(gs, owner, idx)
			gs.VerifiedRules.event(gs, "upgrade-blessing", {"player": owner, "uid": target.uid, "source": source.uid, "awakened": awakened})
		if source.get("formRules", {}).get("blessingSearch", false): draw_owned(gs, owner, target)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var enhance: bool = card.get("blessingEnhance", false)
	if not enhance and not inst.get("blessingInstant", false): return card
	var view := card.duplicate(true)
	if enhance:
		view.enhanced = gs.min_level(owner) >= 3
		view.value = 5 if view.enhanced else 1
		view.effects[0].value = view.value
		view.text += "\n当前增益：+%d力量/+%d生命。" % [view.value, view.value]
	if inst.get("blessingInstant", false):
		view.blessingInstant = true
		if not gs._kw(view, "instant"): view.keywords.append("instant")
		view.text += "\n海之惠：此牌获得瞬发。"
		if view.get("originCard") is Dictionary:
			view.originCard.blessingInstant = true
			if not gs._kw(view.originCard, "instant"): view.originCard.keywords.append("instant")
	return view

static func restricted_type(card: Dictionary) -> bool:
	# Some native awakenings are spell cards; their rule action carries the
	# awakening identity even when the printed type remains 法术牌.
	return card.get("type") in ["realm", "form", "awakening"] or card.get("effects", []).any(func(e): return "awaken" in str(e.get("action", "")).split("-"))

static func card_blocked(gs, unit: Dictionary, card: Dictionary) -> bool:
	return int(unit.get("blessingRestrictedTurn", -1)) == gs.turn_counter and restricted_type(card)

static func end_turn(gs) -> void:
	for owner in gs.players.size():
		for unit in gs.player(owner).units:
			var expired := 0
			var retained: Array = []
			for entry in unit.get("blessingTempLevels", []):
				if int(entry.turn) == gs.turn_counter: expired += int(entry.amount)
				else: retained.append(entry)
			if expired > 0:
				unit.level = maxi(0, int(unit.level) - expired)
				gs.VerifiedRules.event(gs, "blessing-level-expired", {"player": owner, "uid": unit.uid, "amount": expired})
			if retained.is_empty(): unit.erase("blessingTempLevels")
			else: unit.blessingTempLevels = retained
			if int(unit.get("blessingRestrictedTurn", -1)) == gs.turn_counter: unit.erase("blessingRestrictedTurn")

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("blessingGrowthAttack", 0))
	unit.maxHpBonus = int(unit.maxHpBonus) - int(unit.get("blessingGrowthHp", 0))
	unit.erase("blessingGrowthAttack")
	unit.erase("blessingGrowthHp")

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("blessingRules", false): return null
	var source: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	match str(card.effect):
		"blessing-omen":
			if gs._unit_index_by_uid(owner, target_id) < 0: return -100
			return 40 + int(card.value) * 8
		"blessing-temporary-level":
			var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
			if int(target.hp) <= 0:
				return 90 if gs.player(owner).units.any(func(u): return active(u) and u.get("formRules", {}).get("blessingRevive", false)) else -100
			if int(target.level) >= 3: return 65
			for h in gs.player(owner).hand.size():
				var follow: Dictionary = gs.hand_card_def(owner, h)
				if follow.unitId == target.id and int(follow.level) == int(target.level) + 1 and not restricted_type(follow) and int(gs.player(owner).energy) >= gs.effective_card_cost(owner, card) + gs.effective_card_cost(owner, follow): return 75
			return -100
		"blessing-wander": return 65
		"realm": return 80 if overlevel_realms(gs, owner) == 0 else 45
		"form":
			if source.get("form", {}).get("cardId") == card.id: return -100
			if card.get("formRules", {}).get("blessingRevive", false):
				return 85 if gs.player(owner).units.any(func(u): return int(u.hp) <= 0 and can_raise(gs, owner, u)) else 20
			return 70
	return null

static func lowest(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return not u.get("summoned", false) and int(u.level) == gs.min_level(owner))

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") == "blessing-temporary-level":
		return gs.player(owner).units.filter(func(u): return str(u.id) != str(card.unitId) and can_raise(gs, owner, u)).map(func(u): return u.uid)
	if not card.get("upgradeBlessingCard", false): return null
	return lowest(gs, owner).map(func(u): return u.uid)

static func resolve_action(gs, owner: int, src: int, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"blessing-omen":
			if not target.is_empty() and int(target.hp) > 0: grow(gs, target, int(effect.value), int(effect.value))
			gs._draw(owner, 1)
			return true
		"blessing-temporary-level":
			if not target.is_empty():
				target.blessingRestrictedTurn = gs.turn_counter
				raise_level(gs, owner, gs._unit_index_by_uid(owner, target.uid), true)
			return true
		"blessing-wander":
			gs.resolution_stack.append({"kind": "blessing-wander-step", "playerIndex": owner, "remaining": 2})
			return true
	if effect.get("action") == "upgrade-blessing-level":
		if target.is_empty() or not lowest(gs, owner).has(target): return true
		# Continue only after the first upgrade's automatic responses finish.
		gs.resolution_stack.append({"kind": "blessing-level-enemy", "playerIndex": owner})
		gs.raise_unit_level(owner, gs._unit_index_by_uid(owner, target.uid))
		return true
	if effect.get("action") != "upgrade-blessing-awaken": return false
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.awakened: return true
	unit.awakened = true
	unit.passive_hooks = []
	gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") == "blessing-wander-step":
		var owner := int(frame.playerIndex)
		if int(frame.remaining) <= 0: return true
		var pool := lowest(gs, owner)
		if pool.is_empty(): return true
		var chosen: Dictionary = pool[int(floor(gs.randf01() * pool.size()))]
		gs.resolution_stack.append({"kind": "blessing-wander-step", "playerIndex": owner, "remaining": int(frame.remaining) - 1})
		raise_level(gs, owner, gs._unit_index_by_uid(owner, chosen.uid))
		return true
	if frame.get("kind") not in ["blessing-level-enemy", "blessing-level-draw"]: return false
	var owner := int(frame.playerIndex)
	if frame.kind == "blessing-level-draw":
		gs._draw(owner, 1)
		return true
	gs.resolution_stack.append({"kind": "blessing-level-draw", "playerIndex": owner})
	var enemies := lowest(gs, 1 - owner)
	if not enemies.is_empty():
		var chosen: Dictionary = enemies[int(floor(gs.randf01() * enemies.size()))]
		gs.raise_unit_level(1 - owner, gs._unit_index_by_uid(1 - owner, chosen.uid))
	return true
