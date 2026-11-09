class_name YaodaoRules
extends RefCounted
## Source-owned avatar hits and kills; real combat cards stay real cards.

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("yaodaoFlurry", false)

static func permanent_swift(unit: Dictionary) -> bool:
	return is_source(unit) and unit.get("awakened", false) and not unit.get("coopFirstBlade", false)

static func avatar_damaged(gs, owner: int, src: int, victim: int, dealt: int) -> void:
	if dealt <= 0 or owner < 0 or victim == owner or src < 0 or src >= gs.player(owner).units.size(): return
	var source: Dictionary = gs.player(owner).units[src]
	if not is_source(source) or int(source.hp) <= 0 or int(source.level) < 1 or source.get("coopFirstBlade", false): return
	if source.awakened: source.yaodaoFreeCombatTurn = gs.turn_counter
	else: source.yaodaoInstantTurn = gs.turn_counter
	gs.VerifiedRules.event(gs, "yaodao-flurry", {"player": owner, "uid": source.uid, "free": source.awakened})

static func unit_killed(gs, owner: int, src: int, victim_owner: int, victim_idx: int) -> void:
	if owner < 0 or src < 0 or src >= gs.player(owner).units.size() or victim_idx < 0: return
	var source: Dictionary = gs.player(owner).units[src]
	if not is_source(source): return
	var victim: Dictionary = gs.player(victim_owner).units[victim_idx]
	if victim.get("summon", false) and not victim.get("countsAsShikigami", false): return
	source.yaodaoKills = int(source.get("yaodaoKills", 0)) + 1
	gs.VerifiedRules.event(gs, "yaodao-kill-history", {"player": owner, "uid": source.uid, "target": victim.uid, "count": source.yaodaoKills})

static func describe_card(gs, owner: int, definition: Dictionary) -> Dictionary:
	if definition.get("type") != "combat": return definition
	var src: int = gs._source_index(owner, definition)
	if src < 0: return definition
	var source: Dictionary = gs.player(owner).units[src]
	if not is_source(source): return definition
	var card := definition.duplicate(true)
	if card.get("yaodaoKillEnhancement", false):
		var kills := int(source.get("yaodaoKills", 0))
		var bonus := int(card.get("baseCombatAttack", 0)) + kills * 2
		card.value = bonus
		card.effects[0].value = bonus
		card.yaodaoKills = kills
		card.text = "本次战斗+%d力量、+2护甲。增强：本局游戏妖刀姬每消灭一个式神，此牌获得+2力量。已消灭%d个式神。" % [bonus, kills]
	if int(source.get("yaodaoInstantTurn", -1)) == gs.turn_counter:
		var keywords: Array = card.get("keywords", []).duplicate()
		if not keywords.any(func(k): return str(k).to_lower() == "instant"): keywords.append("instant")
		card.keywords = keywords
		card.text += "\n本回合获得瞬发。"
	if int(source.get("yaodaoFreeCombatTurn", -1)) == gs.turn_counter:
		card.cost = 0
		card.yaodaoFreeCombat = true
		card.text += "\n本回合不消耗鬼火。"
	return card

static func combat_finished(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
	if kills <= 0 or not options.get("yaodaoKillDraw", false): return
	# The 2022-01-26 official fix requires the draw to survive the source's
	# death to a kill-triggered projectile. Do not guard this on source HP.
	gs._draw(owner, kills)
	gs.VerifiedRules.event(gs, "yaodao-kill-draw", {"player": owner, "uid": gs.player(owner).units[src].uid, "count": kills})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"yaodao-awaken":
			var source: Dictionary = gs.player(owner).units[src]
			source.erase("coopFirstBlade")
			source.erase("coopFirstBladeTurn")
			source.awakened = true
			source.passive_hooks = []
			gs._grow_unit(source, int(effect.value.attack), int(effect.value.hp))
			gs.VerifiedRules.event(gs, "yaodao-awakened", {"player": owner, "uid": source.uid, "card": card})
		"yaodao-killing-intent":
			var p: Dictionary = gs.player(owner)
			var pool: Array = card.get("generatedCards", [])
			if pool.is_empty(): return true
			for i in int(effect.get("value", 3)):
				var id: String = str(pool[int(floor(gs.randf01() * pool.size()))])
				var generated := ContentLoader.card_def(id)
				var instance := {"instanceId": "%s-yaodao%d" % [p.id, gs.next_card_id], "definitionId": id}
				gs.next_card_id += 1
				if p.hand.size() >= int(gs.rules.maxHandSize):
					gs._log("手牌已满，获得的「%s」被烧毁。" % generated.name, gs.TONE_DANGER)
					continue
				p.hand.append(instance)
				gs._log("杀念获得「%s」。" % generated.name, gs.TONE_CARD)
				gs.VerifiedRules.event(gs, "card-generated", {"player": owner, "uid": p.units[src].uid, "card": generated})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, _target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return null
	var source: Dictionary = gs.player(owner).units[src]
	if card.get("effect") == "yaodao-awaken":
		return 68 if not source.awakened and not gs.player(owner).attackUsed else (42 if not source.awakened else 12)
	if card.get("effect") == "yaodao-killing-intent":
		var remaining: int = int(gs.rules.maxHandSize) - gs.player(owner).hand.size() + 1
		return -100 if remaining <= 0 else 35 + mini(remaining, 3) * 7
	if card.get("type") == "form" and card.get("formRules", {}).get("extraFirstHit", false):
		if source.get("formRules", {}).get("extraFirstHit", false) and int(source.hp) >= 6: return 15
		return 80
	if card.get("type") != "combat": return null
	var power := int(source.attack) + int(card.get("value", 0))
	var enemy: Dictionary = gs.front_unit(1 - owner)
	var hits := 2 if source.get("formRules", {}).get("extraFirstHit", false) else 1
	if enemy.is_empty():
		if power * hits >= int(gs.player(1 - owner).avatarHp) + int(gs.player(1 - owner).avatarArmor): return 1000
		return 45 + power * hits + (12 if not source.awakened and not gs.kw_usage(owner, "instant").get("used", false) else 0)
	var damage := power * hits - int(enemy.shield)
	if enemy.get("barrier", false): damage = power * maxi(0, hits - 1) - int(enemy.shield)
	var kills: bool = damage >= int(enemy.hp) and not (enemy.unyielding and int(enemy.hp) > 1)
	var immune: bool = card.get("combatOption", {}).get("immuneCombat", false)
	var early_kill: bool = hits > 1 and power >= int(enemy.hp) + int(enemy.shield) and not enemy.get("barrier", false) and not enemy.unyielding
	var dies: bool = not immune and not early_kill and int(enemy.attack) >= int(source.hp) + int(source.shield) + int(card.get("combatOption", {}).get("shield", 0))
	return 50 + power + (35 if kills else 0) + (12 if kills and card.get("combatOption", {}).get("yaodaoKillDraw", false) else 0) - (30 if dies else 0)
