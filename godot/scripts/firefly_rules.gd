class_name FireflyRules
extends RefCounted
## Form-card aura, per-instance enhancement and expiring stat changes.

static func grants_form_draw(gs, owner: int, observer: Dictionary, card: Dictionary) -> bool:
	if int(observer.hp) <= 0 or int(observer.level) < 1 or card.get("type") != "form": return false
	var cfg: Dictionary = ContentLoader.unit_def(str(observer.id)).get("formCardAura", {})
	return not cfg.is_empty() and (observer.id == card.get("unitId") or (observer.awakened and cfg.get("awakenedAllies", false)))

static func describe_card(gs, owner: int, instance: Dictionary, definition: Dictionary) -> Dictionary:
	var card := definition.duplicate(true)
	for observer in gs.player(owner).units:
		if grants_form_draw(gs, owner, observer, card):
			var keywords: Array = card.get("keywords", []).duplicate()
			if not keywords.any(func(k): return str(k).to_lower() == "instant"): keywords.append("instant")
			card.keywords = keywords
			card.formAuraDraw = true
			break
	if card.get("enhanceWhileSourceForm", false):
		var count := int(instance.get("enhanceCount", 0))
		var amount := int(card.get("baseValue", 1)) + count
		card.value = amount
		card.enhanceCount = count
		card.text = "使一个己方式神+%d生命，或对一个敌方式神造成%d点伤害。增强：己方回合开始时，若萤草上有形态，此牌效果+1。已增强%d次。" % [amount, amount, count]
		card.effects[0].value = amount
	return card

static func card_announced(gs, owner: int, src: int, card: Dictionary) -> void:
	for observer in gs.player(owner).units:
		if grants_form_draw(gs, owner, observer, card):
			gs.VerifiedRules.event(gs, "form-aura-draw", {"player": owner, "uid": observer.uid, "target": gs.player(owner).units[src].uid, "card": card})
			gs._draw(owner, 1)
			if gs.winner >= 0: return

static func begin_turn(gs, owner: int) -> void:
	# Called before the normal draw. New cards drawn during this turn start did
	# not witness its start and cannot inherit another instance's enhancement.
	for instance in gs.player(owner).hand:
		var card := ContentLoader.card_def(str(instance.definitionId))
		if not card.get("enhanceWhileSourceForm", false): continue
		var src: int = gs._source_index(owner, card)
		if src < 0: continue
		var source: Dictionary = gs.player(owner).units[src]
		if int(source.hp) <= 0 or source.get("form", {}).is_empty(): continue
		instance.enhanceCount = int(instance.get("enhanceCount", 0)) + 1
		gs.VerifiedRules.event(gs, "hand-enhanced", {"player": owner, "uid": source.uid, "instanceId": instance.instanceId, "amount": int(instance.enhanceCount) + int(card.get("baseValue", 1)), "card": card})

static func form_turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.hp) <= 0: return
	var effect := str(unit.get("formRules", {}).get("fireflyLight", ""))
	if not effect.is_empty(): light_effect(gs, owner, src, effect)

static func light_effect(gs, owner: int, src: int, effect: String) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	match effect:
		"heal":
			for unit in gs.player(owner).units:
				if int(unit.hp) > 0: gs._heal_unit(unit, 2)
		"courage": gs._apply_encourage(owner, 2, 0)
		"energy":
			# Bonus fire is not constrained by the baseline executor's invented
			# four-fire cap. It is reset to the ordinary allotment next turn.
			gs.player(owner).energy = int(gs.player(owner).energy) + 1
		_: return
	gs.VerifiedRules.event(gs, "firefly-light", {"player": owner, "uid": source.uid, "light": effect})

static func clear_flash(unit: Dictionary) -> void:
	if not unit.has("flashAttackReduction"): return
	unit.attackBonus = int(unit.attackBonus) + int(unit.flashAttackReduction)
	unit.erase("flashAttackReduction")
	unit.erase("flashAppliedTurn")

static func knocked_out(unit: Dictionary) -> void:
	clear_flash(unit)
	# A plain +生命 is not a permanent modifier. Awakening has its own
	# permanent increment and must survive alongside this temporary increase.
	unit.maxHpBonus = int(unit.maxHpBonus) - int(unit.get("fireflyTemporaryHealth", 0))
	unit.erase("fireflyTemporaryHealth")

static func end_turn(gs, _owner: int) -> void:
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("flashAppliedTurn", -1)) != gs.turn_counter: continue
			clear_flash(unit)
			gs._recalc(unit)
			gs.VerifiedRules.event(gs, "flash-expired", {"uid": unit.uid})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action", "")):
		"damage-character":
			var amount := int(effect.get("value", card.get("value", 0)))
			for victim in 2:
				if str(target_id) == "avatar-%d" % victim:
					gs._damage_avatar(victim, amount, owner)
					return true
				var idx: int = gs._unit_index_by_uid(victim, target.get("uid", ""))
				if idx >= 0 and int(target.get("hp", 0)) > 0:
					gs._damage_unit(victim, idx, amount, owner)
					return true
		"firefly-light": light_effect(gs, owner, src, str(effect.get("value", "")))
		"firefly-dual-target":
			if target.is_empty() or int(target.hp) <= 0: return true
			var own: int = gs._unit_index_by_uid(owner, target.uid)
			var amount := int(effect.get("value", card.get("value", 1)))
			if own >= 0:
				gs._grow_unit(target, 0, amount)
				target.fireflyTemporaryHealth = int(target.get("fireflyTemporaryHealth", 0)) + amount
			else:
				var enemy: int = gs._unit_index_by_uid(1 - owner, target.uid)
				if enemy >= 0: gs._damage_unit(1 - owner, enemy, amount, owner)
		"firefly-flash":
			if target.is_empty() or int(target.hp) <= 0 or int(target.front) != 1 or gs._unit_index_by_uid(1 - owner, target.uid) < 0: return true
			var reduction := int(target.attack)
			target.attackBonus = int(target.attackBonus) - reduction
			target.flashAttackReduction = int(target.get("flashAttackReduction", 0)) + reduction
			target.flashAppliedTurn = gs.turn_counter
			target.flashZeroSerial = int(target.get("flashZeroSerial", 0)) + 1
			gs._recalc(target)
			gs._log("%s 本回合力量变为0。" % target.name, gs.TONE_CARD)
			gs.VerifiedRules.event(gs, "attack-zeroed", {"player": owner, "uid": gs.player(owner).units[src].uid, "target": target.uid})
		"firefly-rainbow":
			var p: Dictionary = gs.player(owner)
			for id in card.get("generatedCards", []):
				var instance := {"instanceId": "%s-rainbow%d" % [p.id, gs.next_card_id], "definitionId": id}
				gs.next_card_id += 1
				if p.hand.size() < int(gs.rules.maxHandSize):
					p.hand.append(instance)
					gs._log("将「%s」置入手牌。" % ContentLoader.card_def(id).name, gs.TONE_CARD)
				else: gs._log("手牌已满，「%s」被烧毁。" % ContentLoader.card_def(id).name, gs.TONE_DANGER)
		"firefly-awaken":
			var source: Dictionary = gs.player(owner).units[src]
			source.awakened = true
			source.passive_hooks = []
			gs._grow_unit(source, int(effect.value.attack), int(effect.value.hp))
			gs.VerifiedRules.event(gs, "firefly-awakened", {"player": owner, "uid": source.uid, "card": card})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var action := str(card.get("effect", ""))
	if action == "damage-character":
		if str(target_id) == "avatar-%d" % owner or gs._unit_index_by_uid(owner, target_id) >= 0: return -100
		if str(target_id) == "avatar-%d" % (1 - owner): return 1000 if int(gs.player(1 - owner).avatarHp) + int(gs.player(1 - owner).avatarArmor) <= int(card.value) else 40
		var unit: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
		return 55 + (35 if not unit.get("barrier", false) and int(unit.get("hp", 0)) + int(unit.get("shield", 0)) <= int(card.value) else 0)
	if action == "firefly-dual-target":
		var unit: Dictionary = gs._unit_by_uid(gs._all_units(), target_id)
		if unit.is_empty(): return -100
		var value := int(card.value)
		if gs._unit_index_by_uid(owner, target_id) >= 0: return 24 + mini(value, int(unit.maxHp)) + (12 if int(unit.front) > 0 else 0)
		return 55 + value + (35 if value >= int(unit.hp) + int(unit.shield) and not unit.get("barrier", false) else 0)
	if action == "firefly-flash":
		var enemy: Dictionary = gs.front_unit(1 - owner)
		if enemy.is_empty() or int(enemy.attack) <= 0 or gs.player(owner).attackUsed or int(gs.player(owner).energy) <= 1: return -100
		return 62 + int(enemy.attack)
	if action == "firefly-rainbow": return 42 if gs.player(owner).hand.size() <= int(gs.rules.maxHandSize) - 2 else -100
	if action == "firefly-awaken": return 60
	return null
