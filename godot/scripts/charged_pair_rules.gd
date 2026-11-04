class_name ChargedPairRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const MODE := "charged-mode"

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("chargedPairRole", ""))

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func clean(inst: Dictionary) -> Dictionary:
	var result := inst.duplicate(true)
	for key in ["chargedMode", "chargedSelected", "chargedReleased"]: result.erase(key)
	return result

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var c := card.duplicate(true)
	var mode := str(gs.player(owner).get("chargedModes", {}).get(str(inst.get("instanceId", "")), inst.get("chargedMode", "")))
	c.chargedSelected = c.get("canCharge", false) and mode == "charge"
	if str(c.id) == "c26802":
		var n: int = gs._all_units().filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and u.has("lanternStored")).size()
		c.value = 1 + n; c.effects[0].value = c.value; c.enhanced = n > 0
		c.currentCardStats = "场上%d位蓄力 · +%d力量" % [n, 1 + n]
	if c.get("canCharge", false):
		var src: int = gs._source_index(owner, c)
		if c.chargedSelected: c.currentCardStats = "蓄力 · 记录本牌与所选目标"
		elif src >= 0 and gs.player(owner).units[src].has("lanternStored"): c.currentCardStats = str(c.get("currentCardStats", "")) + " · 已有蓄力，仅可普通使用"
	return c

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	var src: int = gs._source_index(owner, card)
	if src < 0: return true
	if card.get("chargedSelected", false):
		return gs.response_window.is_empty() and gs.current_player == owner and not gs.player(owner).units[src].has("lanternStored")
	if str(card.id) == "c26907" and int(gs.player(owner).units[src].hp) <= 0: return gs.VerifiedRules.Rebirth.can_revive(gs.player(owner).units[src])
	return true

static func prepare_card(gs, owner: int, src: int, card: Dictionary) -> Dictionary:
	var c := card.duplicate(true)
	c.chargedSourceWasStored = gs.player(owner).units[src].has("lanternStored") or c.get("chargedReleased", false)
	return c

static func targets(gs, owner: int, card: Dictionary):
	if str(card.get("id", "")) == "c26801":
		var ids: Array = []
		for side in [owner, 1-owner]:
			for u in gs.player(side).units:
				if int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil")): ids.append(str(u.uid))
		return ids
	if str(card.get("id", "")) != "c26806": return null
	return gs.player(owner).units.filter(func(u): return active(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and u.has("lanternStored")).map(func(u): return str(u.uid))

static func request_mode(gs, owner: int, index: int) -> bool:
	if not gs.pending_choice.is_empty() or not gs.response_window.is_empty() or gs.current_player != owner: return false
	var c: Dictionary = gs.hand_card_def(owner, index)
	if not c.get("canCharge", false): return false
	var src: int = gs._source_index(owner, c)
	if src < 0 or gs.player(owner).units[src].has("lanternStored"): return false
	gs.pending_choice = {"type": MODE, "playerIndex": owner, "handIid": str(gs.card_instance(owner, index).instanceId), "card": c, "instanceIds": ["charged-use", "charged-store", "charged-cancel"], "heading": "使 用 方 式", "hint": "选择普通使用或蓄力，再选择目标；蓄力此时支付费用，下个己方回合自动使用。"}
	gs.phase = "choice"; gs.state_changed.emit(); return true

static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type") != MODE or int(gs.pending_choice.playerIndex) != owner: return null
	if iid == "charged-cancel": return {"id": iid, "name": "取消", "type": "spell", "level": 0, "cost": 0, "text": "返回手牌，不支付费用。"}
	var c: Dictionary = gs.pending_choice.card.duplicate(true)
	c.currentCardStats = "蓄力使用" if iid == "charged-store" else "普通使用"
	c.text = "支付本牌费用，记录真实牌和所选目标，下个己方回合自动使用。" if iid == "charged-store" else str(c.text)
	return c

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var q: Dictionary = gs.pending_choice
	if q.get("type") != MODE or int(q.playerIndex) != owner or iid not in q.instanceIds: return false
	var index := -1
	for i in gs.playable_card_count(owner):
		if str(gs.card_instance(owner, i).instanceId) == str(q.handIid): index = i; break
	if index < 0: return false
	if iid != "charged-cancel":
		if not gs.player(owner).has("chargedModes"): gs.player(owner).chargedModes = {}
		gs.player(owner).chargedModes[str(q.handIid)] = "charge" if iid == "charged-store" else "use"
		gs.player(owner).chargedReadyHand = index
	else: gs.player(owner).get("chargedModes", {}).erase(str(q.handIid))
	gs.pending_choice = {}; gs.phase = "main"
	gs._record("resolve_divination_choice", {"choice": MODE, "instanceId": iid}, owner)
	gs.state_changed.emit(); return true

static func ready_hand(gs, owner: int) -> int:
	var index := int(gs.player(owner).get("chargedReadyHand", -1))
	gs.player(owner).erase("chargedReadyHand"); return index

static func refresh(gs) -> void:
	for side in gs.players:
		var forest: bool = side.realms.any(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "charged-forest")
		for u in side.units: u.chargedVeil = forest and active(u) and u.has("lanternStored")

static func _stored(gs, owner: int, src: int, card: Dictionary, instance: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or u.has("lanternStored"): return false
	var c := card.duplicate(true); c.chargedSelected = false; c.erase("chargedReleased")
	u.lanternStored = {"chargedPair": true, "card": c, "instance": clean(instance), "targetId": target_id, "turn": gs.turn_counter, "order": gs.next_rule_event_id}
	if role(u) == "beads":
		if u.awakened:
			gs.VerifiedRules.Glutton.record_permanent(u, 1, 1, true)
			gs.VerifiedRules.SunSmoke.remember_permanent(u, 1, 1)
		else: u.chargedGrowth = int(u.get("chargedGrowth", 0)) + 1
		gs._grow_unit(u, 1, 1)
	refresh(gs)
	gs.VerifiedRules.event(gs, "charged-stored", {"player": owner, "uid": u.uid, "card": str(c.id), "target": target_id, "instanceId": instance.get("instanceId", "")})
	return true

static func store_hand(gs, owner: int, index: int, card: Dictionary, payment: Dictionary, target_id) -> bool:
	var src: int = gs._source_index(owner, card)
	if src < 0 or gs.player(owner).units[src].has("lanternStored"): return false
	var instance: Dictionary = gs.take_card_instance(owner, index)
	gs.player(owner).get("chargedModes", {}).erase(str(instance.get("instanceId", "")))
	gs._set_fire(owner, int(gs.player(owner).energy) - int(payment.cost), true)
	gs.VerifiedRules.Moon.consume_card(gs, card)
	if payment.usesInstant: gs.kw_usage(owner, "instant").used = true
	gs._record("play_card", {"hand": index, "card": card.id, "target": target_id, "cardView": card.duplicate(true), "payment": payment.duplicate(true), "charge": true}, owner)
	gs.VerifiedRules.Zhenjian.consume_card(gs,owner,src,card)
	var result := _stored(gs, owner, src, card, instance, target_id)
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return result

static func store_copy(gs, owner: int, src: int, card: Dictionary, target_id) -> bool:
	var inst: Dictionary = clean(card.get("playedInstance", {}))
	inst.definitionId = str(card.id); inst.instanceId = "%s-charged-copy-%d" % [gs.player(owner).id, gs.next_card_id]
	inst.generatedByAbility = true; gs.next_card_id += 1
	return _stored(gs, owner, src, card, inst, target_id)

static func release(gs, owner: int, src: int, combat_id: int = -1) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or not u.has("lanternStored") or gs.VerifiedRules.Stun.blocks(gs, owner, u): return false
	var record: Dictionary = u.lanternStored.duplicate(true)
	u.erase("lanternStored"); refresh(gs)
	gs.VerifiedRules.Arakawa.refresh_hold(gs)
	var c: Dictionary = gs.describe_card_instance(owner, clean(record.instance), false)
	if c.is_empty(): c = record.card.duplicate(true)
	c.chargedReleased = true; c.chargedSelected = false; c.playedInstance = clean(record.instance)
	c=gs.VerifiedRules.Zhenjian.prepare_release(gs,owner,src,c,record)
	if str(c.id) == "c26903": c.formRules.combatKeywords = ["pursuit"]
	for observer in gs.player(owner).units:
		if active(observer) and role(observer) == "bamboo":
			gs._grow_unit(u, 1, 0); u.chargedBambooGrowth = int(u.get("chargedBambooGrowth", 0)) + 1
			if observer.awakened: gs._draw(owner, 1)
	gs.VerifiedRules.event(gs, "charged-release", {"player": owner, "uid": u.uid, "card": str(c.id), "target": record.get("targetId"), "early": combat_id >= 0})
	gs._push_card_frames(owner, str(c.id), record.get("targetId"), c, src, 0, true, combat_id)
	return true

static func defend_started(gs, frame: Dictionary) -> bool:
	var owner := int(frame.options.get("combatVictim", 1 - int(frame.playerIndex)))
	var src := int(frame.defenderIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if str(u.get("lanternStored", {}).get("card", {}).get("id", "")) != "c26904" or gs.VerifiedRules.Stun.blocks(gs, owner, u): return false
	frame.chargedDefenceReady = true
	gs.resolution_stack.append(frame)
	return release(gs, owner, src, int(frame.combatId))

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> void:
	if card.get("chargedReleased", false): gs.player(owner).units[src].barrier = true
	gs.VerifiedRules.ArmorBreak.respond_combat(gs, combat_id, owner, src, card)

static func _awaken(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if str(card.id) == "c26907": gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
	if u.awakened:
		gs.VerifiedRules.Glutton.record_permanent(u, 1, 1, true); gs.VerifiedRules.SunSmoke.remember_permanent(u, 1, 1); gs._grow_unit(u, 1, 1)
	else: gs._awaken(owner, src, card, {"attack": 1, "hp": 1})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"charged-grow-draw":
			var target: Dictionary = gs._unit_by_uid(gs._all_units(), str(target_id))
			if not target.is_empty() and int(target.hp) > 0:
				gs._grow_unit(target, 2, 0)
				if target.has("lanternStored"): gs._grant_unit_armor(target, 2)
			gs._draw(owner, 1)
		"charged-release":
			var idx: int = gs._unit_index_by_uid(owner, str(target_id))
			if idx >= 0: release(gs, owner, idx)
		"charged-awaken": _awaken(gs, owner, src, card)
		"charged-heal": gs._heal_unit(u, 3); gs._heal_avatar(owner, 3)
		"charged-realm":
			gs._deploy_realm(owner, card)
			for target in gs.player(owner).units: gs._heal_unit(target, 2)
			refresh(gs)
		"charged-history":
			gs.resolution_stack.append({"kind": "charged-give-breeze", "playerIndex": owner, "sourceIndex": src})
			for idx in range(gs.player(owner).units.size() - 1, -1, -1):
				if active(gs.player(owner).units[idx]) and not gs.player(owner).units[idx].has("lanternStored"): gs.resolution_stack.append({"kind": "charged-history-one", "playerIndex": owner, "sourceIndex": idx})
		"charged-combat":
			if card.get("chargedReleased", false):
				if str(card.id) == "c26902": _give(gs, owner, "c26902")
				if str(card.id) == "c26904": u.barrier = true
				if str(card.id) == "c26905":
					var front: int = gs.front_index(1 - owner)
					if front >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1 - owner, front, card)
			var options: Dictionary = card.get("combatOption", {}).duplicate(true); options.combatCard = card.duplicate(true)
			gs._grant_unit_armor(u, int(options.get("shield", 0)))
			gs._record("assault", {"unit": src, "bonus": int(card.value), "target": target_id}, owner)
			gs._resolve_combat(owner, src, int(card.value), false, false, false, false, target_id, false, options)
		_: return false
	return true

static func _give(gs, owner: int, id: String) -> void:
	var inst := {"definitionId": id, "instanceId": "%s-charged-gift-%d" % [gs.player(owner).id, gs.next_card_id]}
	gs.next_card_id += 1
	if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex); var u: Dictionary = gs.player(owner).units[src]
	gs.player(owner).get("chargedModes", {}).erase(str(card.get("playedInstance", {}).get("instanceId", "")))
	if str(card.get("type", "")) in ["spell", "combat", "form", "realm", "awakening"]:
		var history: Array = u.get("chargedHistory", [])
		history = history.filter(func(c): return str(c.id) != str(card.id)); history.append(card.duplicate(true)); u.chargedHistory = history
	if str(card.id) == "c26901" and not frame.get("automatic", false): gs.resolution_stack.append({"kind": "charged-copy", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "targetId": frame.get("targetId")})
	if card.get("chargedSourceWasStored", false) or card.get("chargedReleased", false) or card.get("chargedAwaken", false) or str(card.get("type", "")) not in ["combat", "spell"] or u.has("lanternStored"): return
	for observer in gs.player(owner).units:
		if active(observer) and observer.get("formRules", {}).get("chargedCopy", false) and int(observer.get("chargedCopyTurn", -1)) != gs.turn_counter:
			observer.chargedCopyTurn = gs.turn_counter
			gs.resolution_stack.append({"kind": "charged-copy", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "targetId": frame.get("targetId")})

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if str(card.id) == "c26906":
		u.inspired = true
		if card.get("chargedReleased", false): u.swift = true
	if str(card.id) == "c26908" and card.get("chargedReleased", false): gs.resolution_stack.append({"kind": "charged-form-attack", "playerIndex": owner, "sourceIndex": src})

static func death_frames(gs, owner: int, u: Dictionary) -> Array:
	if owner < 0: return []
	var result: Array = []; var src: int = gs._unit_index_by_uid(owner, str(u.uid))
	if u.has("lanternStored"):
		for idx in gs.player(owner).units.size():
			var observer: Dictionary = gs.player(owner).units[idx]
			if (active(observer) or (observer == u and int(observer.level) > 0 and not observer.get("baseRulesSuppressed", false))) and observer.get("formRules", {}).get("chargedDeath", false): result.append({"kind": "charged-death-hit", "playerIndex": owner, "sourceIndex": idx})
	if role(u) == "beads" and u.get("formRules", {}).get("chargedReviveForm", false):
		result.append({"kind": "charged-revive-store", "playerIndex": owner, "sourceIndex": src, "instance": u.form.get("cardInstance", {}).duplicate(true)})
	return result

static func knocked_out(u: Dictionary) -> void:
	var growth := int(u.get("chargedGrowth", 0)); u.attackBonus = int(u.attackBonus) - growth - int(u.get("chargedBambooGrowth", 0)); u.maxHpBonus = int(u.maxHpBonus) - growth
	for key in ["chargedGrowth", "chargedBambooGrowth", "chargedVeil"]: u.erase(key)

static func random_targets(gs, owner: int, card: Dictionary) -> Array:
	# A private rules snapshot removes selection-only veil without touching play state.
	var shadow = gs.get_script().new()
	for prop in gs.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = gs.get(str(prop.name))
			shadow.set(str(prop.name), value.duplicate(true) if value is Array or value is Dictionary else value)
	for p in shadow.players:
		p.randomTargetPreview = true
		for unit in p.units: unit.randomTargetPreview = true
	return shadow.valid_targets(owner, card)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if kind == "combat-hit" and frame.get("chargedDefenceReady", false):
		frame.erase("chargedDefenceReady")
		gs._offer_attack_responses(frame)
		return true
	if not kind.begins_with("charged-"): return false
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex); var u: Dictionary = gs.player(owner).units[src]
	match kind:
		"charged-copy": store_copy(gs, owner, src, frame.card, frame.get("targetId"))
		"charged-history-one":
			var pool: Array = u.get("chargedHistory", []).duplicate(true)
			pool = pool.filter(func(c): return str(c.get("target", "auto")) == "auto" or not random_targets(gs, owner, c).is_empty())
			if not pool.is_empty():
				var c: Dictionary = pool[int(gs.next_random() % pool.size())]
				var targets_: Array = [null] if str(c.get("target", "auto")) == "auto" else random_targets(gs, owner, c)
				store_copy(gs, owner, src, c, targets_[int(gs.next_random() % targets_.size())])
		"charged-give-breeze": _give(gs, owner, "c26806")
		"charged-death-hit": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 4, "竹叶守护")
		"charged-revive-store":
			gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
			if int(u.hp) > 0:
				var c := Content.card_def("c26908").duplicate(true); c.playedInstance = frame.instance
				store_copy(gs, owner, src, c, null)
		"charged-form-attack": gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"immuneCombat": true})
	return true

static func ai_prepare(gs, owner: int) -> void:
	for index in gs.playable_card_count(owner):
		var inst: Dictionary = gs.card_instance(owner, index); var c := Content.card_def(str(inst.get("definitionId", ""))); var src: int = gs._source_index(owner, c)
		if src >= 0 and c.get("canCharge", false) and not gs.player(owner).units[src].has("lanternStored"):
			if not gs.player(owner).has("chargedModes"): gs.player(owner).chargedModes = {}
			gs.player(owner).chargedModes[str(inst.instanceId)] = "charge" if str(c.unitId) == "shuzhu" and c.id not in ["c26906"] else "use"

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != MODE: return null
	return resolve_choice(gs, owner, "charged-store")

static func score_card(gs, owner: int, card: Dictionary, _target):
	if not card.get("chargedPairCard", false): return null
	if str(card.id) == "c26806": return 65
	if card.get("chargedAwaken", false): return 65 if not gs.player(owner).units[gs._source_index(owner, card)].awakened else 15
	return 40 if card.get("chargedSelected", false) else 32

static func marks(gs, _owner: int, u: Dictionary) -> Array:
	var result: Array = []
	if u.has("lanternStored"):
		var record: Dictionary = u.lanternStored
		result.append("蓄力 · " + str(record.card.get("name", "")) + (" · 可主动释放" if not gs.VerifiedRules.Zhenjian.auto_release(u) else " · 下个己方回合使用"))
	if role(u) == "beads": result.append("蓄力时" + ("永久" if u.awakened else "") + "+1力量/+1生命")
	return result
