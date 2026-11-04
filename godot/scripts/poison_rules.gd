class_name PoisonRules
extends RefCounted
## Classic armor break belongs to 清姬/跳跳弟弟. It is not the later 中毒 status.

static func role(unit: Dictionary) -> String:
	return str(ContentLoader.runtime_unit_def(unit).get("armorBreakRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) >= 1

static func convert_damage(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> bool:
	if amount <= 0 or owner < 0 or src < 0 or src >= gs.player(owner).units.size(): return false
	var source: Dictionary = gs.player(owner).units[src]
	if role(source) != "snake" or not active(source) or gs.VerifiedRules.ArmorBreak.amount(gs, victim, idx) > 0: return false
	gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, amount)
	gs.VerifiedRules.event(gs, "damage-to-armor-break", {"player": owner, "uid": source.uid, "victimPlayer": victim, "target": "" if idx < 0 else gs.player(victim).units[idx].uid, "amount": amount})
	return true

static func damaged(gs, victim: int, idx: int, owner: int, src: int, amount: int, combat: bool) -> void:
	if amount <= 0: return
	var unit: Dictionary = gs.player(victim).units[idx]
	# Snapshot before possible lethal damage removes the form; lethal hits still
	# satisfy 尸毒体质 but never resurrect the source via its awakening.
	var form: Dictionary = unit.get("formRules", {}).duplicate(true)
	if role(unit) == "jumper" and int(unit.level) >= 1:
		gs.VerifiedRules.ArmorBreak.give(gs, victim, idx, victim, idx, amount)
		if unit.awakened:
			gs.VerifiedRules.Glutton.record_permanent(unit,0,1)
			gs._grow_unit(unit, 0, 1)
			gs.VerifiedRules.event(gs, "jumper-health-growth", {"player": victim, "uid": unit.uid, "amount": 1})
	if combat and form.get("breakCombatAttacker", false) and owner >= 0 and src >= 0:
		gs.VerifiedRules.ArmorBreak.give(gs, victim, idx, owner, src, 3)
	if form.get("corpseThresholds", false):
		if amount >= 6:
			for enemy in gs.player(1 - victim).units.size(): gs.VerifiedRules.ArmorBreak.give(gs, victim, idx, 1 - victim, enemy, 3)
			gs.VerifiedRules.ArmorBreak.give(gs, victim, idx, 1 - victim, -1, 3)
		if amount >= 15: gs.VerifiedRules.ArmorBreak.give(gs, victim, idx, 1 - victim, -1, 10)

static func power_reduction(gs, owner: int, unit: Dictionary) -> int:
	var total := 0
	for source in gs.player(1 - owner).units:
		if active(source) and source.get("formRules", {}).get("breakWeakensEnemy", false): total += int(unit.get("armorBreak", 0))
	return total

static func refresh_all(gs) -> void:
	for owner in gs.players.size():
		for unit in gs.player(owner).units:
			if int(unit.get("poisonAuraReduction", 0)) > 0 or power_reduction(gs, owner, unit) > 0: gs._recalc(unit)

static func preserves(gs, owner: int, idx: int) -> bool:
	if idx >= 0 and active(gs.player(owner).units[idx]) and gs.player(owner).units[idx].get("formRules", {}).get("retainOwnArmorBreak", false): return true
	for source in gs.player(1 - owner).units:
		if active(source) and source.awakened and role(source) == "snake": return true
	return false

static func turn_start(gs, owner: int) -> void:
	# Enhancement is earned by copies already in hand at the event, not later draws.
	if gs.front_index(owner) >= 0:
		for entry in gs.player(owner).hand:
			if ContentLoader.card_def(str(entry.definitionId)).get("poisonFountain", false): entry.poisonInstant = true
	for src in gs.player(1 - owner).units.size():
		var source: Dictionary = gs.player(1 - owner).units[src]
		if not active(source) or not source.get("formRules", {}).get("breakEnemyTurnStart", false): continue
		for idx in gs.player(owner).units.size(): gs.VerifiedRules.ArmorBreak.give(gs, 1 - owner, src, owner, idx, 1)
		gs.VerifiedRules.ArmorBreak.give(gs, 1 - owner, src, owner, -1, 1)
	refresh_all(gs)

static func end_turn(gs, owner: int) -> void:
	for src in gs.player(1 - owner).units.size():
		var source: Dictionary = gs.player(1 - owner).units[src]
		if active(source) and source.get("formRules", {}).get("breakEnemyFrontAtEnd", false):
			var idx: int = gs.front_index(owner)
			if idx >= 0: gs.VerifiedRules.ArmorBreak.give(gs, 1 - owner, src, owner, idx, 2)
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("poisonShieldTurn", -1)) <= gs.turn_counter: unit.erase("poisonShieldTurn")

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var amount := int(card.get("formRules", {}).get("entryArmorBreak", 0))
	if amount > 0: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, owner, src, amount)
	refresh_all(gs)

static func describe_card(gs, owner: int, entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("poisonRules", false): return card
	var view := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	if src < 0: return view
	var amount: int = gs.VerifiedRules.ArmorBreak.amount(gs, owner, src)
	if card.get("effect") == "poison-snake-strike":
		view.poisonInstance = entry.duplicate(true)
		view.value = 2
		view.snakeReturns = not entry.get("snakeReturned", false)
		view.text = "瞬发。对一个式神造成2点伤害。" + ("使用后将此牌回手并失去此能力。" if view.snakeReturns else "此牌已失去回手能力。")
	if card.get("poisonFountain", false):
		if entry.get("poisonInstant", false) and not view.keywords.has("instant"): view.keywords.append("instant")
		view.text += "\n当前转移破甲：%d%s。" % [amount, " · 已增强瞬发" if entry.get("poisonInstant", false) else ""]
	if card.get("effect") == "poison-stiff":
		view.value = amount
		view.text += "\n当前本次力量加成：%d。" % amount
	return view

static func transfer_before_combat(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> void:
	if idx < 0 or not options.get("transferOwnArmorBreak", false): return
	var amount: int = gs.VerifiedRules.ArmorBreak.consume(gs, owner, src)
	gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, amount)
	gs.VerifiedRules.event(gs, "armor-break-transferred", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": gs.player(victim).units[idx].uid, "amount": amount})

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary) -> void:
	if idx < 0 or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	var source: Dictionary = gs.player(owner).units[src]
	if int(source.get("poisonShieldTurn", -1)) == gs.turn_counter: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, 3)

static func avatar_response(gs, frame: Dictionary, power: int, options: Dictionary) -> bool:
	var owner := int(frame.playerIndex)
	var victim := int(options.get("combatVictim", 1-owner))
	var src := int(frame.sourceIndex)
	var continuation := frame.duplicate(true)
	continuation.kind = "combat-hit"
	continuation.defenderIndex = -1
	continuation.power = power
	continuation.attackSnapshot = int(gs.player(owner).units[src].attack)
	continuation.powerMultiplier = 2 if frame.crit else 1
	continuation.options = options.duplicate(true)
	continuation.combatId = gs.next_resolution_id
	gs.next_resolution_id += 1
	return gs.VerifiedRules.automatic_response(gs, victim, "avatar-attacked", "avatar-%d" % victim, continuation)

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
	if not card.get("poisonGuard", false): return false
	var source: Dictionary = gs.player(owner).units[src]
	if not active(source) or gs.VerifiedRules.Bingyong.replacement_blocked(gs, owner, source): return true
	for frame in gs.resolution_stack:
		if frame.get("kind") != "combat-hit" or int(frame.get("combatId", -1)) != combat_id: continue
		var entered: bool = int(source.front) == 0
		gs.VerifiedRules.Xuenv.clear_wall(gs, owner)
		var movement_old: Array = []
		for i in gs.player(owner).units.size(): movement_old.append({"idx": i, "front": int(gs.player(owner).units[i].front)})
		for unit in gs.player(owner).units: unit.front = 1 if unit.uid == source.uid else 0
		for old in movement_old: gs.VerifiedRules.Movement.moved(gs, owner, int(old.idx), int(old.front))
		if entered:
			gs._fire_hooks(owner, src, "unit-entered-front", {})
			gs._run_form_hooks(owner, src, "unit-entered-front", {})
		frame.defenderIndex = src
		frame.erase("avatarResponsePending")
		gs.VerifiedRules.ArmorBreak.respond_combat(gs, combat_id, owner, src, card)
		frame.kind = "poison-guard-target-response"
		gs.VerifiedRules.event(gs, "unit-moved", {"player": owner, "uid": source.uid, "front": 1})
		gs.VerifiedRules.event(gs, "poison-guard", {"player": owner, "uid": source.uid, "card": card})
		break
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") == "poison-guard-target-response":
		frame.kind = "combat-hit"
		var defender_owner := int(frame.options.get("combatVictim", 1-int(frame.playerIndex)))
		var defender: Dictionary = gs.player(defender_owner).units[int(frame.defenderIndex)]
		if not gs.VerifiedRules.automatic_response(gs, defender_owner, "unit-attacked", defender.uid, frame): gs._resolve_combat_hit(frame)
		return true
	if frame.get("kind") != "combat-hit" or int(frame.get("defenderIndex", 0)) >= 0: return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var source: Dictionary = gs.player(owner).units[src]
	if not active(source) or gs.winner >= 0: return true
	var options: Dictionary = frame.options
	var victim := int(options.get("combatVictim", 1-owner))
	gs.VerifiedRules.Light.avatar_attacked(gs, victim, owner)
	var hits := (2 if frame.combo or source.get("formRules", {}).get("extraFirstHit", false) else 1) + (1 if gs.VerifiedRules.SnowCrane.extra(source, int(gs.player(victim).get("avatarFrozen", 0)) > 0) else 0)
	gs.VerifiedRules.event(gs, "combat-hit", {"player": owner, "uid": source.uid, "target": ""})
	for step in hits:
		if gs.winner >= 0 or not active(source): break
		var hit: Dictionary = gs.VerifiedRules.Combat.strike(gs, owner, src, victim, -1, int(frame.power), options)
		if hits > 1: gs._record_combat_strike(owner, src, victim, -1, hit, step, options.get("combatCard", {}))
		if int(hit.damage) > 0 and int(options.get("countdownOnAvatarDamage", 0)) > 0:
			gs.VerifiedRules.reduce_countdown(gs, owner, src, int(options.countdownOnAvatarDamage), owner if options.has("combatCard") else -1)
	gs._finish_combat(owner, src, {}, bool(frame.fromReserve), options, 0)
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	var enemy := 1 - owner
	match str(effect.get("action", "")):
		"poison-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"poison-punch", "poison-stiff":
			var punch: bool = effect.action == "poison-punch"
			if punch: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, owner, src, 2)
			var bonus: int = 0 if punch else gs.VerifiedRules.ArmorBreak.amount(gs, owner, src)
			var options: Dictionary = card.get("combatOption", {}).duplicate(true)
			options.combatCard = card.duplicate(true)
			options.transferOwnArmorBreak = punch
			gs._record("assault", {"unit": src, "target": target_id, "bonus": bonus}, owner)
			gs._resolve_combat(owner, src, bonus, gs._kw(card, "pierce"), gs._kw(card, "remote"), gs._kw(card, "combo"), gs._kw(card, "first-strike"), target_id, gs._kw(card, "crit"), options)
		"poison-fountain":
			var amount: int = gs.VerifiedRules.ArmorBreak.consume(gs, owner, src)
			for idx in gs.player(enemy).units.size(): gs.VerifiedRules.ArmorBreak.give(gs, owner, src, enemy, idx, amount)
		"poison-snake-strike":
			if target.is_empty() or int(target.hp) <= 0: return true
			var victim: int = owner if gs._unit_index_by_uid(owner, target.uid) >= 0 else enemy
			var idx: int = gs._unit_index_by_uid(victim, target.uid)
			var returns: bool = not card.get("poisonInstance", {}).get("snakeReturned", false)
			gs._damage_unit(victim, idx, int(card.value) + int(card.get("foxHandDamageBonus", 0)), owner, src)
			if returns and not card.get("poisonInstance", {}).is_empty():
				var entry: Dictionary = card.poisonInstance.duplicate(true)
				entry.snakeReturned = true
				if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(entry)
				gs.VerifiedRules.event(gs, "snake-strike-returned", {"player": owner, "uid": unit.uid, "amount": 2, "card": card})
		"poison-toxin":
			for idx in gs.player(enemy).units.size(): gs._damage_unit(enemy, idx, 2 + int(card.get("foxHandDamageBonus", 0)), owner, src)
			gs._damage_avatar(enemy, 2 + int(card.get("foxHandDamageBonus", 0)), owner, src)
		"poison-scorch":
			for victim in 2:
				if str(target_id) == "avatar-%d" % victim: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, -1, 2)
				elif not target.is_empty():
					var idx: int = gs._unit_index_by_uid(victim, target.uid)
					if idx >= 0: gs.VerifiedRules.ArmorBreak.give(gs, owner, src, victim, idx, 2)
			# Membership is tested after the grant, at each individual damage event.
			for idx in gs.player(enemy).units.size():
				if gs.VerifiedRules.ArmorBreak.amount(gs, enemy, idx) > 0: gs._damage_unit(enemy, idx, 3 + int(card.get("foxHandDamageBonus", 0)), owner, src)
			if gs.VerifiedRules.ArmorBreak.amount(gs, enemy, -1) > 0: gs._damage_avatar(enemy, 3 + int(card.get("foxHandDamageBonus", 0)), owner, src)
		"poison-shield":
			if target.is_empty() or int(target.hp) <= 0: return true
			gs._grant_unit_armor(target, 2)
			target.poisonShieldTurn = gs.turn_counter
		_: return false
	refresh_all(gs)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("poisonRules", false): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var unit: Dictionary = gs.player(owner).units[src]
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
	var amount: int = gs.VerifiedRules.ArmorBreak.amount(gs, owner, src)
	match str(card.get("effect", "")):
		"poison-snake-strike": return 60 + int(card.value) * 3 + (25 if int(enemy.get("armorBreak", 0)) > 0 else 0) if not enemy.is_empty() else -100
		"poison-scorch": return 70 if not enemy.is_empty() or str(target_id) == "avatar-%d" % (1 - owner) else -100
		"poison-shield": return 35 + (15 if int(ally.get("front", 0)) == 1 else 0) if not ally.is_empty() else -100
		"poison-fountain": return -100 if amount == 0 else 40 + amount * 3
		"poison-awaken": return 75 if not unit.awakened else 5
		"form": return 55 if unit.get("form", {}).get("cardId") != card.id else -100
		"poison-punch", "poison-stiff": return 50 + amount * 3
	return null
