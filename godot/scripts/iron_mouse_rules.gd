class_name IronMouseRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("coinMaster", false) and not unit.get("baseRulesSuppressed", false)

static func active(unit: Dictionary) -> bool:
	return is_source(unit) and int(unit.hp) > 0 and int(unit.level) > 0

static func used(gs, owner: int) -> int:
	var p: Dictionary = gs.player(owner)
	return int(p.get("coinsUsed", 0)) if int(p.get("coinUsedTurn", -1)) == gs.turn_counter else 0

static func add_coin(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var instance := {"definitionId": "xingyun-qianbi", "instanceId": "%s-coin-%d" % [p.id, gs.next_card_id]}
	gs.next_card_id += 1
	if p.hand.size() < int(gs.rules.maxHandSize): p.hand.append(instance)
	else: gs._log("手牌已满，获得的幸运钱币被烧毁。", gs.TONE_DANGER)
	gs.VerifiedRules.event(gs, "coin-created", {"player": owner, "card": ContentLoader.card_def("xingyun-qianbi")})

static func upgraded(gs, owner: int, idx: int) -> void:
	if active(gs.player(owner).units[idx]): add_coin(gs, owner)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.has("coinRule"): return card
	var out := card.duplicate(true)
	var src: int = gs._source_index(owner, out)
	if src < 0: return out
	var unit: Dictionary = gs.player(owner).units[src]
	var count := used(gs, owner)
	match str(out.coinRule):
		"coin":
			out.coinInstance = inst.duplicate(true)
			if active(unit) and unit.awakened and count == 0:
				out.cost = 0
				out.coinFirstFree = true
				out.text += "\n觉醒：本回合首枚钱币不消耗鬼火。"
			if active(unit) and unit.get("formRules", {}).get("coinDamageGuard", false):
				out.autoResponse = "source-damaged"
				out.coinDamageGuard = true
				out.text += "\n响应：当铁鼠受到伤害时，自动使用并免疫本次伤害。"
		"jingle":
			out.value = count
			out.effects[0].value = count
			out.combatOption.immuneCombat = count > 0
			out.text += "\n本回合已用%d枚：+%d力量%s。" % [count, count, "，免疫战斗伤害" if count > 0 else ""]
		"fraud":
			out.combatOption.lethal = count > 0
			if count > 0: out.keywords.append("lethal")
			out.text += "\n本回合已用%d枚%s。" % [count, "，已获得必杀" if count > 0 else "，尚未获得必杀"]
		"windfall":
			var available: int = gs.player(owner).hand.filter(func(i): return ContentLoader.card_def(str(i.definitionId)).get("coinRule") == "coin").size()
			out.text += "\n当前可使用%d枚钱币，每枚投射4点伤害。" % mini(3, available)
	return out

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.get("coinRule") != "coin": return
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var p: Dictionary = gs.player(owner)
	p.coinsUsed = used(gs, owner) + 1
	p.coinUsedTurn = gs.turn_counter
	var unit: Dictionary = p.units[src]
	if active(unit):
		if unit.awakened:
			unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) + 1
			unit.coinTemporaryAttack = int(unit.get("coinTemporaryAttack", 0)) + 1
			unit.coinSwiftTurn = gs.turn_counter
			gs._recalc(unit)
		if unit.get("formRules", {}).get("coinGrowth", false):
			gs._grow_unit(unit, 1, 1)
			unit.coinGrowth = int(unit.get("coinGrowth", 0)) + 1
		if unit.get("formRules", {}).get("coinDirectAttack", false) and int(unit.formRules.get("coinAttackTurn", -1)) != gs.turn_counter:
			unit.formRules.coinAttackTurn = gs.turn_counter
			# This independent use-trigger survives a counter to the coin itself.
			var trigger := {"kind": "coin-direct-attack", "playerIndex": owner, "sourceIndex": src}
			for i in gs.resolution_stack.size():
				var pending: Dictionary = gs.resolution_stack[i]
				if pending.get("kind") == "card-complete" and int(pending.get("resolutionId", -1)) == int(frame.resolutionId):
					gs.resolution_stack.insert(i, trigger)
					break
	gs.VerifiedRules.event(gs, "coin-used", {"player": owner, "uid": unit.uid, "count": p.coinsUsed, "card": card})

static func swift(gs, unit: Dictionary) -> bool:
	return active(unit) and int(unit.get("coinSwiftTurn", -1)) == gs.turn_counter

static func end_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			var bonus := int(unit.get("coinTemporaryAttack", 0))
			if bonus > 0:
				unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) - bonus
				unit.erase("coinTemporaryAttack")
				gs._recalc(unit)
			unit.erase("coinSwiftTurn")

static func knocked_out(unit: Dictionary) -> void:
	var growth := int(unit.get("coinGrowth", 0))
	unit.attackBonus = int(unit.attackBonus) - growth
	unit.maxHpBonus = int(unit.maxHpBonus) - growth
	for key in ["coinGrowth", "coinTemporaryAttack", "coinSwiftTurn", "coinPreventDamage"]: unit.erase(key)

static func prevents_damage(gs, unit: Dictionary) -> bool:
	if not unit.get("coinPreventDamage", false): return false
	unit.erase("coinPreventDamage")
	gs.VerifiedRules.event(gs, "coin-damage-prevented", {"uid": unit.uid})
	return true

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if owner == victim or idx >= 0 or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	if not options.get("coinOnAvatarDamage", false): return
	add_coin(gs, owner)
	gs.VerifiedRules.event(gs, "coin-combat-earned", {"player": owner, "uid": gs.player(owner).units[src].uid})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"coin-toss":
			if card.get("coinGuardTriggered", false): unit.coinPreventDamage = true
			if gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src):
				var inst: Dictionary = card.coinInstance.duplicate(true)
				if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(inst)
				gs.VerifiedRules.event(gs, "coin-returned", {"player": owner, "uid": unit.uid, "card": card, "instanceId": inst.instanceId})
		"coin-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, 1, 1)
			add_coin(gs, owner)
		"coin-windfall":
			var ids: Array = []
			for inst in gs.player(owner).hand:
				if ContentLoader.card_def(str(inst.definitionId)).get("coinRule") == "coin" and ids.size() < 3: ids.append(inst.instanceId)
			gs.resolution_stack.append({"kind": "coin-windfall-step", "playerIndex": owner, "sourceIndex": src, "instanceIds": ids, "used": 0, "card": card.duplicate(true), "context": gs._card_effect_context.duplicate(true)})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if kind not in ["coin-direct-attack", "coin-windfall-step", "coin-windfall-projectile"]: return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	if kind == "coin-direct-attack":
		if active(unit) and int(unit.frozen) == 0:
			var context: Dictionary = gs._card_effect_context
			gs._card_effect_context = {}
			gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"directAvatar": true})
			gs._card_effect_context = context
		return true
	if kind == "coin-windfall-projectile":
		var context: Dictionary = gs._card_effect_context
		gs._card_effect_context = frame.context.duplicate(true)
		var target: int = gs.front_index(1 - owner)
		var amount := 4 + int(frame.card.get("foxHandDamageBonus", 0))
		if target < 0: gs._damage_avatar(1 - owner, amount, owner, src)
		else: gs._damage_unit(1 - owner, target, amount, owner, src)
		gs._card_effect_context = context
		return true
	while not frame.instanceIds.is_empty() and active(unit) and int(unit.frozen) == 0:
		var iid: String = str(frame.instanceIds.pop_front())
		for i in p.hand.size():
			if str(p.hand[i].instanceId) != iid: continue
			var coin: Dictionary = gs.hand_card_def(owner, i)
			p.hand.remove_at(i)
			p.cardsPlayedThisTurn = int(p.cardsPlayedThisTurn) + 1
			frame.used = int(frame.used) + 1
			gs.resolution_stack.append(frame)
			# The parent card pays for these real uses. They do not consume fire
			# or the shared instant allowance; returns cannot re-use the same copy.
			gs._push_card_frames(owner, str(coin.id), null, coin, src, gs.MAX_RESPONSE_DEPTH)
			return true
	for i in int(frame.used):
		gs.resolution_stack.append({"kind": "coin-windfall-projectile", "playerIndex": owner, "sourceIndex": src, "card": frame.card, "context": frame.context})
	return true

static func score_card(gs, owner: int, card: Dictionary):
	if not card.has("coinRule"): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var unit: Dictionary = gs.player(owner).units[src]
	match str(card.coinRule):
		"coin":
			# A bare toss has no standalone reward; reserve coins for a payoff.
			if unit.awakened or unit.get("formRules", {}).get("coinGrowth", false): return 60 if used(gs, owner) < 6 else -100
			if unit.get("formRules", {}).get("coinDirectAttack", false) and int(unit.formRules.get("coinAttackTurn", -1)) != gs.turn_counter: return 80
			return -100
		"windfall": return 65 + mini(3, gs.player(owner).hand.filter(func(i): return ContentLoader.card_def(str(i.definitionId)).get("coinRule") == "coin").size()) * 20 if gs.player(owner).hand.any(func(i): return ContentLoader.card_def(str(i.definitionId)).get("coinRule") == "coin") else -100
		"awaken": return 85 if not unit.awakened else 15
		"form": return 55 if unit.get("form", {}).get("cardId") != card.id else -100
		_: return 50 + int(card.get("value", 0)) * 4 + (25 if card.get("combatOption", {}).get("lethal", false) else 0)
