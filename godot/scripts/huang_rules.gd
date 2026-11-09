class_name HuangRules
extends RefCounted
## Native realm durability, destruction and hand-instance choices.

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("huangRealmGrowth", false)

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) >= 1 and not unit.get("baseRulesSuppressed", false)

static func gain(gs, owner: int, realm: Dictionary, amount: int) -> void:
	if amount <= 0 or not gs.player(owner).realms.has(realm): return
	var gained := amount + (2 if realm.get("nativeRealm") == "huang-moon" else 0)
	realm.hp = int(realm.hp) + gained
	gs.VerifiedRules.event(gs, "realm-durability-gained", {"player": owner, "realm": realm.uid, "amount": gained, "remaining": realm.hp})
	gs.VerifiedRules.Blueprint.durability(gs, owner, str(realm.uid))

static func combat_dealt(gs, owner: int, src: int, result: Dictionary) -> void:
	if int(result.get("transferredDealt", result.get("dealt", result.get("damage", 0)))) <= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	# An ordinary counterhit can still resolve after simultaneous knockout.
	if not is_source(unit) or int(unit.level) < 1: return
	for realm in gs.player(owner).realms.duplicate(): gain(gs, owner, realm, 1)

static func destroy(gs, owner: int, realm: Dictionary, reason: String, moved: bool = false) -> void:
	var idx: int = gs.player(owner).realms.find(realm)
	if idx < 0: return
	gs.player(owner).realms.remove_at(idx)
	gs.player(owner).blueprintRealmLeftTurn = gs.turn_counter
	if realm.get("nativeRealm") == "peacock-mist": gs.VerifiedRules.DuskCycle.refresh_mist(gs, owner)
	gs.VerifiedRules.Night.refresh(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	gs._log("幻境「%s」%s。" % [realm.name, reason], gs.TONE_CARD)
	var card := ContentLoader.card_def(str(realm.cardId))
	gs.VerifiedRules.event(gs, "realm-moved" if moved else "realm-destroyed", {"player": owner, "realm": realm.uid, "card": gs.VerifiedRules.Langya.realm_card(realm, card), "reason": reason, "nativeRealm": realm.get("nativeRealm", "")})
	gs.VerifiedRules.Langya.realm_destroyed(gs, owner, realm)
	gs.VerifiedRules.TwinSight.realm_left(gs, owner, realm)
	gs.VerifiedRules.PeachGrove.realm_left(gs, owner, realm)
	if realm.get("nativeRealm") == "travel-mist": gs.VerifiedRules.DragonAbyss.Travel.refresh_mist(gs, owner)
	if realm.get("nativeRealm") == "treasure-vault": gs.VerifiedRules.Treasure.realm_trigger(gs, owner)
	if moved: return
	gs.VerifiedRules.StarShopCards.realm_destroyed(gs, owner, realm)
	gs.VerifiedRules.Mountain.realm_destroyed(gs,owner,realm,reason)
	if not realm.get("returnOnDestroy", false): return
	var inst: Dictionary = realm.returnInstance.duplicate(true)
	inst.huangSeaReturned = true
	gs.player(owner).hand.append(inst)
	if gs.player(owner).hand.size() > int(gs.rules.maxHandSize):
		gs.player(owner).hand.pop_back()
		gs._log("手牌已满，回手的「%s」被烧毁。" % realm.name, gs.TONE_DANGER)
	else:
		gs._log("「%s」回到手牌，并失去再次回手的能力。" % realm.name, gs.TONE_CARD)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("huangRules", false): return card
	var view := card.duplicate(true)
	if view.get("huangBody", false):
		var count: int = gs.player(owner).realms.size()
		view.value.attack = 5 + count
		view.value.hp = 5 + count
		view.effects[0].value = view.value.duplicate()
		view.text += "\n当前幻境%d：%d力量/%d生命。" % [count, 5 + count, 5 + count]
	if view.get("realm", {}).get("nativeRealm") == "huang-sea":
		view.realm.returnOnDestroy = not inst.get("huangSeaReturned", false)
		view.realm.returnInstance = inst.duplicate(true)
		if inst.get("huangSeaReturned", false): view.text = "瞬发。\n此副本已失去回手能力。"
	return view

static func discard_options(gs, owner: int) -> Array:
	var ids: Array = []
	for inst in gs.player(owner).hand:
		if ContentLoader.card_def(str(inst.definitionId)).get("type") == "realm": ids.append(str(inst.instanceId))
	return ids

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect") != "huang-discard-draw" or not discard_options(gs, owner).is_empty()

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "huang-discard" or int(choice.playerIndex) != owner or not choice.instanceIds.has(iid): return false
	var idx: int = gs.player(owner).hand.find_custom(func(i): return str(i.instanceId) == iid)
	if idx < 0 or ContentLoader.card_def(str(gs.player(owner).hand[idx].definitionId)).get("type") != "realm": return false
	var inst: Dictionary = gs.discard_hand_card(owner, idx)
	gs._record("resolve_divination_choice", {"instanceId": iid, "card": inst.definitionId, "choice": "huang-discard"}, owner)
	gs._log("余辉弃掉「%s」。" % ContentLoader.card_def(str(inst.definitionId)).name, gs.TONE_CARD)
	gs.pending_choice = {}
	gs.phase = "main"
	gs._draw(owner, 3)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int) -> Variant:
	if gs.pending_choice.get("type") != "huang-discard": return null
	var best := ""
	var score := 999999
	for iid in gs.pending_choice.instanceIds:
		for inst in gs.player(owner).hand:
			if str(inst.instanceId) != str(iid): continue
			var card := ContentLoader.card_def(str(inst.definitionId))
			var value := int(card.get("level", 1)) * 10 + (20 if card.get("rarity") == "ssr" else 0)
			if inst.get("huangSeaReturned", false): value -= 10
			if value < score: score = value; best = str(iid)
	return false if best.is_empty() else gs.resolve_divination_choice(owner, best)

static func choice_card(gs, owner: int, iid: String) -> Variant:
	if gs.pending_choice.get("type") != "huang-discard": return null
	for i in gs.player(owner).hand.size():
		if str(gs.player(owner).hand[i].instanceId) == iid: return gs.hand_card_def(owner, i)
	return {}

static func resolve_action(gs, owner: int, src: int, _card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"huang-discard-draw":
			var ids := discard_options(gs, owner)
			if not ids.is_empty():
				gs.pending_choice = {"type": "huang-discard", "playerIndex": owner, "zone": "hand", "instanceIds": ids, "heading": "余 辉", "hint": "弃一张幻境手牌，然后从牌库抽三张牌"}
				gs.phase = "choice"
		"huang-awaken": gs._awaken(owner, src, _card, effect.value)
		_: return false
	return true

static func announced(gs, owner: int, card: Dictionary) -> void:
	if card.get("type") != "realm": return
	for src in range(gs.player(owner).units.size() - 1, -1, -1):
		var unit: Dictionary = gs.player(owner).units[src]
		if not active(unit): continue
		if is_source(unit) and unit.awakened:
			unit.swift = true
			gs.VerifiedRules.event(gs, "swift-gained", {"player": owner, "uid": unit.uid})
		if unit.get("formRules", {}).get("huangSpiral", false):
			gs.resolution_stack.append({"kind": "huang-spiral", "playerIndex": owner, "sourceIndex": src})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "huang-spiral": return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit) and int(unit.frozen) == 0:
		gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"immuneCombat": true})
	return true

static func _hit(gs, owner: int, src: int, idx: int, amount: int, realm: Dictionary) -> void:
	var actual: int
	var transferred := false
	if idx < 0: actual = gs._damage_avatar(1 - owner, amount, owner, src)
	else:
		var hit: Dictionary = gs._damage_unit(1 - owner, idx, amount, owner, src)
		transferred = hit.has("transferredDealt")
		actual = int(hit.get("transferredDealt", hit.get("damage", 0)))
	gs.VerifiedRules.event(gs, "realm-damage-resolved", {"player": owner, "uid": "" if src < 0 else gs.player(owner).units[src].uid, "target": "" if idx < 0 or transferred else gs.player(1 - owner).units[idx].uid, "victimPlayer": 1 - owner, "amount": actual, "blocked": actual == 0, "card": ContentLoader.card_def(str(realm.cardId))})

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	var mode := str(realm.get("nativeRealm", ""))
	if not mode.begins_with("huang-"): return false
	if mode == "huang-sea": return true
	var src: int = gs._source_index(owner, {"unitId": realm.sourceUnit})
	var context: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	gs._log("幻境「%s」引动。" % realm.name, gs.TONE_CARD)
	match mode:
		"huang-track":
			var amount := int(realm.hp)
			var idx: int = gs.front_index(1 - owner)
			var overflow := 0
			if idx >= 0:
				var target: Dictionary = gs.player(1 - owner).units[idx]
				if not target.get("bloodTransfer", false): overflow = maxi(0, amount + int(target.armorBreak) - int(target.shield) - int(target.hp))
			_hit(gs, owner, src, idx, amount, realm)
			if overflow > 0 and gs.winner < 0: _hit(gs, owner, src, -1, overflow, realm)
			destroy(gs, owner, realm, "自毁")
		"huang-meteor":
			var count := int(realm.hp)
			for i in count:
				if gs.winner >= 0: break
				var pool: Array = [-1]
				for idx in gs.player(1 - owner).units.size():
					if int(gs.player(1 - owner).units[idx].hp) > 0 and int(gs.player(1 - owner).units[idx].level) >= 1: pool.append(idx)
				var idx: int = pool[int(floor(gs.randf01() * pool.size()))]
				_hit(gs, owner, src, idx, 2, realm)
				gs.VerifiedRules.event(gs, "realm-random-hit", {"player": owner, "realm": realm.uid, "target": "" if idx < 0 else gs.player(1 - owner).units[idx].uid, "amount": 2, "step": i})
			destroy(gs, owner, realm, "自毁")
		"huang-moon":
			gain(gs, owner, realm, 3)
			if int(realm.hp) >= 30:
				# Once the threshold is met, destruction and the damage group are
				# committed; subsequent damage cannot undo this threshold check.
				destroy(gs, owner, realm, "自毁")
				for idx in gs.player(1 - owner).units.size():
					if gs.winner >= 0: break
					if int(gs.player(1 - owner).units[idx].hp) > 0: _hit(gs, owner, src, idx, 10, realm)
				if gs.winner < 0: _hit(gs, owner, src, -1, 10, realm)
	gs._card_effect_context = context
	return true

static func score_card(gs, owner: int, card: Dictionary, _target) -> Variant:
	if not card.get("huangRules", false): return null
	if card.get("effect") == "huang-discard-draw": return 50 if gs.player(owner).hand.size() <= 9 and gs.player(owner).deck.size() >= 3 else -100
	if card.get("effect") == "huang-awaken": return 60 if not gs.player(owner).units[gs._source_index(owner, card)].awakened else -100
	if card.get("type") == "form": return 55 + (gs.player(owner).realms.size() * 5 if card.get("huangBody", false) else 0)
	return 48
