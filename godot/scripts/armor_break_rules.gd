class_name ArmorBreakRules
extends RefCounted
## Armor and armor break cancel before acquiring a capped character status.
## Conversion replaces the effect with damage, which has no status-value cap.
const STATUS_LIMIT := 65535

static func capped_gain(current: int, requested: int) -> int:
	return mini(maxi(0, requested), maxi(0, STATUS_LIMIT - current))

static func armor_after_gain(armor: int, armor_break: int, requested: int) -> int:
	return armor + capped_gain(armor, maxi(0, requested - armor_break))

static func amount(gs, owner: int, idx: int) -> int:
	return int(gs.player(owner).get("avatarArmorBreak", 0)) if idx < 0 else int(gs.player(owner).units[idx].get("armorBreak", 0))

static func consume(gs, owner: int, idx: int) -> int:
	var value := amount(gs, owner, idx)
	if idx < 0: gs.player(owner).avatarArmorBreak = 0
	else:
		gs.player(owner).units[idx].armorBreak = 0
		gs.VerifiedRules.StarBear.consumed_break(gs.player(owner).units[idx],value)
		if not gs.VerifiedRules.DuskCycle.realms(gs, 1-owner, "peacock-mist").is_empty(): gs._recalc(gs.player(owner).units[idx])
	if value > 0:
		gs.VerifiedRules.event(gs, "armor-break-consumed", {"player": owner, "target": "" if idx < 0 else gs.player(owner).units[idx].uid, "amount": value})
		gs.VerifiedRules.Poison.refresh_all(gs)
	return value

static func give(gs, source_owner: int, source_idx: int, owner: int, idx: int, value: int, convert: bool = true) -> Dictionary:
	var empty := {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if value <= 0 or gs.winner >= 0: return empty
	if idx >= 0 and int(gs.player(owner).units[idx].hp) <= 0: return empty
	var source: Dictionary = gs.player(source_owner).units[source_idx] if source_idx>=0 else {"uid":"avatar-%d"%source_owner,"hp":0,"formRules":{}}
	var target := "" if idx < 0 else str(gs.player(owner).units[idx].uid)
	if convert and int(source.hp) > 0 and source.get("formRules", {}).get("armorBreakToDamage", false):
		gs.VerifiedRules.event(gs, "armor-break-converted", {"player": source_owner, "uid": source.uid, "target": target, "victimPlayer": owner, "amount": value})
		# Direct damage is already the replacement result. Do not run the combat
		# damage-to-poison conversion again (碧羽散华 + 毒蚀).
		if idx < 0:
			var dealt: int = gs._damage_avatar(owner, value, source_owner, source_idx)
			return {"damage": dealt, "dealt": dealt, "knocked": false, "overkill": 0}
		return gs._damage_unit(owner, idx, value, source_owner, source_idx)
	value+=gs.VerifiedRules.House.break_bonus(gs,source_owner,owner)
	# Applying armor break first removes armor, without touching barriers.
	# Only the remainder is an acquired armor-break status.
	var armor: int = int(gs.player(owner).get("avatarArmor", 0)) if idx < 0 else int(gs.player(owner).units[idx].shield)
	var cancelled := mini(value, armor)
	if idx < 0:
		gs.player(owner).avatarArmor = armor - cancelled
	else:
		var unit: Dictionary = gs.player(owner).units[idx]
		unit.shield = armor - cancelled
		gs.VerifiedRules.YanmieTrio.armor_removed(gs, owner, idx, cancelled)
		gs.VerifiedRules.StarBear.consumed_armor(unit,cancelled)
		unit.shieldExpires = maxi(0, int(unit.get("shieldExpires", 0)) - cancelled)
	if idx >= 0: gs.VerifiedRules.ArmorBlood.armor_changed(gs, gs.player(owner).units[idx])
	if cancelled > 0: gs.VerifiedRules.event(gs, "armor-cancelled", {"player": owner, "uid": target, "amount": cancelled})
	value -= cancelled
	value = capped_gain(amount(gs, owner, idx), value)
	if value <= 0: return empty
	if idx < 0: gs.player(owner).avatarArmorBreak = amount(gs, owner, idx) + value
	else: gs.player(owner).units[idx].armorBreak = amount(gs, owner, idx) + value
	gs._log("%s 获得%d破甲。" % [gs.player(owner).name + "的牌手" if idx < 0 else gs.player(owner).units[idx].name, value], gs.TONE_DANGER)
	gs.VerifiedRules.event(gs, "armor-break-gained", {"player": source_owner, "uid": source.uid, "target": target, "victimPlayer": owner, "amount": value})
	gs.VerifiedRules.Poison.refresh_all(gs)
	if idx >= 0:
		var victim: Dictionary = gs.player(owner).units[idx]
		if not gs.VerifiedRules.DuskCycle.realms(gs, 1-owner, "peacock-mist").is_empty(): gs._recalc(victim)
		gs.VerifiedRules.DuskCycle.armor_acquired(gs, owner, idx)
		gs.VerifiedRules.DragonFlow.break_gained(gs, owner, idx)
		# 'This turn's first gain' belongs to each enemy, including gains before
		# the form entered. Replacing the form cannot reset that fact.
		var first: bool = int(victim.get("armorBreakGainedTurn", -1)) != gs.turn_counter
		victim.armorBreakGainedTurn = gs.turn_counter
		if first:
			for i in gs.player(1 - owner).units.size():
				var observer: Dictionary = gs.player(1 - owner).units[i]
				var reduction := int(observer.get("formRules", {}).get("firstEnemyArmorBreakCountdown", 0))
				if int(observer.hp) > 0 and reduction > 0:
					gs.resolution_stack.append({"kind": "countdown-change", "playerIndex": 1 - owner, "sourceIndex": i, "delta": -reduction})
	return empty

static func prepare_combat(gs, enemy: int, idx: int, options: Dictionary) -> Dictionary:
	var result := options.duplicate(true)
	var marked := amount(gs, enemy, idx) > 0
	result.immuneCombat = options.get("immuneCombat", false) or (marked and options.get("immuneAgainstArmorBreak", false))
	result.lifeSteal = options.get("lifeSteal", false) or (marked and options.get("lifeStealAgainstArmorBreak", false))
	return result

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> void:
	if int(gs.player(owner).units[src].hp) <= 0: return
	var continuation: Dictionary = {}
	for frame in gs.resolution_stack:
		if frame.get("kind") == "combat-hit" and int(frame.get("combatId", -1)) == combat_id: continuation = frame
	if continuation.is_empty(): return
	continuation.defenderCombatCard = card.duplicate(true)
	if card.get("combatOption", {}).get("counterPierce", false): continuation.defenderPierce = true
	continuation.defenderBonus = int(continuation.get("defenderBonus", 0)) + int(card.value)
	if card.get("combatOption", {}).get("immuneCombat", false): continuation.defenderImmuneCombat = true
	var armor := int(card.get("combatOption", {}).get("shield", 0))
	gs._grant_unit_armor(gs.player(owner).units[src], armor)
	if card.get("combatOption", {}).get("convertCombatToArmorBreak", false):
		continuation.options.convertCombatToArmorBreak = true
	gs.VerifiedRules.event(gs, "combat-response-applied", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": card})

static func combat_damage(gs, source_owner: int, src: int, owner: int, idx: int, power: int, convert: bool, immune: bool = false, knockout_extra: int = -1, critical: bool = false) -> Dictionary:
	var empty := {"damage": 0, "dealt": 0, "knocked": false, "overkill": 0}
	if power < 0 or (power == 0 and (idx < 0 or not gs.VerifiedRules.Mianqiling.positive_zero(gs,owner,idx,source_owner,src,true))): return empty
	if not convert:
		var coop_redirected = gs.VerifiedRules.CoopLate.redirect_damage(gs, owner, idx, power, source_owner, src, knockout_extra, critical)
		if coop_redirected != null: return coop_redirected
	var transfer_pending: bool = idx >= 0 and gs.VerifiedRules.ArmorBlood.take_transfer(gs.player(owner).units[idx])
	if not convert:
		if gs.VerifiedRules.Poison.convert_damage(gs,source_owner,src,owner,idx,power): return empty
		var star_redirected=gs.VerifiedRules.StarBear.redirect(gs,owner,idx,power,source_owner,src,true,critical)
		if star_redirected!=null: return star_redirected
	if idx >= 0 and gs.VerifiedRules.OwlInsect.prevents_damage(gs,gs.player(owner).units[idx],source_owner,src): return empty
	if convert: return give(gs, source_owner, src, owner, idx, power)
	var preview_armor := 0 if gs.VerifiedRules.Combat.has(gs.player(source_owner).units[src], "penetration") else int(gs.player(owner).avatarArmor)
	if idx < 0 and gs.VerifiedRules.Light.prevents_avatar_damage(gs, owner, maxi(0, power + int(gs.player(owner).avatarArmorBreak) - preview_armor) * (2 if critical and owner != source_owner else 1)): return empty
	var redirected = gs.VerifiedRules.MonkCleaner.redirect(gs, owner, idx, power, source_owner, src, true, critical)
	if redirected != null: return redirected
	if immune and not transfer_pending:
		# A real damage event first consumes a barrier, then combat immunity
		# prevents damage without consuming armor or existing poison.
		if idx >= 0 and gs.player(owner).units[idx].get("barrier", false):
			return gs._damage_unit(owner, idx, power, source_owner, src, true, -1, transfer_pending, critical)
		gs.VerifiedRules.event(gs, "combat-immune", {"player": owner, "uid": "" if idx < 0 else gs.player(owner).units[idx].uid})
		return empty
	if idx < 0:
		var dealt: int = gs._damage_avatar(owner, power, source_owner, src, critical, true)
		return {"damage": dealt, "dealt": dealt, "knocked": false, "overkill": 0}
	return gs._damage_unit(owner, idx, power, source_owner, src, true, knockout_extra, transfer_pending, critical)

static func after_combat_damage(gs, owner: int, src: int, victim_owner: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	var dealt := int(result.get("dealt", result.damage))
	var leech := int(result.get("transferredDealt", dealt))
	if leech > 0 and options.get("lifeSteal", false) and gs.winner < 0:
		gs.VerifiedRules.ArmorBlood.heal(gs, owner, leech)
	if dealt <= 0: return
	if options.get("halfRemainingHpArmorBreak", false):
		var hp := int(gs.player(victim_owner).avatarHp) if idx < 0 else int(gs.player(victim_owner).units[idx].hp)
		give(gs, owner, src, victim_owner, idx, int(floor(hp / 2.0)))

static func resolve_action(gs, owner: int, src: int, effect: Dictionary, target: Dictionary) -> bool:
	var source: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"poison-countdown":
			var history := int(source.get("poisonTriggers", 0))
			var value := int(effect.value) + (history if effect.get("growsWithHistory", false) else 0)
			source.poisonTriggers = history + 1
			give(gs, owner, src, 1 - owner, -1, value)
		"apply-armor-break":
			match str(effect.get("target", "")):
				"enemy-avatar", "enemy-player": give(gs, owner, src, 1 - owner, -1, int(effect.value))
				"all-enemy-units":
					for i in gs.player(1 - owner).units.size(): give(gs, owner, src, 1 - owner, i, int(effect.value))
				"enemy-front":
					var idx: int = gs.front_index(1 - owner)
					if idx >= 0: give(gs, owner, src, 1 - owner, idx, int(effect.value))
				"source": give(gs, owner, src, owner, src, int(effect.value))
				_:
					if not target.is_empty():
						for p in 2:
							var idx: int = gs._unit_index_by_uid(p, target.uid)
							if idx >= 0: give(gs, owner, src, p, idx, int(effect.value))
		_: return false
	return true
