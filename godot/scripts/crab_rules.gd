class_name CrabRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func uses(gs, owner: int, id: String) -> int:
	var name: String = Content.card_def(id).get("name", id)
	return int(gs.player(owner).get("sameNameUses", {}).get(name, 0))

static func source(gs, owner: int) -> Dictionary:
	for unit in gs.player(owner).units:
		if active(unit) and Content.runtime_unit_def(unit).get("crabSameName", false): return unit
	return {}

static func bounce_instance(unit: Dictionary, inst: Dictionary, card: Dictionary) -> Dictionary:
	var copy := inst.duplicate(true)
	if not unit.is_empty() and unit.get("formRules", {}).get("crabBounce", false) and card.get("crabRules", false) and card.type in ["spell", "awakening", "combat"]:
		var grant := int(unit.get("crabBounceGrant", 0))
		if int(copy.get("crabBounceGrant", -1)) != grant:
			copy.crabBounceGrant = grant; copy.crabBounceSpent = false
	return copy

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var unit := source(gs, owner)
	var prior := uses(gs, owner, str(card.id))
	var same_name_instant: bool = not unit.is_empty() and prior > 0 and gs._source_index(owner, card) >= 0 and (unit.awakened or card.get("crabRules", false))
	if not card.get("crabRules", false) and not same_name_instant: return card
	var out := card.duplicate(true)
	if same_name_instant:
		out.keywords.append("instant"); out.text += "\n已使用过同名牌：瞬发。"
	if not card.get("crabRules", false): return out
	out.crabPriorUses = prior
	if prior > 0: out.enhanced = true
	out.crabInstance = bounce_instance(unit, inst, card)
	out.crabReturn = out.crabInstance.has("crabBounceGrant") and not out.crabInstance.get("crabBounceSpent", false)
	if out.crabReturn: out.keywords.append("bounce"); out.text += "\n弹回：使用后原牌回手并失去此次弹回。"
	match str(card.effect):
		"assault":
			out.value = 1 + prior * 2
			out.effects[0].value = out.value
			out.combatOption.shield = 1 + prior
		"draw": out.value = 1 + prior; out.effects[0].value = out.value
		"form":
			if card.get("crabGrowingBody", false):
				out.value.attack = 6 + prior * 2; out.value.hp = 6 + prior * 2
				out.effects[0].value = out.value.duplicate(true)
	if prior > 0:
		if card.effect == "form" and card.get("crabGrowingBody", false): out.currentCardStats = "当前面板 %d/%d" % [int(out.value.attack), int(out.value.hp)]
		elif card.effect == "draw": out.currentCardStats = "当前抽牌 %d张" % int(out.value)
		elif card.effect == "crab-hammer": out.currentCardStats = "额外随机伤害 2×%d" % prior
	out.text += "\n本局此前使用过同名牌%d次。" % prior
	return out

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var history: Dictionary = gs.player(owner).get("sameNameUses", {})
	var name := str(card.get("name", card.id))
	var prior := int(history.get(name, 0))
	history[name] = prior + 1; gs.player(owner).sameNameUses = history
	if not card.get("crabRules", false): return
	var after := {"kind": "crab-after-use", "playerIndex": owner, "sourceIndex": int(frame.sourceIndex), "prior": prior, "card": card.duplicate(true)}
	# 使用记录及用牌后触发独立于牌的效果，反制不会抹去实际用牌历史。
	for i in gs.resolution_stack.size():
		if gs.resolution_stack[i].get("kind") == "card-complete" and gs.resolution_stack[i].get("resolutionId") == frame.resolutionId:
			gs.resolution_stack.insert(i, after); return

static func form_entered(gs, owner: int, idx: int, card: Dictionary) -> void:
	if not card.get("formRules", {}).get("crabBounce", false): return
	var unit: Dictionary = gs.player(owner).units[idx]
	unit.crabBounceGrant = gs.next_rule_event_id
	for zone in ["deck", "hand"]:
		for i in gs.player(owner)[zone].size():
			var inst: Dictionary = gs.player(owner)[zone][i]
			gs.player(owner)[zone][i] = bounce_instance(unit, inst, Content.card_def(str(inst.definitionId)))

static func copy_card(gs, owner: int, inst: Dictionary, zone: String) -> void:
	var copy := inst.duplicate(true)
	copy.instanceId = "%s-crab-%d" % [gs.player(owner).id, gs.next_card_id]; gs.next_card_id += 1
	copy.erase("revealed")
	copy = bounce_instance(source(gs, owner), copy, Content.card_def(str(copy.definitionId)))
	if zone == "hand" and gs.player(owner).hand.size() >= int(gs.rules.maxHandSize):
		gs._log("手牌已满，复制的牌被烧毁。", gs.TONE_DANGER); return
	gs.player(owner)[zone].append(copy)
	gs.VerifiedRules.event(gs, "card-copied", {"player": owner, "instanceId": copy.instanceId, "card": Content.card_def(str(copy.definitionId)), "zone": zone})

static func random_hand_copy(gs, owner: int) -> void:
	var hand: Array = gs.player(owner).hand
	if not hand.is_empty(): copy_card(gs, owner, hand[int(floor(gs.randf01() * hand.size()))], "hand")

static func end_turn(gs, owner: int) -> void:
	for realm in gs.player(owner).realms.duplicate():
		if realm.get("nativeRealm") == "crab-dream" and int(realm.hp) > 0: random_hand_copy(gs, owner)

static func clear_finished_immunity(gs) -> void:
	for owner in gs.players.size():
		for idx in gs.player(owner).units.size():
			var unit: Dictionary = gs.player(owner).units[idx]
			if not unit.get("crabCombatImmune", false): continue
			var pending: bool = gs.resolution_stack.any(func(f): return int(f.get("playerIndex", -1)) == owner and int(f.get("sourceIndex", -1)) == idx and f.get("options", {}).get("crabImmuneAll", false))
			if not pending: unit.erase("crabCombatImmune")

static func choices(gs, owner: int) -> Array:
	return gs.player(owner).hand.filter(func(i): return Content.card_def(str(i.definitionId)).get("crabRules", false)).map(func(i): return str(i.instanceId))

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect") != "crab-sleep" or choices(gs, owner).size() > 1

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") != "crab-sleep" or int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var p: Dictionary = gs.player(owner)
	var idx: int = p.hand.find_custom(func(i): return str(i.instanceId) == iid)
	if idx < 0: return false
	for i in 3: copy_card(gs, owner, p.hand[idx], "deck")
	gs._shuffle(p.deck)
	gs._record("resolve_divination_choice", {"instanceId": iid, "card": p.hand[idx].definitionId, "choice": "crab-sleep"}, owner)
	gs.pending_choice = {}; gs.phase = "main"
	gs._draw(owner, 1); gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != "crab-sleep": return null
	var best := str(gs.pending_choice.instanceIds[0]); var score := -1
	for iid in gs.pending_choice.instanceIds:
		for inst in gs.player(owner).hand:
			if str(inst.instanceId) != str(iid): continue
			var card: Dictionary = Content.card_def(str(inst.definitionId))
			var value := 10 if card.type == "combat" or card.get("effect") == "crab-hammer" else int(card.level)
			if value > score: best = str(iid); score = value
	return resolve_choice(gs, owner, best)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") == "crab-hammer-hit":
		var owner := int(frame.playerIndex); var enemy := 1 - owner
		var pool: Array = ["avatar-%d" % enemy]
		for unit in gs.player(enemy).units:
			if int(unit.hp) > 0: pool.append(str(unit.uid))
		var target := str(pool[int(floor(gs.randf01() * pool.size()))])
		gs.VerifiedRules.Eye.damage(gs, owner, int(frame.sourceIndex), target, 2 + int(frame.get("damageBonus", 0)))
		return true
	if frame.get("kind") != "crab-after-use": return false
	var owner := int(frame.playerIndex); var idx := int(frame.sourceIndex)
	var unit: Dictionary = gs.player(owner).units[idx]
	var card: Dictionary = frame.card
	if card.get("crabReturn", false):
		var inst: Dictionary = card.crabInstance.duplicate(true)
		inst.crabBounceSpent = true
		if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
		else: gs._log("手牌已满，弹回的牌被烧毁。", gs.TONE_DANGER)
		gs.VerifiedRules.event(gs, "crab-card-returned", {"player": owner, "card": card, "instanceId": inst.instanceId})
	if int(frame.prior) > 0 and active(unit) and int(unit.frozen) == 0 and unit.get("formRules", {}).get("crabBounce", false) and int(unit.get("crabAttackTurn", -1)) != gs.turn_counter:
		unit.crabAttackTurn = gs.turn_counter
		gs._resolve_combat(owner, idx, 0, false, false, false, false, null, false, {"immuneCombat": true, "crabImmuneAll": true})
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.get("action", "")):
		"crab-sleep":
			var ids := choices(gs, owner)
			if not ids.is_empty():
				gs.pending_choice = {"type": "crab-sleep", "playerIndex": owner, "zone": "hand", "instanceIds": ids, "heading": "睡 觉 觉", "title": "选择一张蟹姬手牌", "hint": "将选中牌的三张复制洗入牌库，然后抽一张牌。"}; gs.phase = "choice"
		"crab-awaken": gs._awaken(owner, src, card, {"attack": 2, "hp": 2}); random_hand_copy(gs, owner)
		"crab-hammer":
			for i in int(card.get("crabPriorUses", 0)):
				gs.resolution_stack.append({"kind": "crab-hammer-hit", "playerIndex": owner, "sourceIndex": src, "damageBonus": int(card.get("foxHandDamageBonus", 0))})
			gs.VerifiedRules.Eye.damage(gs, owner, src, target_id, 4 + int(card.get("foxHandDamageBonus", 0)))
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("crabRules", false): return null
	if card.effect == "crab-awaken": return -100 if gs.player(owner).units[gs._source_index(owner, card)].awakened else 80
	if card.type == "form":
		var unit: Dictionary = gs.player(owner).units[gs._source_index(owner, card)]
		if unit.get("form", {}).get("cardId") != card.id: return 75
		if card.get("crabGrowingBody", false) and (int(card.value.attack) > int(unit.attack) or int(card.value.hp) > int(unit.maxHp) or int(unit.hp) < int(unit.maxHp)): return 60
		return -100
	if card.effect == "crab-hammer": return 65 + int(card.get("crabPriorUses", 0)) * 15 if str(target_id) == "avatar-%d" % (1 - owner) or gs._unit_index_by_uid(1 - owner, target_id) >= 0 else -100
	return 55 + int(card.get("crabPriorUses", 0)) * 5
