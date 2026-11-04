class_name ShantongRules
extends RefCounted

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("mountainGrowth", false)

static func immune(unit: Dictionary, owner: int, source_owner: int, combat: bool) -> bool:
	return is_source(unit) and unit.awakened and source_owner >= 0 and source_owner != owner and not combat

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return card
	var view := card.duplicate(true)
	if card.get("effect") == "mountain-collapse":
		var growth := int(gs.player(owner).units[src].get("permanentAttack", 0))
		view.value = {"front": 4 + growth, "reserve": 1 + growth}
		view.text = "对敌方战斗区式神造成%d伤害，对准备区式神造成%d伤害。增强：山童每永久提高1力量，此牌伤害+1。已永久提高%d力量。" % [4 + growth, 1 + growth, growth]
	if card.get("combatOption", {}).get("counterPierce", false) and gs.current_player != owner:
		view.value = int(card.value) + 2
		view.effects[0].value = view.value
	return view

static func turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not unit.get("formRules", {}).get("automaticAttack", false) or int(unit.hp) <= 0 or int(unit.level) < 1 or int(unit.frozen) > 0: return
	gs._record("assault", {"unit": src, "bonus": 0, "automatic": true}, owner)
	gs._resolve_combat(owner, src, 0, false, false, false, false)
	gs._resolve_resolution_stack()

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"mountain-permanent-power":
			unit.permanentAttack = int(unit.get("permanentAttack", 0)) + int(effect.value)
			gs._recalc(unit)
		"mountain-roar":
			for ally in gs.player(owner).units:
				if int(ally.hp) <= 0: continue
				ally.temporaryAttack = int(ally.get("temporaryAttack", 0)) + int(effect.value)
				gs._recalc(ally)
		"mountain-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"mountain-collapse":
			var extra := int(unit.get("permanentAttack", 0))
			var targets: Array = []
			for i in gs.player(1 - owner).units.size():
				var target: Dictionary = gs.player(1 - owner).units[i]
				if int(target.hp) > 0: targets.append({"idx": i, "damage": (4 if int(target.front) == 1 else 1) + extra})
			for target in targets:
				if gs.winner >= 0: break
				gs._damage_unit(1 - owner, int(target.idx), int(target.damage), owner, src)
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, _target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return null
	var unit: Dictionary = gs.player(owner).units[src]
	if card.get("effect") == "mountain-awaken": return 60 if not unit.awakened else 8
	if card.get("effect") == "mountain-collapse":
		var score := 0
		for target in gs.player(1 - owner).units:
			if int(target.hp) > 0: score += mini(int(target.hp), (4 if int(target.front) == 1 else 1) + int(unit.get("permanentAttack", 0))) * 6
		return score - 5
	if card.get("effect") == "mountain-roar": return 26
	if card.get("type") == "form": return 40 if unit.get("form", {}).get("cardId") != card.id else -100
	if card.get("type") == "combat": return 52 + int(card.get("value", 0))
	if card.get("effect") == "mountain-permanent-power": return 60
	return null
