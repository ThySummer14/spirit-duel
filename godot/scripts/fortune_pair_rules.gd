class_name FortunePairRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")

static func role(unit: Dictionary) -> String:
	if unit.get("baseRulesSuppressed", false): return ""
	return str(ContentLoader.runtime_unit_def(unit).get("fortuneRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func sixes(gs, owner: int) -> int:
	return int(gs.player(owner).get("fortuneSixes", 0))

static func forced_die(gs, owner: int, source: int) -> int:
	if source >= 0:
		var unit: Dictionary = gs.player(owner).units[source]
		if role(unit) == "rabbit" and unit.get("nextFortuneSix", false):
			unit.erase("nextFortuneSix")
			return 6
	for unit in gs.player(owner).units:
		if active(unit) and unit.get("formRules", {}).get("alwaysSix", false): return 6
	return 0

static func record_die(gs, owner: int, value: int) -> void:
	var p: Dictionary = gs.player(owner)
	p.fortuneRollTotal = int(p.get("fortuneRollTotal", 0)) + value
	if not p.has("fortuneNumbers"): p.fortuneNumbers = []
	# JSON restores numeric array entries as floats; compare dice values rather
	# than Variant types so repeated faces cannot enhance 九莲宝灯 twice.
	if value >= 1 and value <= 6 and not p.fortuneNumbers.any(func(n): return int(n) == value): p.fortuneNumbers.append(value)
	if value == 6: p.fortuneSixes = sixes(gs, owner) + 1
	gs.VerifiedRules.BoxMaiden.die_rolled(gs,owner,value)
	gs.VerifiedRules.event(gs, "die-rolled", {"player": owner, "roll": value, "sixes": sixes(gs, owner)})

static func repeat_count(gs, owner: int) -> int:
	for unit in gs.player(owner).units:
		if active(unit) and role(unit) == "frog" and unit.awakened: return 2
	return 1

static func last_repeats(gs, owner: int) -> int:
	return int(gs.kw_usage(owner, "fortune").get("last", {}).get("effectRepeats", 1))

static func success(gs, owner: int) -> void:
	for unit in gs.player(owner).units:
		if not active(unit) or role(unit) != "frog": continue
		unit.frogBonusTurn = gs.turn_counter
		var growth := int(unit.get("formRules", {}).get("fortunePermanentPower", 0))
		if growth > 0: gs._grow_unit(unit, growth, 0)
		gs._recalc(unit)
	gs.VerifiedRules.Pine.fortune_success(gs,owner)

static func power(gs, unit: Dictionary) -> int:
	return 2 if active(unit) and role(unit) == "frog" and int(unit.get("frogBonusTurn", -1)) == gs.turn_counter else 0

static func turn_boundary(gs) -> void:
	for side in gs.players:
		for unit in side.units:
			if role(unit) == "frog": gs._recalc(unit)

static func end_turn(gs) -> void:
	for side in gs.players:
		for unit in side.units:
			var debuff := int(unit.get("fortuneForcedAttackDebuff", 0))
			if debuff <= 0: continue
			unit.temporaryAttack = int(unit.get("temporaryAttack", 0)) + debuff
			unit.erase("fortuneForcedAttackDebuff")
			gs._recalc(unit)

static func turn_start(gs, owner: int, src: int) -> void:
	var rabbit: Dictionary = gs.player(owner).units[src]
	if not active(rabbit) or role(rabbit) != "rabbit": return
	# Awakening repeats the whole fortune clause, including its own die roll.
	for attempt in (2 if rabbit.awakened else 1):
		if gs.winner >= 0: break
		if not gs.VerifiedRules.Light.roll(gs, owner, 6, 6, src): continue
		var copies := last_repeats(gs, owner)
		for copy in copies:
			for idx in gs.player(owner).units.size():
				if idx == src or gs.winner >= 0: continue
				gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1)
				var unit: Dictionary = gs.player(owner).units[idx]
				if int(unit.hp) > 0: gs._grow_unit(unit, 2 if rabbit.awakened else 1, 0)
			gs._resolve_resolution_stack()

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("fortunePair", false): return card
	var out := card.duplicate(true)
	var count := sixes(gs, owner)
	match str(card.get("fortuneEnhancement", "")):
		"sixes-projectile":
			out.value = 2 + count
			out.effects[0].value = out.value
		"sixes-blessing":
			out.value = {"attack": 3 if count >= 3 else 1, "hp": 3 if count >= 3 else 1}
			out.effects[0].value = out.value.duplicate()
		"sixes-unyielding": out.formRules.fortuneUnyielding = count >= 3
		"sixes-body", "distinct-body":
			var extra: int = count if card.fortuneEnhancement == "sixes-body" else gs.player(owner).get("fortuneNumbers", []).size()
			out.value.attack = int(card.value.attack) + extra
			out.value.hp = int(card.value.hp) + extra
			out.effects[0].value = out.value.duplicate()
	out.text += "\n本局已投出%d次6点；不同点数%d种。" % [count, gs.player(owner).get("fortuneNumbers", []).size()]
	return out

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.get("baseRulesSuppressed", false) and not card.get("paperTransform", false): restore(unit)
	if card.get("formRules", {}).get("fortuneUnyielding", false): unit.unyielding = true
	gs._recalc(unit)

static func restore(unit: Dictionary) -> void:
	if not unit.get("baseRulesSuppressed", false): return
	for key in unit.get("paperSavedModifiers", {}): unit[key] = unit.paperSavedModifiers[key]
	unit.passive_hooks = unit.get("paperSavedHooks", []).duplicate(true)
	unit.name = unit.get("paperSavedName", unit.name)
	unit.erase("baseRulesSuppressed")
	unit.erase("paperSavedHooks")
	unit.erase("paperSavedName")
	unit.erase("paperSavedModifiers")

static func transform(gs, owner: int, idx: int, small: bool) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if int(unit.hp) <= 0: return
	if not unit.get("baseRulesSuppressed", false):
		unit.paperSavedHooks = unit.get("passive_hooks", []).duplicate(true)
		unit.paperSavedName = unit.name
		unit.paperSavedModifiers = {}
		# The paper body replaces its visible modifiers. Keep original modifier
		# bookkeeping so the original owner's death cleanup can remove temporary
		# rage/training/healing growth exactly once when the paper is knocked out.
		for key in ["attackBonus", "maxHpBonus", "permanentAttack"]:
			if unit.has(key): unit.paperSavedModifiers[key] = unit[key]
	# Replacing a form uses its real leave hooks and removes its timer.
	gs.VerifiedRules.Forms.remove(gs, owner, idx, "戏谑套索变形")
	unit.attackBonus = 0
	unit.maxHpBonus = 0
	unit.erase("temporaryAttack")
	unit.erase("untilAttack")
	unit.erase("permanentAttack")
	unit.erase("cranePower")
	unit.erase("spellCountdown")
	gs.VerifiedRules.StarBear.consumed_armor(unit,int(unit.shield))
	gs.VerifiedRules.StarBear.consumed_break(unit,int(unit.armorBreak))
	unit.shield = 0
	unit.shieldExpires = 0
	unit.unyielding = false
	unit.barrier = false
	unit.brittle = 0
	unit.armorBreak = 0
	var body := 1 if small else 3
	var name := "小纸人" if small else "纸人"
	var token := {"id": "fortune-small-paper" if small else "fortune-paper", "name": name, "type": "form", "value": {"attack": body, "hp": body, "setBase": true}, "formRules": {}, "formAbility": "失去形态能力及初始、觉醒能力。", "paperTransform": true}
	gs._install_form(owner, idx, token)
	unit.name = name
	unit.baseRulesSuppressed = true
	unit.passive_hooks = []
	gs._recalc(unit)
	unit.hp = int(unit.maxHp)
	gs.VerifiedRules.event(gs, "paper-transformed", {"player": owner, "uid": unit.uid, "small": small, "card": token})

static func before_attack(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit) and unit.get("formRules", {}).get("fortuneAttackArmor", false):
		if gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src): gs._grant_unit_armor(unit, 2 * last_repeats(gs, owner))

static func before_attacked(gs, owner: int, idx: int) -> void:
	before_attack(gs, owner, idx)

static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	var card: Dictionary = options.get("combatCard", {})
	if not card.get("fortuneReplay", false) or gs.winner >= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.hp) <= 0: return
	if not gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src): return
	for copy in last_repeats(gs, owner):
		if gs.player(owner).hand.size() < 2: break
		for discard in 2:
			var hand: Array = gs.player(owner).hand
			var idx := int(floor(gs.randf01() * hand.size()))
			var inst: Dictionary = hand.pop_at(idx)
			if not gs.player(owner).has("discard"): gs.player(owner).discard = []
			gs.player(owner).discard.append(inst)
			gs.VerifiedRules.event(gs, "fortune-random-discard", {"player": owner, "card": inst.definitionId})
		gs._push_card_frames(owner, str(card.id), null, card, src, 0, true)

static func prepare_combat(gs, owner: int, src: int, card: Dictionary) -> Dictionary:
	var out := card.duplicate(true)
	if not card.get("fortuneCombat", false): return out
	var unit: Dictionary = gs.player(owner).units[src]
	var success_roll: bool = gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src, card.get("fortuneImmune", false) and not unit.get("form", {}).is_empty())
	if card.get("fortuneImmune", false): out.combatOption.immuneCombat = success_roll
	elif success_roll:
		for copy in last_repeats(gs, owner): add_card(gs, owner, str(card.id))
	return out

static func add_card(gs, owner: int, id: String) -> void:
	if gs.player(owner).hand.size() >= int(gs.rules.maxHandSize): return
	gs.player(owner).hand.append({"instanceId": "%s-c%d" % [gs.player(owner).id, gs.next_card_id], "definitionId": id})
	gs.next_card_id += 1

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"fortune-blessing":
			if not target.is_empty() and gs._unit_index_by_uid(owner, target.uid) >= 0 and int(target.hp) > 0:
				gs._grow_unit(target, int(card.value.attack), int(card.value.hp))
				if sixes(gs, owner) >= 3: target.swift = true
		"fortune-combat":
			var played := prepare_combat(gs, owner, src, card)
			gs._resolve_action(owner, src, played, {"action": "assault", "value": 0, "target": "source"}, target_id, target)
		"fortune-dice-damage":
			if not gs.VerifiedRules.Light.roll(gs, owner, 1, 6, src): return true
			var amount := int(gs.kw_usage(owner, "fortune").last.roll)
			var copies := last_repeats(gs, owner)
			for copy in copies:
				if str(target_id) == "avatar-%d" % (1 - owner): gs._damage_avatar(1 - owner, amount, owner, src)
				elif not target.is_empty() and int(target.hp) > 0: gs._damage_unit(1 - owner, gs._unit_index_by_uid(1 - owner, target.uid), amount, owner, src)
		"fortune-win":
			if sixes(gs, owner) >= 10:
				gs.winner = owner
				gs.phase = "finished"
				gs.VerifiedRules.event(gs, "fortune-special-win", {"player": owner})
			else: unit.nextFortuneSix = true
		"fortune-transform":
			var idx: int = gs.front_index(1 - owner)
			if idx >= 0: transform(gs, 1 - owner, idx, sixes(gs, owner) >= 3)
		"fortune-force-attack":
			if target.is_empty() or int(target.hp) <= 0: return true
			target.temporaryAttack = int(target.get("temporaryAttack", 0)) - sixes(gs, owner)
			target.fortuneForcedAttackDebuff = int(target.get("fortuneForcedAttackDebuff", 0)) + sixes(gs, owner)
			gs._recalc(target)
			gs._resolve_combat(1 - owner, gs._unit_index_by_uid(1 - owner, target.uid), 0, false, false, false, false)
		_: return false
	return true

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
	if not card.get("fortuneCombat", false): return false
	gs.VerifiedRules.ArmorBreak.respond_combat(gs, combat_id, owner, src, prepare_combat(gs, owner, src, card))
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("fortunePair", false): return null
	match str(card.get("effect", "")):
		"fortune-win": return 10000 if sixes(gs, owner) >= 10 else 55
		"fortune-transform": return 75 if gs.front_index(1 - owner) >= 0 else -100
		"fortune-force-attack":
			var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
			if target.is_empty(): return -100
			return 60 + maxi(0, 6 - int(target.hp)) - maxi(0, int(target.attack) - sixes(gs, owner)) * 3
		"fortune-dice-damage": return 60
		"fortune-combat": return 60
		"form": return 58 + int(card.value.hp)
	return 55
