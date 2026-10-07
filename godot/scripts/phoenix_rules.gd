class_name PhoenixRules
extends RefCounted
## Source-owned spell damage, real avatar-hit history and spell-use abilities.

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.unit_def(str(unit.get("id", ""))).get("phoenixSpellTrigger", false)

static func bonus(unit: Dictionary) -> int:
	return int(unit.get("formRules", {}).get("nonCombatDamageBonus", 0)) if int(unit.get("hp", 0)) > 0 else 0

static func avatar_damaged(gs, owner: int, src: int, victim: int, dealt: int) -> void:
	if dealt <= 0 or owner < 0 or victim == owner or src < 0 or src >= gs.player(owner).units.size(): return
	var unit: Dictionary = gs.player(owner).units[src]
	if not is_source(unit): return
	unit.phoenixAvatarHits = int(unit.get("phoenixAvatarHits", 0)) + 1
	gs.VerifiedRules.event(gs, "phoenix-history", {"uid": unit.uid, "player": owner, "count": unit.phoenixAvatarHits})

static func damage_preview(card: Dictionary, unit: Dictionary) -> int:
	if not card.get("phoenixSpell", false): return 0
	var amount := int(card.get("phoenixBaseDamage", 0)) + bonus(unit)
	if card.get("phoenixEnhancement", false): amount += int(unit.get("phoenixAvatarHits", 0))
	return amount

static func describe_card(card: Dictionary, unit: Dictionary) -> Dictionary:
	if not card.get("phoenixSpell", false): return card
	var view := card.duplicate(true)
	var amount := damage_preview(card, unit)
	view.value = amount
	if card.get("phoenixEnhancement", false):
		view.text = "贯通。投射：造成%d点伤害。\n增强：本局游戏凤凰火每对敌方牌手造成一次伤害，此牌伤害+1。\n已对敌方牌手造成伤害%d次。" % [amount, int(unit.get("phoenixAvatarHits", 0))]
	elif card.get("effect") == "phoenix-ignite":
		view.text = "对一个式神造成%d点伤害，若击杀则再对它的牌手造成%d点伤害。" % [amount, amount]
	elif card.get("target") == "any-living-unit": view.text = "对一个式神造成%d点伤害。" % amount
	elif card.get("phoenixArea", false): view.text = "对所有敌方式神造成%d点伤害。" % amount
	else: view.text = "瞬发。对敌方牌手造成%d点伤害。" % amount
	return view

static func _avatar(gs, owner: int, src: int, victim: int, amount: int) -> int:
	return gs._damage_avatar(victim, amount, owner, src)

static func _projectile(gs, owner: int, src: int, amount: int, pierce: bool) -> void:
	var victim := 1 - owner
	var idx: int = gs.front_index(victim)
	if idx < 0:
		_avatar(gs, owner, src, victim, amount)
		return
	var target: Dictionary = gs.player(victim).units[idx]
	var barrier_overflow := maxi(0, amount - int(target.hp) - int(target.shield)) if target.get("barrier", false) else 0
	var hit: Dictionary = gs._damage_unit(victim, idx, amount, owner)
	# Overflow is allocated to the avatar independently of a unit's barrier.
	# The same damage must not receive the source's bonus a second time.
	var overflow := maxi(barrier_overflow, int(hit.get("overkill", 0)))
	if pierce and overflow > 0:
		_avatar(gs, owner, src, victim, overflow)

static func card_announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.get("type") != "spell" or gs.winner >= 0: return
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var triggers: Array = []
	for idx in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[idx]
		if not is_source(unit) or int(unit.hp) <= 0 or int(unit.level) < 1: continue
		if idx != src and not unit.awakened: continue
		var trigger := {"sourceIndex": idx, "uid": unit.uid}
		if idx == src and unit.get("formRules", {}).has("fortuneGenerate"):
			trigger.fortune = unit.formRules.fortuneGenerate.duplicate(true)
		triggers.append(trigger)
	if triggers.is_empty(): return
	# A used spell and the spell's successful effects are distinct events.
	# This independent ability frame survives removal of the card's frames.
	# LIFO: place it below card-complete, so normal spells resolve before it.
	var used := {"kind": "phoenix-spell-used", "playerIndex": owner, "triggers": triggers, "causeResolutionId": frame.resolutionId}
	for i in gs.resolution_stack.size():
		var pending: Dictionary = gs.resolution_stack[i]
		if pending.get("kind") == "card-complete" and pending.get("resolutionId") == frame.resolutionId:
			gs.resolution_stack.insert(i, used)
			return

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "phoenix-spell-used": return false
	var owner := int(frame.playerIndex)
	for trigger in frame.triggers:
		if gs.winner >= 0: break
		var idx := int(trigger.sourceIndex)
		var unit: Dictionary = gs.player(owner).units[idx]
		# The original FAQ explicitly confirms self-lethal Phoenix Fire/Ignite
		# still projects: source death cannot erase an already-created trigger.
		if unit.uid != trigger.uid: continue
		var ability := {"id": "phoenix-projectile", "name": "凤火投射", "unitId": unit.id, "type": "ability", "typeLabel": "基础能力", "level": unit.level, "cost": 0, "verifiedRules": true, "target": "auto", "text": "投射：造成%d点伤害。" % (1 + bonus(unit)), "effects": [{"action": "damage-enemy-front", "target": "auto", "value": 1 + bonus(unit)}]}
		gs.VerifiedRules.event(gs, "ability-trigger", {"player": owner, "uid": unit.uid, "card": ability, "reason": "使用法术牌"})
		var previous_context: Dictionary = gs._card_effect_context
		gs._card_effect_context = {"playerIndex": owner, "sourceIndex": idx, "cardOverride": ability, "affectedUnits": []}
		_projectile(gs, owner, idx, 1 + bonus(unit), false)
		gs._card_effect_context = previous_context
		if trigger.has("fortune") and gs.winner < 0:
			_generate_on_fortune(gs, owner, idx, trigger.fortune)
	return true

static func _generate_on_fortune(gs, owner: int, src: int, cfg: Dictionary) -> void:
	var success: bool = gs._roll_fortune(owner, {"fortune": {"sides": 6, "threshold": int(cfg.get("threshold", 4))}})
	var last: Dictionary = gs.kw_usage(owner, "fortune").last
	gs.VerifiedRules.event(gs, "phoenix-fortune", {"player": owner, "uid": gs.player(owner).units[src].uid, "roll": last.roll, "success": success})
	if not success: return
	var p: Dictionary = gs.player(owner)
	var card := ContentLoader.card_def(str(cfg.card))
	if p.hand.size() >= int(gs.rules.maxHandSize):
		gs._log("手牌已满，获得的「%s」被烧毁。" % card.name, gs.TONE_DANGER)
		return
	p.hand.append({"instanceId": "%s-c%d" % [p.id, gs.next_card_id], "definitionId": card.id})
	gs.next_card_id += 1
	gs.VerifiedRules.event(gs, "card-generated", {"player": owner, "uid": p.units[src].uid, "card": card})
	gs._log("%s 的出云获得「%s」。" % [p.units[src].name, card.name], gs.TONE_CARD)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var action := str(effect.get("action", ""))
	var unit: Dictionary = gs.player(owner).units[src]
	if action == "awaken-phoenix":
		unit.awakened = true
		gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		return true
	if not card.get("phoenixSpell", false): return false
	var amount := damage_preview(card, unit)
	match action:
		"damage-enemy-front": _projectile(gs, owner, src, amount, true)
		"damage":
			if effect.get("target") == "enemy-avatar": _avatar(gs, owner, src, 1 - owner, amount)
			elif effect.get("target") == "all-enemy-units":
				for idx in gs.player(1 - owner).units.size(): gs._damage_unit(1 - owner, idx, amount, owner)
			else:
				for victim in 2:
					var idx: int = gs._unit_index_by_uid(victim, target.get("uid", ""))
					if idx >= 0: gs._damage_unit(victim, idx, amount, owner)
		"phoenix-ignite":
			for victim in 2:
				var idx: int = gs._unit_index_by_uid(victim, target.get("uid", ""))
				if idx < 0: continue
				var hit: Dictionary = gs._damage_unit(victim, idx, amount, owner)
				if hit.knocked: _avatar(gs, owner, src, victim, amount)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0: return null
	var unit: Dictionary = gs.player(owner).units[src]
	if card.get("effect") == "awaken-phoenix": return 58 if not unit.awakened else 20
	if not card.get("phoenixSpell", false): return null
	var amount := damage_preview(card, unit)
	var score := 48 + amount
	if card.get("target") == "any-living-unit":
		if gs._unit_index_by_uid(owner, target_id) >= 0: return -100
		var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
		if target.is_empty(): return -100
		if target.get("barrier", false): return 25
		var damage := amount + int(target.get("armorBreak", 0)) - int(target.shield)
		var saved_by_unyielding: bool = target.unyielding and int(target.hp) > 1
		if damage >= int(target.hp) and not saved_by_unyielding: score += 38 + int(target.attack)
		if card.get("effect") == "phoenix-ignite" and damage >= int(target.hp) and not saved_by_unyielding:
			score += 12
			if amount >= int(gs.player(1 - owner).avatarHp) + int(gs.player(1 - owner).avatarArmor): score += 500
	elif card.get("phoenixArea", false):
		for target in gs.player(1 - owner).units:
			if int(target.hp) > 0 and not target.get("barrier", false): score += 8 + (15 if amount >= int(target.hp) + int(target.shield) else 0)
	else:
		var damage := amount
		var target: Dictionary = gs.front_unit(1 - owner)
		if card.get("phoenixEnhancement", false) and not target.is_empty():
			var poison := 0 if target.get("barrier", false) else int(target.get("armorBreak", 0))
			damage = maxi(0, amount + poison - int(target.hp) - int(target.shield))
		if damage >= int(gs.player(1 - owner).avatarHp) + int(gs.player(1 - owner).avatarArmor): score += 500
	return score - int(card.cost) * 3
