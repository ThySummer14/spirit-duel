class_name HaifangzhuRules
extends RefCounted
## Healing keeps its source, actual recovery and excess separate.

static func is_source(unit: Dictionary) -> bool:
	return ContentLoader.runtime_unit_def(unit).get("tideRestoration", false)

static func heal(gs, owner: int, src: int, victim: int, idx: int, amount: int) -> int:
	if amount <= 0 or gs.winner >= 0: return 0
	if gs.VerifiedRules.Light.convert_heal(gs, owner, src, victim, idx, amount): return 0
	var source: Dictionary = gs.player(owner).units[src]
	var p: Dictionary = gs.player(victim)
	if idx >= 0 and int(p.units[idx].hp) <= 0: return 0
	var missing: int = int(p.maxAvatarHp) - int(p.avatarHp) if idx < 0 else int(p.units[idx].maxHp) - int(p.units[idx].hp)
	var restored := mini(amount, maxi(0, missing))
	var excess := amount - restored
	if idx < 0: gs._heal_avatar(victim, amount)
	else: gs._heal_unit(p.units[idx], amount)
	var active: bool = is_source(source) and int(source.hp) > 0 and int(source.level) > 0
	var armor := 0
	if active and owner == victim and excess > 0:
		if idx < 0: armor = gs._grant_avatar_armor(victim, excess)
		else:
			armor = gs._grant_unit_armor(p.units[idx], excess)
			if source.awakened:
				p.units[idx].temporaryAttack = int(p.units[idx].get("temporaryAttack", 0)) + excess
				gs._recalc(p.units[idx])
		gs.VerifiedRules.event(gs, "tide-overheal", {"player": owner, "uid": source.uid, "target": "" if idx < 0 else p.units[idx].uid, "victimPlayer": victim, "amount": excess, "armor": armor, "attack": excess if source.awakened and idx >= 0 else 0})
	gs.VerifiedRules.event(gs, "tide-heal", {"player": owner, "uid": source.uid, "target": "" if idx < 0 else p.units[idx].uid, "victimPlayer": victim, "amount": restored})
	if active and idx < 0 and restored > 0 and source.get("formRules", {}).get("healSelfOnAvatarRestore", false):
		heal(gs, owner, src, owner, src, restored)
	return restored

static func combat_traits(gs, owner: int, src: int) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[src]
	return {"tideHealOthers": bool(unit.get("formRules", {}).get("combatHealOthers", false)), "tideCombatHeals": unit.get("tideCombatHeals", []).filter(func(e): return int(e.turn) == gs.turn_counter).duplicate(true)}

static func combat_dealt(gs, owner: int, src: int, result: Dictionary, traits: Dictionary) -> void:
	var amount := int(result.get("dealt", result.get("damage", 0)))
	if amount <= 0 or gs.winner >= 0: return
	if traits.get("tideHealOthers", false):
		heal(gs, owner, src, owner, -1, amount)
		for i in gs.player(owner).units.size():
			if i != src: heal(gs, owner, src, owner, i, amount)
	for entry in traits.get("tideCombatHeals", []):
		# The recipient has gained this ability; another healer's passive must
		# not convert its recovery merely because it granted the card effect.
		heal(gs, owner, src, int(entry.owner), -1, int(entry.amount))

static func end_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if unit.has("tideCombatHeals"): unit.tideCombatHeals = unit.tideCombatHeals.filter(func(e): return int(e.turn) > gs.turn_counter)

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return card
	var view := card.duplicate(true)
	var armor := int(gs.player(owner).units[src].shield)
	if card.get("effect") == "tide-heal":
		view.text = "瞬发。为一个角色恢复%d点生命（基础3，每2点海坊主护甲额外+1）。" % (3 + int(armor / 2))
	elif card.get("effect") == "tide-cyclone":
		var poison := int(gs.player(owner).units[src].armorBreak)
		view.text = "使海坊主获得3护甲，对一个式神造成等同于其护甲的伤害（当前预计%d）。" % gs.VerifiedRules.ArmorBreak.armor_after_gain(armor, poison, 3)
	return view

static func resolve_action(gs, owner: int, src: int, _card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"tide-heal":
			var amount := 3 + int(int(unit.shield) / 2)
			for victim in 2:
				if str(target_id) == "avatar-%d" % victim: heal(gs, owner, src, victim, -1, amount)
				elif not target.is_empty():
					var idx: int = gs._unit_index_by_uid(victim, target.uid)
					if idx >= 0: heal(gs, owner, src, victim, idx, amount)
		"tide-heal-all":
			heal(gs, owner, src, owner, -1, 3)
			for i in gs.player(owner).units.size(): heal(gs, owner, src, owner, i, 3)
		"tide-cyclone":
			gs._grant_unit_armor(unit, 3)
			if not target.is_empty():
				for victim in 2:
					var idx: int = gs._unit_index_by_uid(victim, target.uid)
					if idx >= 0: gs._damage_unit(victim, idx, int(unit.shield) + int(_card.get("foxHandDamageBonus", 0)), owner, src)
		"tide-wave":
			var amount := 0
			for i in gs.player(1 - owner).units.size():
				if gs.winner >= 0: break
				var hit: Dictionary = gs._damage_unit(1 - owner, i, 2 + int(_card.get("foxHandDamageBonus", 0)), owner, src)
				amount += int(hit.get("dealt", hit.damage))
			heal(gs, owner, src, owner, src, amount)
		"tide-shield":
			if target.is_empty() or int(target.hp) <= 0: return true
			gs._grant_unit_armor(target, 2)
			if not target.has("tideCombatHeals"): target.tideCombatHeals = []
			target.tideCombatHeals.append({"owner": owner, "amount": 2, "turn": gs.turn_counter})
		"tide-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0 or not is_source(gs.player(owner).units[src]): return null
	var unit: Dictionary = gs.player(owner).units[src]
	var ally: Dictionary = gs._unit_by_uid(gs.player(owner).units, target_id)
	var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
	match str(card.get("effect", "")):
		"tide-heal":
			if str(target_id) == "avatar-%d" % owner: return 40 + mini(10, int(gs.player(owner).maxAvatarHp) - int(gs.player(owner).avatarHp)) * 4
			return 40 + int(ally.get("attack", 0)) + (15 if unit.awakened else 0) if not ally.is_empty() else -100
		"tide-cyclone": return 55 + int(enemy.get("attack", 0)) * 3 if not enemy.is_empty() else -100
		"tide-heal-all": return 55 + (25 if unit.awakened else 0)
		"tide-wave": return 32 + gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("barrier", false)).size() * 7
		"tide-shield": return 35 if not ally.is_empty() else -100
		"tide-awaken": return 70 if not unit.awakened else 10
		"form": return 60 if unit.get("form", {}).get("cardId") != card.id else -100
	return null
