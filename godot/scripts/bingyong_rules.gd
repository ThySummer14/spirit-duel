class_name BingyongRules
extends RefCounted
## Armor is read at resolution time; form growth has its own nonpermanent ledger.

static func preserves_armor(unit: Dictionary) -> bool:
	return bool(unit.get("awakened", false)) and ContentLoader.runtime_unit_def(unit).has("bingyongArmor")

static func gain_armor(gs, owner: int, unit: Dictionary, amount: int) -> void:
	if amount <= 0 or int(unit.hp) <= 0: return
	var gained: int = gs._grant_unit_armor(unit, amount)
	if gained > 0:
		gs.VerifiedRules.event(gs, "armor-gained", {"player": owner, "uid": unit.uid, "amount": gained})

static func describe_card(_gs, _owner: int, instance: Dictionary, definition: Dictionary) -> Dictionary:
	if not definition.get("enhanceWhileSourceFront", false): return definition
	var card := definition.duplicate(true)
	var count := int(instance.get("enhanceCount", 0))
	var amount := int(card.get("baseValue", 2)) + count
	card.value = amount
	card.enhanceCount = count
	card.combatOption.shield = amount
	card.effects[0].value = amount
	card.text = "本次战斗获得+%d力量/+%d护甲。增强：己方回合开始时若兵俑在战斗区，此牌获得+1力量/+1护甲。已增强%d次。" % [amount, amount, count]
	return card

static func begin_turn(gs, owner: int) -> void:
	for instance in gs.player(owner).hand:
		var card := ContentLoader.card_def(str(instance.definitionId))
		if not card.get("enhanceWhileSourceFront", false): continue
		var src: int = gs._source_index(owner, card)
		if src < 0: continue
		var source: Dictionary = gs.player(owner).units[src]
		if int(source.hp) <= 0 or int(source.level) < 1 or int(source.front) != 1: continue
		instance.enhanceCount = int(instance.get("enhanceCount", 0)) + 1
		gs.VerifiedRules.event(gs, "hand-enhanced", {"player": owner, "uid": source.uid, "instanceId": instance.instanceId, "amount": int(instance.enhanceCount) + int(card.get("baseValue", 2)), "card": card})

static func unit_turn_start(gs, owner: int, src: int) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	if int(source.hp) <= 0 or int(source.level) < 1: return
	var cfg: Dictionary = ContentLoader.runtime_unit_def(source).get("bingyongArmor", {})
	if cfg.is_empty(): return
	gain_armor(gs, owner, source, int(cfg.get("turnArmor", 2)))

static func form_turn_start(gs, owner: int, src: int) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	var amount := int(source.get("formRules", {}).get("frontTurnGrowth", 0))
	if amount <= 0 or int(source.hp) <= 0 or int(source.level) < 1 or int(source.front) != 1: return
	gs._grow_unit(source, amount, 0)
	source.bingyongTemporaryAttack = int(source.get("bingyongTemporaryAttack", 0)) + amount
	gs.VerifiedRules.event(gs, "front-growth", {"player": owner, "uid": source.uid, "attack": amount})

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	var cfg: Dictionary = card.get("formRules", {})
	if int(source.hp) <= 0: return
	if int(cfg.get("entryArmor", 0)) > 0: gain_armor(gs, owner, source, int(cfg.entryArmor))
	if cfg.get("entryArmorHealth", false):
		var amount := int(source.shield)
		for target in gs.player(owner).units:
			if target.uid == source.uid or int(target.hp) <= 0 or amount <= 0: continue
			gs._grow_unit(target, 0, amount)
			target.bingyongTemporaryHealth = int(target.get("bingyongTemporaryHealth", 0)) + amount
			gs.VerifiedRules.event(gs, "armor-health", {"player": owner, "uid": source.uid, "target": target.uid, "amount": amount})
	if cfg.get("entryFront", false) and int(source.front) == 0 and not replacement_blocked(gs, owner, source):
		# Moving never creates a combat or spends the ordinary attack allowance.
		gs.VerifiedRules.move_unit(gs, owner, source)

static func limit_damage(unit: Dictionary, amount: int) -> int:
	if unit.get("formRules", {}).get("armorDamageCap", false) and int(unit.shield) > 0:
		return mini(amount, int(unit.shield))
	return amount

static func replacement_blocked(gs, owner: int, entering: Dictionary) -> bool:
	if entering.is_empty() or int(entering.get("front", 0)) == 1: return false
	var current: Dictionary = gs.front_unit(owner)
	if current.is_empty() or current.uid == entering.uid: return false
	for enemy in gs.player(1 - owner).units:
		if int(enemy.hp) > 0 and int(enemy.level) >= 1 and int(enemy.front) == 1 and enemy.get("formRules", {}).get("lockEnemyFrontReplacement", false): return true
	return false

static func knocked_out(unit: Dictionary) -> void:
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("bingyongTemporaryAttack", 0))
	unit.maxHpBonus = int(unit.maxHpBonus) - int(unit.get("bingyongTemporaryHealth", 0))
	unit.erase("bingyongTemporaryAttack")
	unit.erase("bingyongTemporaryHealth")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	var source: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"bingyong-dustblade":
			var bonus := int(source.shield)
			var options: Dictionary = card.get("combatOption", {}).duplicate(true)
			options.combatCard = card.duplicate(true)
			gs._record("assault", {"unit": src, "target": target_id, "bonus": bonus}, owner)
			gs._resolve_combat(owner, src, bonus, false, false, false, false, target_id, false, options)
		"bingyong-shield": gain_armor(gs, owner, target, int(effect.value))
		"bingyong-awaken":
			source.awakened = true
			source.passive_hooks = []
			gain_armor(gs, owner, source, int(effect.value))
			gs.VerifiedRules.event(gs, "armor-awakened", {"player": owner, "uid": source.uid, "card": card})
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("bingyongRules", false): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	var source: Dictionary = gs.player(owner).units[src]
	var enemy: Dictionary = gs.front_unit(1 - owner)
	match str(card.get("effect", "")):
		"bingyong-dustblade", "assault":
			if replacement_blocked(gs, owner, source): return -100
			var bonus := int(source.shield) if card.effect == "bingyong-dustblade" else int(card.value)
			var power := int(source.attack) + bonus
			if enemy.is_empty(): return 1000 if power >= int(gs.player(1 - owner).avatarHp) + int(gs.player(1 - owner).avatarArmor) else 42 + power
			return 44 + power + (25 if power >= int(enemy.hp) + int(enemy.shield) else 0)
		"bingyong-shield":
			var target: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
			if target.is_empty(): return -100
			return 40 + (25 if target.front else 0) + (10 if preserves_armor(target) else 0)
		"bingyong-awaken": return 54 if not source.awakened else 32
		"form":
			var cfg: Dictionary = card.get("formRules", {})
			if cfg.get("entryFront", false): return 48 + int(source.maxHp) - int(source.hp)
			if cfg.get("entryArmorHealth", false): return 34 + int(source.shield) * 4
			if cfg.get("armorDamageCap", false): return 51
			if cfg.get("lockEnemyFrontReplacement", false): return 34 + (18 if source.front and not enemy.is_empty() else 0)
	return null
