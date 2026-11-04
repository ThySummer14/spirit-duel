class_name DogDemonRules
extends RefCounted
## Permanent training, form snapshots and source-owned kill chains have separate lifetimes.

static func dog(unit: Dictionary) -> bool:
	return bool(ContentLoader.runtime_unit_def(unit).get("dogTraining", false))

static func demon(unit: Dictionary) -> bool:
	return bool(ContentLoader.runtime_unit_def(unit).get("demonStrength", false))

static func record_strength(unit: Dictionary) -> void:
	if demon(unit): unit.demonPeakStrength = maxi(int(unit.get("demonPeakStrength", 0)), int(unit.attack))

static func level_up(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not dog(unit) or unit.awakened: return
	var p: Dictionary = gs.player(owner)
	if p.hand.size() >= int(gs.rules.maxHandSize):
		gs._log("手牌已满，升级获得的「心身炼磨」被烧毁。", gs.TONE_DANGER)
		return
	p.hand.append({"instanceId": "%s-training%d" % [p.id, gs.next_card_id], "definitionId": "xinshen-lianmo"})
	gs.next_card_id += 1
	gs.VerifiedRules.event(gs, "dog-training-generated", {"player": owner, "uid": unit.uid})

static func card_announced(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("dogTrainingCard", false): return
	var unit: Dictionary = gs.player(owner).units[src]
	unit.dogTrainings = int(unit.get("dogTrainings", 0)) + 1
	gs.VerifiedRules.event(gs, "dog-training-used", {"player": owner, "uid": unit.uid, "count": unit.dogTrainings})

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var unit: Dictionary = gs.player(owner).units[src]
	if not dog(unit) and not demon(unit): return card
	var view := card.duplicate(true)
	if dog(unit):
		if int(unit.hp) > 0 and unit.get("formRules", {}).get("dogInstant", false):
			if not view.keywords.has("instant"): view.keywords.append("instant")
			view.text += "\n心剑乱舞：此牌获得瞬发。"
		if card.get("dogTrainingForm", false):
			view.dogTrainingSnapshot = int(unit.get("dogTrainings", 0))
			view.text += "\n当前心身炼磨使用次数：%d。" % view.dogTrainingSnapshot
		if card.type == "combat" and int(unit.hp) > 0:
			var bonus := int(unit.get("formRules", {}).get("dogCombatBonus", 0))
			if bonus > 0:
				view.value = int(view.value) + bonus
				view.effects[0].value = view.value
				view.combatOption.shield = int(view.combatOption.get("shield", 0)) + bonus
				view.text += "\n心技一体：本次战斗额外+%d力量/+%d护甲。" % [bonus, bonus]
	elif card.get("demonPull", false):
		view.target = "enemy-reserve-unit" if gs.front_index(1 - owner) < 0 else "auto"
	elif card.get("effect") == "demon-restore-peak":
		view.text += "\n本局最高力量：%d。" % maxi(int(unit.attack), int(unit.get("demonPeakStrength", 0)))
	return view

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	var src: int = gs._source_index(owner, card)
	if src < 0: return false
	if card.get("requiresKnockedSource", false): return int(gs.player(owner).units[src].hp) <= 0
	return true

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("dogTrainingForm", false):
		var unit: Dictionary = gs.player(owner).units[src]
		unit.formRules.dogCombatBonus = int(card.get("dogTrainingSnapshot", unit.get("dogTrainings", 0)))
		unit.formAbility = "犬神的战斗牌额外获得+%d力量与+%d护甲（进场时固定）。" % [unit.formRules.dogCombatBonus, unit.formRules.dogCombatBonus]

static func turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not demon(unit) or int(unit.hp) <= 0 or int(unit.level) < 1: return
	var gain := maxi(0, int(unit.attack)) if unit.awakened else 1
	unit.demonGrowth = int(unit.get("demonGrowth", 0)) + gain
	gs._grow_unit(unit, gain, 0)
	record_strength(unit)
	gs.VerifiedRules.event(gs, "demon-strength", {"player": owner, "uid": unit.uid, "amount": gain, "awakened": unit.awakened})

static func end_turn(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[src]
		if not dog(unit) or not unit.awakened or int(unit.level) < 1: continue
		if int(unit.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
		gs.VerifiedRules.Glutton.record_permanent(unit,1,1)
		gs.VerifiedRules.SunSmoke.remember_permanent(unit,1,1)
		gs._grow_unit(unit, 1, 1)
		gs.VerifiedRules.event(gs, "dog-end-turn-growth", {"player": owner, "uid": unit.uid})

static func knocked_out(unit: Dictionary) -> void:
	if not demon(unit): return
	record_strength(unit)
	unit.attackBonus = int(unit.attackBonus) - int(unit.get("demonGrowth", 0))
	unit.erase("demonGrowth")

static func unit_killed(gs, owner: int, src: int, victim: int, target: Dictionary, was_front: bool) -> void:
	if owner < 0 or src < 0 or src >= gs.player(owner).units.size(): return
	var unit: Dictionary = gs.player(owner).units[src]
	if not demon(unit) or ((target.get("summon", false) or target.get("summoned", false)) and not target.get("countsAsShikigami", false)): return
	unit.demonKills = int(unit.get("demonKills", 0)) + 1
	gs.VerifiedRules.event(gs, "demon-kill-history", {"player": owner, "uid": unit.uid, "target": target.uid, "count": unit.demonKills})
	if owner == victim or not was_front or int(unit.hp) <= 0 or not unit.get("formRules", {}).get("demonReserveWrath", false): return
	# The killed unit has already left play. These are source-owned damage events,
	# so reserve kills count in the same history without recursively splashing.
	var saved: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	for idx in gs.player(victim).units.size():
		var enemy: Dictionary = gs.player(victim).units[idx]
		if int(enemy.hp) > 0 and int(enemy.front) == 0: gs._damage_unit(victim, idx, 2, owner, src)
	gs._card_effect_context = saved

static func combat_finished(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
	if not options.get("demonHellChain", false) or kills <= 0 or gs.winner >= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.hp) <= 0: return
	var candidates: Array = []
	var lowest := 2147483647
	for enemy in gs.player(1 - owner).units:
		if int(enemy.hp) <= 0: continue
		if int(enemy.hp) < lowest:
			lowest = int(enemy.hp)
			candidates.clear()
		if int(enemy.hp) == lowest: candidates.append(enemy.uid)
	if candidates.is_empty(): return
	var selected: String = str(candidates[int(floor(gs.randf01() * candidates.size()))])
	gs.resolution_stack.append({"kind": "demon-chain-attack", "playerIndex": owner, "sourceIndex": src, "targetId": selected, "card": options.get("combatCard", {}).duplicate(true)})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind") != "demon-chain-attack": return false
	var options := {"pursuit": true, "demonHellChain": true, "combatCard": frame.card}
	gs.VerifiedRules.event(gs, "demon-chain-attack", {"player": frame.playerIndex, "uid": gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)].uid, "target": frame.targetId})
	gs._resolve_combat(int(frame.playerIndex), int(frame.sourceIndex), 0, false, false, false, false, frame.targetId, false, options)
	return true

static func respond_combat(gs, combat_id: int, owner: int, src: int, card: Dictionary) -> bool:
	if not card.get("dogGuard", false): return false
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.hp) <= 0 or gs.VerifiedRules.Bingyong.replacement_blocked(gs, owner, unit): return true
	for frame in gs.resolution_stack:
		if frame.get("kind") != "combat-hit" or int(frame.get("combatId", -1)) != combat_id: continue
		var movement_old: Array = []
		for i in gs.player(owner).units.size(): movement_old.append({"idx": i, "front": int(gs.player(owner).units[i].front)})
		for ally in gs.player(owner).units: ally.front = 1 if ally.uid == unit.uid else 0
		for old in movement_old: gs.VerifiedRules.Movement.moved(gs, owner, int(old.idx), int(old.front))
		frame.defenderIndex = src
		gs.VerifiedRules.ArmorBreak.respond_combat(gs, combat_id, owner, src, card)
		gs.VerifiedRules.event(gs, "dog-guard", {"player": owner, "uid": unit.uid, "card": card})
		break
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"dog-heal-full": gs._heal_unit(unit, maxi(0, int(unit.maxHp) - int(unit.hp)))
		"dog-training":
			gs.VerifiedRules.Glutton.record_permanent(unit,1,1)
			gs.VerifiedRules.SunSmoke.remember_permanent(unit,1,1)
			gs._grow_unit(unit, 1, 1)
		"dog-revive": gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
		"dog-awaken":
			gs.VerifiedRules.Glutton.record_permanent(unit,int(effect.value.attack),int(effect.value.hp),true)
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"demon-awaken":
			gs.VerifiedRules.Glutton.record_permanent(unit,0,int(effect.value.hp),true)
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, 0, int(effect.value.hp))
		"demon-strength":
			var gain := int(effect.value)
			unit.demonGrowth = int(unit.get("demonGrowth", 0)) + gain
			gs._grow_unit(unit, gain, 0)
		"demon-restore-peak":
			var gain := maxi(0, int(unit.get("demonPeakStrength", unit.attack)) - int(unit.attack))
			unit.demonGrowth = int(unit.get("demonGrowth", 0)) + gain
			gs._grow_unit(unit, gain, 0)
		"demon-pull":
			if gs.front_index(1 - owner) >= 0: return true
			if target.is_empty() or int(target.hp) <= 0: return true
			target.front = 1
			gs.VerifiedRules.Movement.moved(gs, 1 - owner, gs._unit_index_by_uid(1 - owner, target.uid), 0)
			var moved: int = gs._unit_index_by_uid(1 - owner, target.uid)
			gs._fire_hooks(1 - owner, moved, "unit-entered-front", {})
			gs._run_form_hooks(1 - owner, moved, "unit-entered-front", {})
			gs.VerifiedRules.event(gs, "unit-moved", {"player": 1 - owner, "uid": target.uid, "front": 1})
		_: return false
	record_strength(unit)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	var src: int = gs._source_index(owner, card)
	if src < 0: return null
	var unit: Dictionary = gs.player(owner).units[src]
	if not dog(unit) and not demon(unit): return null
	match str(card.get("effect", "")):
		"dog-heal-full": return maxi(0, int(unit.maxHp) - int(unit.hp)) * 8 - 8
		"dog-training": return 48
		"dog-revive": return 85 if int(unit.hp) <= 0 else -100
		"dog-awaken": return 72 if not unit.awakened else -100
		"demon-strength": return 47
		"demon-restore-peak": return (int(unit.get("demonPeakStrength", unit.attack)) - int(unit.attack)) * 8 - 8
		"demon-awaken": return 57 if not unit.awakened else 8
	if card.get("type") == "form": return 46 + maxi(0, int(unit.maxHp) - int(unit.hp)) * 3
	if card.get("demonPull", false) or card.get("combatOption", {}).get("demonHellChain", false):
		var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
		if target.is_empty(): target = gs.front_unit(1 - owner)
		if target.is_empty(): return null
		var power := int(unit.attack) + int(card.value)
		return 50 + power + (30 if power >= int(target.hp) + int(target.shield) and not target.get("barrier", false) else 0) - (25 if int(target.attack) >= int(unit.hp) + int(unit.shield) else 0)
	return null
