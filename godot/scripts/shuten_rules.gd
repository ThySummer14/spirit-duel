class_name ShutenRules
extends RefCounted
## Rage is caused by damage events; form body, turn history and survival are
## separate states. Damage history includes the part prevented by unyielding.

static func is_source(unit: Dictionary) -> bool:
	return bool(ContentLoader.runtime_unit_def(unit).get("damageRage", false))

static func damage_this_turn(gs, unit: Dictionary) -> int:
	return int(unit.get("shutenTurnDamage", 0)) if int(unit.get("shutenDamageTurn", -1)) == gs.turn_counter else 0

static func friendly_damage_this_turn(gs, unit: Dictionary) -> bool:
	return int(unit.get("shutenDamageTurn", -1)) == gs.turn_counter and bool(unit.get("shutenFriendlyDamage", false))

static func record_damage(gs, owner: int, src: int, amount: int, source_player: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not is_source(unit) or amount <= 0: return
	if int(unit.get("shutenDamageTurn", -1)) != gs.turn_counter:
		unit.shutenDamageTurn = gs.turn_counter
		unit.shutenTurnDamage = 0
		unit.shutenFriendlyDamage = false
	unit.shutenTurnDamage = int(unit.shutenTurnDamage) + amount
	if source_player == owner: unit.shutenFriendlyDamage = true
	gs.VerifiedRules.event(gs, "shuten-damage-history", {"player": owner, "uid": unit.uid, "amount": amount, "total": unit.shutenTurnDamage, "friendly": source_player == owner})
	# Non-permanent rage cannot remain on a knocked-out unit. The separate
	# turn history survives, since a revival does not undo received damage.
	if int(unit.hp) <= 0 or int(unit.level) < 1: return
	var gain := amount if unit.awakened else 1
	unit.shutenRageGrowth = int(unit.get("shutenRageGrowth", 0)) + gain
	gs._grow_unit(unit, gain, 0)
	gs.VerifiedRules.event(gs, "shuten-rage", {"player": owner, "uid": unit.uid, "amount": gain, "awakened": unit.awakened})
	gs._log("%s 受到伤害，获得%d点力量。" % [unit.name, gain], gs.TONE_CARD)

static func describe_card(gs, card: Dictionary, unit: Dictionary) -> Dictionary:
	if not card.get("shutenRules", false): return card
	var view := card.duplicate(true)
	if card.get("effect") == "shuten-night-parade":
		var amount := damage_this_turn(gs, unit)
		view.value = amount
		view.text = "瞬发。对其他所有式神各造成%d点伤害。X为酒吞童子本回合所受伤害之和（当前%d）。" % [amount, amount]
		view.effects[0].value = amount
	elif card.get("shutenFriendlyEnhance", false):
		var enhanced := friendly_damage_this_turn(gs, unit)
		view.value = 4 if enhanced else 2
		view.effects[0].value = view.value
		view.text = "本次战斗+%d力量。若本回合酒吞童子受到过己方伤害，此牌额外+2力量。%s" % [view.value, "条件已满足。" if enhanced else "条件未满足。"]
	return view

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not is_source(unit): return
	unit.shutenFormUnyielding = bool(card.get("formRules", {}).get("shutenUnyielding", false))
	if unit.shutenFormUnyielding:
		gs.VerifiedRules.event(gs, "shuten-unyielding", {"player": owner, "uid": unit.uid, "card": card})

static func has_unyielding(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and bool(unit.get("shutenFormUnyielding", false))

static func consume_unyielding(unit: Dictionary) -> void:
	unit.shutenFormUnyielding = false

static func minimum_hp(gs, unit: Dictionary) -> int:
	return 1 if int(unit.get("shutenHowlTurn", -1)) == gs.turn_counter and int(unit.get("hp", 0)) > 0 else 0

static func end_turn(gs, _owner: int) -> void:
	for player in gs.players:
		for unit in player.units:
			if int(unit.get("shutenHowlTurn", -1)) == gs.turn_counter:
				unit.erase("shutenHowlTurn")
				gs.VerifiedRules.event(gs, "shuten-howl-expired", {"uid": unit.uid})

static func knocked_out(unit: Dictionary) -> void:
	if not is_source(unit): return
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("shutenRageGrowth", 0))
	unit.erase("shutenRageGrowth")
	unit.erase("shutenHowlTurn")
	unit.erase("shutenFormUnyielding")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary) -> bool:
	var source: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"shuten-self-damage": gs._damage_unit(owner, src, int(effect.get("value", 1)), owner)
		"shuten-night-parade":
			# Snapshot X once. Damage/death of other units during the spell cannot
			# turn later targets into a different damage wave.
			var amount := damage_this_turn(gs, source)
			for victim in 2:
				for idx in gs.player(victim).units.size():
					if victim == owner and idx == src: continue
					gs._damage_unit(victim, idx, amount, owner)
		"shuten-howl":
			source.shutenHowlTurn = gs.turn_counter
			gs.VerifiedRules.event(gs, "shuten-howl", {"player": owner, "uid": source.uid, "card": card})
		"shuten-awaken":
			source.awakened = true
			source.passive_hooks = []
			gs._grow_unit(source, int(effect.value.attack), int(effect.value.hp))
			gs.VerifiedRules.event(gs, "shuten-awakened", {"player": owner, "uid": source.uid, "card": card})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("shutenRules", false): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var source: Dictionary = gs.player(owner).units[src]
	match str(card.get("effect", "")):
		"shuten-self-damage": return -100 if int(source.hp) <= int(card.value) and int(source.shield) == 0 and not source.get("barrier", false) and not has_unyielding(source) and minimum_hp(gs, source) == 0 else 45
		"shuten-night-parade":
			var amount := damage_this_turn(gs, source)
			if amount <= 0: return -100
			var score := 0
			for victim in 2:
				for idx in gs.player(victim).units.size():
					if victim == owner and idx == src: continue
					var unit: Dictionary = gs.player(victim).units[idx]
					if int(unit.hp) <= 0 or unit.get("barrier", false): continue
					var dealt := maxi(0, amount - int(unit.shield))
					var value := mini(dealt, int(unit.hp)) * 3
					if dealt >= int(unit.hp) and not unit.unyielding and not has_unyielding(unit): value += 20 + int(unit.attack)
					score += value if victim != owner else -value
			return score
		"shuten-howl": return 54 if int(source.front) > 0 and minimum_hp(gs, source) == 0 and int(source.hp) <= 3 else -100
		"shuten-awaken": return 58 if not source.awakened else 25
		"form": return 54 + maxi(0, int(source.maxHp) - int(source.hp)) * 3
	# Generic combat scoring already reads the dynamic +2/+4 and target.
	return null
