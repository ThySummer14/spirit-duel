class_name NightRealmRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("nightRealm", false) and not unit.get("baseRulesSuppressed", false)

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func power(gs, unit: Dictionary) -> int:
	if not active(unit) or not is_source(unit): return 0
	for owner in gs.players.size():
		if gs._unit_index_by_uid(owner, unit.uid) >= 0:
			var count: int = gs.player(owner).realms.filter(func(r): return int(r.hp) > 0).size()
			return count if unit.awakened else mini(1, count)
	return 0

static func refresh(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if is_source(unit): gs._recalc(unit)

static func first_strike(gs, unit: Dictionary) -> bool:
	return active(unit) and is_source(unit) and unit.awakened and power(gs, unit) > 0

static func cover(gs, owner: int, idx: int, combat: bool) -> Dictionary:
	var p: Dictionary = gs.player(owner)
	var target: Dictionary = p.units[idx]
	var all_units: bool = p.units.any(func(u): return active(u) and u.get("formRules", {}).get("nightCoverAll", false))
	if not all_units and not (active(target) and is_source(target)): return {}
	for realm in p.realms:
		if int(realm.hp) > 0 and realm.get("nativeRealm") == ("night-sun" if combat else "night-moon"): return realm
	return {}

static func group(gs, card: Dictionary, effect: Dictionary) -> Dictionary:
	var area: bool = effect.get("target", "") in ["all-enemy-units", "all-enemies", "all-ally-units", "all-units"] or effect.get("action") in ["tide-wave", "mountain-collapse", "river-song"] or card.get("phoenixArea", false)
	if not area: return {}
	var protected := {}
	for owner in gs.players.size():
		for idx in gs.player(owner).units.size():
			if int(gs.player(owner).units[idx].hp) <= 0: continue
			var realm := cover(gs, owner, idx, false)
			if not realm.is_empty(): protected[str(gs.player(owner).units[idx].uid)] = {"owner": owner, "realm": realm}
	return {} if protected.is_empty() else {"protected": protected, "losses": {}}

static func lose(gs, owner: int, realm: Dictionary, amount: int) -> void:
	if amount <= 0 or not gs.player(owner).realms.has(realm): return
	realm.hp = maxi(0, int(realm.hp) - amount)
	gs.VerifiedRules.event(gs, "realm-durability", {"player": owner, "realm": realm.uid, "amount": amount, "remaining": realm.hp})
	if int(realm.hp) == 0: gs.VerifiedRules.Huang.destroy(gs, owner, realm, "承受伤害后破碎")

static func finish_group(gs, damage_group: Dictionary) -> void:
	for entry in damage_group.get("losses", {}).values(): lose(gs, int(entry.owner), entry.realm, int(entry.amount))

static func defer_avatar_realm_damage(gs, owner: int, amount: int) -> bool:
	var batch: Dictionary = gs._night_damage_group
	var realms: Array = gs.player(owner).realms
	if batch.is_empty() or realms.is_empty() or amount <= 0: return false
	var realm: Dictionary = realms[0]
	if not batch.protected.values().any(func(e): return e.realm.uid == realm.uid): return false
	var key := str(realm.uid)
	var entry: Dictionary = batch.losses.get(key, {"owner": owner, "realm": realm, "amount": 0})
	entry.amount = maxi(amount, int(entry.amount))
	batch.losses[key] = entry
	return true

static func replace_damage(gs, owner: int, idx: int, amount: int, combat: bool) -> bool:
	if amount <= 0: return false
	var uid := str(gs.player(owner).units[idx].uid)
	var batch: Dictionary = gs._night_damage_group
	var realm: Dictionary = {}
	if not combat and batch.get("protected", {}).has(uid):
		realm = batch.protected[uid].realm
		var key := str(realm.uid)
		var previous: Dictionary = batch.losses.get(key, {"owner": owner, "realm": realm, "amount": 0})
		previous.amount = maxi(int(previous.amount), amount)
		batch.losses[key] = previous
	else:
		realm = cover(gs, owner, idx, combat)
		if not realm.is_empty(): lose(gs, owner, realm, amount)
	if realm.is_empty(): return false
	gs.VerifiedRules.event(gs, "night-damage-replaced", {"player": owner, "uid": uid, "realm": realm.uid, "amount": amount, "combat": combat})
	return true

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("nightRules", false): return card
	var out := card.duplicate(true)
	if card.get("nightInstant", false) and not gs.player(owner).realms.is_empty():
		out.keywords.append("instant")
		out.text += "\n已有幻境：获得瞬发。"
	return out

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"night-summon-choice":
			gs.pending_choice = {"type": "night-summon", "playerIndex": owner, "sourceIndex": src, "instanceIds": ["c17703", "c17704"], "heading": "残 阳 无 影", "title": "选择要召唤的幻境", "hint": "新月之哀抵挡非战斗伤害；日轮之城抵挡战斗伤害。"}
			gs.phase = "choice"
		"night-awaken": gs._awaken(owner, src, card, {"attack": 0, "hp": 1})
		"night-both-realms":
			for id in ["c17703", "c17704"]: gs._deploy_realm(owner, ContentLoader.card_def(id))
		_: return false
	return true

static func choice_card(gs, _owner: int, iid: String):
	return ContentLoader.card_def(iid) if gs.pending_choice.get("type") == "night-summon" else null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "night-summon" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	gs._record("resolve_divination_choice", {"instanceId": iid, "card": iid, "choice": "night-summon"}, owner)
	gs.pending_choice = {}
	gs.phase = "main"
	gs._deploy_realm(owner, ContentLoader.card_def(iid))
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "night-summon": return null
	return resolve_choice(gs, owner, "c17703" if gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "night-sun") else "c17704")

static func combat_dealt(gs, owner: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if owner == victim or idx >= 0 or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	if options.get("nightRealmGrow", false):
		for realm in gs.player(owner).realms.duplicate():
			if str(realm.get("nativeRealm", "")).begins_with("night-"): gs.VerifiedRules.Huang.gain(gs, owner, realm, 3)
	if options.get("nightDestroyRealm", false):
		var pool: Array = gs.player(victim).realms.filter(func(r): return int(r.hp) > 0)
		if pool.is_empty(): return
		var highest := 0
		for realm in pool: highest = maxi(highest, int(realm.hp))
		pool = pool.filter(func(r): return int(r.hp) == highest)
		gs.VerifiedRules.Huang.destroy(gs, victim, pool[int(floor(gs.randf01() * pool.size()))], "月之奥义消灭")

static func after_attack(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.get("nightRepeat", false) or not active(gs.player(owner).units[src]) or int(gs.player(owner).units[src].frozen) > 0 or gs.player(owner).realms.is_empty(): return
	var pool: Array = gs.player(owner).realms.duplicate()
	gs.VerifiedRules.Huang.destroy(gs, owner, pool[int(floor(gs.randf01() * pool.size()))], "胧月无眠消灭")
	var card: Dictionary = options.combatCard.duplicate(true)
	gs.player(owner).cardsPlayedThisTurn = int(gs.player(owner).cardsPlayedThisTurn) + 1
	gs.VerifiedRules.event(gs, "automatic-card", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": card, "reason": "胧月无眠再次使用"})
	gs._push_card_frames(owner, str(card.id), null, card, src, gs.MAX_RESPONSE_DEPTH)

static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("nightRules", false): return null
	var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
	if card.effect == "night-awaken": return 85 if not unit.awakened else -100
	if card.type == "form": return 80 if unit.get("form", {}).get("cardId") != card.id else -100
	if card.type == "realm": return 55 if not gs.player(owner).realms.any(func(r): return r.cardId == card.id) else 20
	return 55 + gs.player(owner).realms.size() * 8
