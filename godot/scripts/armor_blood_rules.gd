class_name ArmorBloodRules
extends RefCounted
## 月夜幻响：armor-derived power, realm durability, damage replacement and recovery.

static func role(unit: Dictionary) -> String:
	return str(ContentLoader.runtime_unit_def(unit).get("armorBloodRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0

static func armor_power(gs, unit: Dictionary) -> int:
	if not active(unit): return 0
	var armor := int(unit.get("shield", 0))
	var power := 0
	if role(unit) == "whale": power += armor if unit.get("awakened", false) else (1 if armor > 0 else 0)
	if int(unit.get("whaleGiftTurn", -1)) == gs.turn_counter: power += 1 if armor > 0 else 0
	return power

static func armor_changed(gs, unit: Dictionary) -> void:
	gs.VerifiedRules.MonkCleaner.armor_changed(gs, unit)
	if role(unit) == "whale" or unit.has("whaleGiftTurn"): gs._recalc(unit)

static func refresh(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if role(unit) == "whale" or unit.has("whaleGiftTurn"): gs._recalc(unit)

static func healing_recorded(gs) -> void:
	# Enhancement belongs to the copies in either player's hand at this event.
	for p in gs.players:
		for inst in p.hand:
			if ContentLoader.card_def(str(inst.definitionId)).get("bloodRage", false): inst.bloodRage = int(inst.get("bloodRage", 0)) + 1

static func avatar_healed(gs, owner: int, amount: int, source_index: int) -> void:
	if amount <= 0 or gs.winner >= 0: return
	for idx in gs.player(owner).units.size():
		if idx != source_index: continue
		var unit: Dictionary = gs.player(owner).units[idx]
		if role(unit) != "vampire" or not active(unit): continue
		var gain := mini(5, amount) if unit.get("awakened", false) else 1
		unit.bloodGainedPower = int(unit.get("bloodGainedPower", 0)) + gain
		gs._grow_unit(unit, gain, 0)
		gs._grant_unit_armor(unit, gain)
		gs.VerifiedRules.event(gs, "blood-growth", {"player": owner, "uid": unit.uid, "healed": amount, "amount": gain})

static func heal(gs, owner: int, amount: int) -> void:
	# Triggered recovery and its triggered damage are abilities, not additional
	# damage packets of the spell whose resolution is currently suspended.
	var context: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	gs._heal_avatar(owner, amount)
	gs._card_effect_context = context

static func spell_damage(gs, source_owner: int, src: int, amount: int) -> void:
	if amount <= 0 or gs.winner >= 0: return
	var context: Dictionary = gs._card_effect_context
	if context.is_empty() or source_owner != int(context.playerIndex) or src != int(context.sourceIndex): return
	var card: Dictionary = context.get("cardOverride", ContentLoader.card_def(str(context.get("definitionId", ""))))
	if ContentLoader.is_spell(card) and card.get("bloodSpellLifeSteal", false): heal(gs, source_owner, amount)

static func traits(gs, owner: int, src: int) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[src]
	return {"bloodLifeSteal": gs.VerifiedRules.Combat.has(unit, "lifesteal"), "bloodEmbrace": unit.get("bloodEmbrace", []).filter(func(e): return int(e.turn) == gs.turn_counter).duplicate(true)}

static func combat_dealt(gs, owner: int, result: Dictionary, options: Dictionary) -> void:
	var amount := int(result.get("transferredDealt", result.get("dealt", result.get("damage", 0))))
	if amount <= 0 or gs.winner >= 0: return
	# The keyword does not stack with another grant of the same keyword.
	if options.get("bloodLifeSteal", false) and not options.get("lifeSteal", false): heal(gs, owner, amount)
	for grant in options.get("bloodEmbrace", []):
		if gs.winner >= 0: break
		heal(gs, int(grant.player), amount)

static func take_transfer(unit: Dictionary) -> bool:
	var pending: bool = unit.get("bloodTransfer", false)
	unit.erase("bloodTransfer")
	return pending

static func transfer(gs, victim: int, unit: Dictionary, amount: int, owner: int, src: int, combat: bool = false) -> Dictionary:
	# The original unit event already applied source damage modifiers.
	var dealt: int = gs._damage_avatar(victim, amount, owner, src, false, combat, true)
	gs.VerifiedRules.event(gs, "blood-transfer", {"player": victim, "uid": unit.uid, "amount": amount, "dealt": dealt, "sourcePlayer": owner})
	return {"damage": 0, "dealt": 0, "transferredDealt": dealt, "knocked": false, "overkill": 0}

static func damaged(gs, owner: int, idx: int, amount: int) -> void:
	if amount <= 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm") == "whale-guard" and int(realm.hp) > 0:
			gs._grant_unit_armor(unit, 1)
			gs.VerifiedRules.event(gs, "realm-guard", {"player": owner, "uid": unit.uid, "realm": realm.uid})

static func protects_avatar(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "whale-treasure" and int(r.hp) > 0)

static func realm_veil(gs, owner: int) -> bool:
	return gs.player(owner).units.any(func(u): return active(u) and u.get("formRules", {}).get("whaleRealmVeil", false))

static func damage_realm(gs, owner: int, amount: int) -> void:
	var realms: Array = gs.player(owner).realms
	if amount <= 0 or realms.is_empty(): return
	# The first placed realm bears the entire packet. Excess never spills into
	# the next realm. Snapshot protection before removing a treasure this way.
	var realm: Dictionary = realms[0]
	realm.hp = maxi(0, int(realm.hp) - amount)
	gs.VerifiedRules.event(gs, "realm-durability", {"player": owner, "realm": str(realm.get("uid", "")), "amount": amount, "remaining": realm.hp})
	if int(realm.hp) == 0:
		gs.VerifiedRules.Huang.destroy(gs, owner, realm, "破碎")
	gs.VerifiedRules.MonkCleaner.refresh(gs)

static func form_entered(gs, owner: int, src: int, _card: Dictionary) -> void:
	form_turn_start(gs, owner, src)

static func form_turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit) or gs.player(owner).realms.is_empty(): return
	var value := int(unit.get("formRules", {}).get("whaleRealmArmor", 0))
	if value <= 0: return
	for target in (gs.player(owner).units if unit.get("formRules", {}).get("whaleTeamArmor", false) else [unit]): gs._grant_unit_armor(target, value)

static func turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit) and role(unit) == "whale" and unit.get("awakened", false): gs._grant_unit_armor(unit, gs.player(owner).realms.size())

static func end_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("whaleGiftTurn", -1)) <= gs.turn_counter: unit.erase("whaleGiftTurn")
			if unit.has("bloodEmbrace"):
				unit.bloodEmbrace = unit.bloodEmbrace.filter(func(e): return int(e.turn) > gs.turn_counter)
	refresh(gs)

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("bloodGainedPower", 0))
	unit.erase("bloodGainedPower")
	for key in ["whaleGiftTurn", "bloodTransfer", "bloodEmbrace"]: unit.erase(key)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var view := card.duplicate(true)
	if view.get("bloodRage", false):
		view.value = 1 + int(inst.get("bloodRage", 0))
		view.effects[0].value = view.value
		view.text += "\n当前伤害%d（此手牌已增强%d次）。" % [int(view.value), int(inst.get("bloodRage", 0))]
	if view.get("whaleOpen", false):
		var count: int = gs.player(owner).realms.size()
		view.value = 1 + count
		view.effects[0].value = view.value
		view.combatOption.shield = 1 + count
		view.text += "\n当前幻境%d：+%d力量、+%d护甲。" % [count, 1 + count, 1 + count]
	if view.get("bloodScent", false) and int(gs.player(owner).avatarHp) == 30:
		view.combatOption.immuneCombat = true
		view.text += "\n已增强：免疫战斗伤害。"
	if ContentLoader.is_spell(view) and ("lifesteal" in view.get("keywords", []) or gs.player(owner).units.any(func(u): return active(u) and u.get("formRules", {}).get("bloodSpellLifeSteal", false))):
		view.bloodSpellLifeSteal = true
		if not "lifesteal" in view.get("keywords", []):
			view.bloodAuraLifeSteal = true
			view.keywords.append("lifesteal")
			view.text += "\n猩红之月：吸血。"
	return view

static func card_started(gs, owner: int, card: Dictionary) -> void:
	if not ContentLoader.is_spell(card): return
	var intrinsic: bool = not card.get("bloodAuraLifeSteal", false) and "lifesteal" in card.get("keywords", [])
	card.bloodSpellLifeSteal = intrinsic or gs.player(owner).units.any(func(u): return active(u) and u.get("formRules", {}).get("bloodSpellLifeSteal", false))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"armor-blood-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"whale-shield":
			if target.is_empty() or target.uid == unit.uid: return true
			target.whaleGiftTurn = gs.turn_counter
			gs._grant_unit_armor(target, 4)
			gs._recalc(target)
		"blood-shield":
			if not target.is_empty(): target.bloodTransfer = true
		"blood-rage":
			var amount := int(effect.value) + int(card.get("foxHandDamageBonus", 0))
			if str(target_id).begins_with("avatar-"): gs._damage_avatar(int(str(target_id).trim_prefix("avatar-")), amount, owner, src)
			elif not target.is_empty():
				for side in 2:
					var idx: int = gs._unit_index_by_uid(side, target.uid)
					if idx >= 0: gs._damage_unit(side, idx, amount, owner, src)
		"blood-embrace":
			if target.is_empty(): return true
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target.uid)
				if idx < 0: continue
				gs._damage_unit(side, idx, 1 + int(card.get("foxHandDamageBonus", 0)), owner, src)
				if int(target.hp) > 0:
					if not target.has("bloodEmbrace"): target.bloodEmbrace = []
					target.bloodEmbrace.append({"player": owner, "turn": gs.turn_counter})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("armorBloodRules", false): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
	match str(card.get("effect", "")):
		"blood-shield":
			if not ally.is_empty(): return 35 + int(ally.attack) * 2 if int(gs.player(owner).avatarHp) > 10 else -100
			if not enemy.is_empty(): return 65 + int(gs.player(owner).units[src].attack) * 3 if int(enemy.front) == 1 else -100
		"blood-embrace": return 35 + int(ally.attack) * 5 if not ally.is_empty() and int(ally.hp) > 1 and int(gs.player(owner).avatarHp) < 30 else -100
		"whale-shield": return 40 + int(ally.attack) * 2 if not ally.is_empty() else -100
		"blood-rage": return 50 + int(card.value) * 4 if not enemy.is_empty() or str(target_id) == "avatar-%d" % (1 - owner) else -100
		"realm": return 65 if card.get("realm", {}).get("nativeRealm") == "whale-guard" else 80
		"armor-blood-awaken": return 65
		"assault": return 45 + int(card.value) * 5
		"form": return 55 if gs.player(owner).units[src].get("form", {}).get("cardId") != card.id else -100
	return -100
