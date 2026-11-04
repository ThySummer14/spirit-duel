class_name BondDreamRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false)

static func masters(gs, owner: int, key: String) -> Array:
	return gs.player(owner).units.filter(func(u): return active(u) and Content.runtime_unit_def(u).get(key, false))

static func nightmare_cards(gs, owner: int) -> Array:
	return gs.player(owner).deck.filter(func(i): return not i.get("nightmareMarks", []).is_empty())

static func nightmare_total(gs, owner: int) -> int:
	var amount := 0
	for inst in gs.player(owner).deck: amount += inst.get("nightmareMarks", []).size()
	return amount

static func attach(gs, owner: int, victim: int, count: int, key: String, src: int = -1, zone: String = "deck", add_bonus: bool = true) -> void:
	if count <= 0: return
	if key == "bondMarks" and add_bonus:
		count += gs.player(owner).realms.filter(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "bond-blossom").size()
	var pool: Array = gs.player(victim)[zone].duplicate()
	gs._shuffle(pool)
	for i in mini(count, pool.size()):
		var marks: Array = pool[i].get(key, [])
		marks.append({"owner": owner, "sourceUid": "" if src < 0 else str(gs.player(owner).units[src].uid)})
		pool[i][key] = marks
		gs.VerifiedRules.event(gs, "deck-charm-attached", {"player": owner, "victimPlayer": victim, "instanceId": pool[i].instanceId, "charm": key, "count": marks.size()})
	refresh(gs)

static func fetched(gs, inst: Dictionary) -> void:
	for key in ["bondMarks", "nightmareMarks", "eyeCurses"]: inst.erase(key)
	refresh(gs)

static func body(gs, unit: Dictionary) -> int:
	if not unit.get("formRules", {}).get("dreamBody", false): return -1
	for owner in gs.players.size():
		if gs._unit_index_by_uid(owner, unit.uid) >= 0: return nightmare_cards(gs, 1 - owner).size()
	return 0

static func refresh(gs) -> void:
	for p in gs.players:
		for unit in p.units.duplicate():
			if not unit.get("formRules", {}).get("dreamBody", false): continue
			gs._recalc(unit)
			if int(unit.maxHp) <= 0: gs._knockout_unit(unit)

static func prevent_damage(gs, owner: int, idx: int, amount: int) -> bool:
	var unit: Dictionary = gs.player(owner).units[idx]
	if amount <= 0 or not active(unit) or not unit.get("formRules", {}).get("dreamBody", false): return false
	var pool := nightmare_cards(gs, 1 - owner)
	gs._shuffle(pool)
	for i in mini(mini(3, amount), pool.size()):
		gs.player(1 - owner).deck.erase(pool[i])
		gs.VerifiedRules.event(gs, "dream-card-removed", {"player": owner, "uid": unit.uid, "instanceId": pool[i].instanceId, "card": Content.card_def(str(pool[i].definitionId))})
	refresh(gs)
	return true

static func drawn(gs, owner: int, inst: Dictionary) -> bool:
	var before: int = gs.resolution_stack.size()
	# LIFO：同一张牌固定为缘结→梦魇→诅咒，取得牌的效果不走这里。
	gs.VerifiedRules.OniAsura.drawn(gs,owner,inst)
	gs.VerifiedRules.Moon.drawn(gs,owner,inst)
	gs.VerifiedRules.Eye.drawn(gs, owner, inst)
	var nightmares: Array = inst.get("nightmareMarks", [])
	if not nightmares.is_empty():
		gs.resolution_stack.append({"kind": "charm-nightmare-after", "playerIndex": owner, "instance": inst.duplicate(true)})
		for i in range(nightmares.size() - 1, -1, -1):
			gs.resolution_stack.append({"kind": "charm-nightmare-hit", "playerIndex": owner, "mark": nightmares[i].duplicate(true)})
	var bonds: Array = inst.get("bondMarks", [])
	for i in range(bonds.size() - 1, -1, -1):
		gs.resolution_stack.append({"kind": "charm-bond", "playerIndex": owner, "instance": inst.duplicate(true)})
	return gs.resolution_stack.size() > before

static func grant_moon(gs, owner: int, unit: Dictionary) -> void:
	if not active(unit) or int(gs.player(owner).get("bondMoonTurn", -1)) != gs.turn_counter: return
	if int(unit.get("bondMoonSwiftTurn", -1)) != gs.turn_counter:
		unit.bondMoonSwiftBaseline = bool(unit.get("swift", false))
		unit.bondMoonSwiftTurn = gs.turn_counter
		unit.swift = true
	unit.bondMoonPursuit = true

static func bond(gs, owner: int, inst: Dictionary) -> void:
	var def: Dictionary = Content.card_def(str(inst.definitionId))
	var idx: int = gs._source_index(owner, def)
	var sources := masters(gs, owner, "bondMaster")
	var copies := 2 if sources.any(func(u): return u.awakened) else 1
	# 每回合一次的形态以本次抽牌为一组，觉醒复制该组效果两次。
	var triggers: Array = []
	for unit in sources:
		var form: Dictionary = unit.get("formRules", {})
		var reward := str(form.get("bondReward", ""))
		if reward in ["draw", "fire"] and int(unit.get("bondRewardTurns", {}).get(reward, -1)) == gs.turn_counter: continue
		if reward in ["draw", "fire"]:
			unit.bondRewardTurns = unit.get("bondRewardTurns", {})
			unit.bondRewardTurns[reward] = gs.turn_counter
		if reward != "": triggers.append(reward)
	for copy in copies:
		gs.VerifiedRules.ArmorBlood.heal(gs, owner, 2)
		if gs.winner >= 0: return
		if idx >= 0:
			gs._heal_unit(gs.player(owner).units[idx], 2)
			gs.player(owner).units[idx].bondAffectedTurn = gs.turn_counter
			grant_moon(gs, owner, gs.player(owner).units[idx])
		for reward in triggers:
			match reward:
				"fire": gs._set_fire(owner,int(gs.player(owner).energy)+1)
				"revive":
					if idx >= 0:
						var target: Dictionary = gs.player(owner).units[idx]
						if int(target.hp)<=0 and gs.VerifiedRules.Rebirth.can_revive(target):
							target.hp = int(target.maxHp); target.knockout = 0
							gs.VerifiedRules.Movement.revived(gs, owner, idx)
						gs._grow_unit(target, 1, 1)
						grant_moon(gs, owner, target)
				"draw": gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})
	gs.VerifiedRules.event(gs, "bond-resolved", {"player": owner, "instanceId": inst.instanceId, "copies": copies, "unitIndex": idx})

static func nightmare_after(gs, victim: int, inst: Dictionary) -> void:
	var owners := {}
	for mark in inst.nightmareMarks: owners[int(mark.owner)] = true
	var card: Dictionary = Content.card_def(str(inst.definitionId))
	var idx: int = gs._source_index(victim, card)
	for owner in owners:
		if owner == victim: continue
		gs.player(owner).nightmareDrawTurn = gs.turn_counter
		for realm in gs.player(owner).realms.duplicate():
			if int(realm.hp) <= 0 or idx < 0: continue
			var target: Dictionary = gs.player(victim).units[idx]
			match str(realm.get("nativeRealm", "")):
				"dream-whisper":
					if int(target.hp) > 0:
						target.dreamPowerPenalty = int(target.get("dreamPowerPenalty", 0)) + 2
						target.dreamPenaltyTurn = gs.turn_counter
						gs._recalc(target)
				"dream-sleep":
					if int(target.hp) > 0: gs.VerifiedRules.Panguan.destroy(gs, owner, gs._source_index(owner, {"unitId": realm.sourceUnit}), victim, idx)
		gs.VerifiedRules.automatic_response(gs, owner, "enemy-drew-nightmare", null, {"kind": "response-complete"}, gs.MAX_RESPONSE_DEPTH)

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary) -> void:
	if victim == owner or idx >= 0 or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if Content.runtime_unit_def(unit).get("dreamMaster", false) and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false):
		attach(gs, owner, victim, 3 if unit.awakened else 1, "nightmareMarks", src)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if not Content.is_spell(card): return
	var owner := int(frame.playerIndex)
	var sources: Array = []
	for idx in gs.player(owner).units.size():
		var unit: Dictionary = gs.player(owner).units[idx]
		if active(unit) and unit.get("formRules", {}).get("dreamOnSpell", false): sources.append(idx)
	if sources.is_empty(): return
	for i in gs.resolution_stack.size():
		if gs.resolution_stack[i].get("kind") == "card-complete" and gs.resolution_stack[i].get("resolutionId") == frame.resolutionId:
			gs.resolution_stack.insert(i, {"kind": "charm-spell-dream", "playerIndex": owner, "sources": sources})
			return

static func turn_start(gs, owner: int, idx: int) -> void:
	var unit: Dictionary = gs.player(owner).units[idx]
	if active(unit) and unit.get("formRules", {}).get("bondTurnDivination", false):
		gs.resolution_stack.append({"kind": "charm-divination", "playerIndex": owner})

static func end_turn(gs, owner: int) -> void:
	for unit in masters(gs, owner, "bondMaster"):
		attach(gs, owner, owner, 2 if unit.awakened else 1, "bondMarks", gs._unit_index_by_uid(owner, unit.uid))
	for realm in gs.player(owner).realms.duplicate():
		if int(realm.hp) > 0 and realm.get("nativeRealm") in ["dream-whisper", "dream-sleep"]:
			attach(gs, owner, 1 - owner, 1, "nightmareMarks", gs._source_index(owner, {"unitId": realm.sourceUnit}))

static func expire_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if int(unit.get("bondMoonSwiftTurn", -1)) == gs.turn_counter:
				if unit.swift: unit.swift = bool(unit.get("bondMoonSwiftBaseline", false))
				unit.erase("bondMoonSwiftTurn"); unit.erase("bondMoonSwiftBaseline"); unit.erase("bondMoonPursuit")
			if int(unit.get("dreamPenaltyTurn", -1)) == gs.turn_counter:
				unit.erase("dreamPowerPenalty"); unit.erase("dreamPenaltyTurn"); gs._recalc(unit)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var idx: int = gs._source_index(owner, card)
	var pursuit: bool = card.get("type") == "combat" and idx >= 0 and gs.player(owner).units[idx].get("bondMoonPursuit", false)
	if not card.get("bondDreamRules", false) and not pursuit and inst.get("bondMarks", []).is_empty() and inst.get("nightmareMarks", []).is_empty(): return card
	var out := card.duplicate(true)
	if pursuit:
		out.target = "enemy-unit"
		out.combatOption = out.get("combatOption", {}).duplicate(true); out.combatOption.pursuit = true
	if not inst.get("bondMarks", []).is_empty(): out.text += "\n缘结×%d：抽到时恢复对应式神与牌手2生命。" % inst.bondMarks.size()
	if not inst.get("nightmareMarks", []).is_empty(): out.text += "\n梦魇×%d：抽到时对牌手造成3点伤害。" % inst.nightmareMarks.size()
	if card.get("dreamShock", false) and int(gs.player(owner).get("nightmareDrawTurn", -1)) == gs.turn_counter:
		out.keywords.append("instant"); out.enhanced = true; out.combatOption.shield = 3
		out.text += "\n本回合敌方抽到过梦魇：本次+3护甲并获得瞬发。"
	if card.get("formRules", {}).get("dreamBody", false):
		var count := nightmare_cards(gs, 1 - owner).size()
		out.value = {"attack": count, "hp": count, "setBase": true}; out.effects[0].value = out.value.duplicate(true)
		out.currentCardStats = "当前面板 %d/%d" % [count, count]
	return out

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"bond-traveler":
			attach(gs, owner, owner, 3, "bondMarks", src)
			var pool: Array = gs.player(owner).deck.filter(func(i): return not i.get("bondMarks", []).is_empty())
			if not pool.is_empty():
				var inst: Dictionary = pool[int(floor(gs.randf01() * pool.size()))]
				gs.player(owner).deck.erase(inst); gs.player(owner).deck.append(inst)
				gs._draw(owner, 1)
		"bond-awaken": gs._awaken(owner, src, card, {"attack": 2, "hp": 2})
		"bond-moon":
			gs._apply_encourage(owner, 3, 3); gs.player(owner).bondMoonTurn = gs.turn_counter
			for unit in gs.player(owner).units:
				if int(unit.get("bondAffectedTurn", -1)) == gs.turn_counter: grant_moon(gs, owner, unit)
		"bond-together":
			var pool: Array = gs.player(owner).hand.duplicate(); gs._shuffle(pool)
			var count := mini(3, pool.size())
			for i in count:
				gs.player(owner).hand.erase(pool[i]); gs.player(owner).deck.append(pool[i])
				var marks: Array = pool[i].get("bondMarks", []); marks.append({"owner": owner, "sourceUid": gs.player(owner).units[src].uid}); pool[i].bondMarks = marks
			var bonus: int = gs.player(owner).realms.filter(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "bond-blossom").size()
			if count > 0 and bonus > 0: attach(gs, owner, owner, bonus, "bondMarks", src, "deck", false)
			gs._shuffle(gs.player(owner).deck); gs._draw(owner, 3)
		"dream-attach": attach(gs, owner, 1 - owner, int(effect.value), "nightmareMarks", src)
		"dream-awaken": gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
		"dream-feast":
			attach(gs, owner, 1 - owner, 3, "nightmareMarks", src)
			gs.VerifiedRules.ArmorBlood.heal(gs, owner, nightmare_total(gs, 1 - owner))
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", 0))
	match str(frame.get("kind", "")):
		"charm-bond": bond(gs, owner, frame.instance)
		"charm-nightmare-hit":
			var source := int(frame.mark.owner)
			var idx: int = gs._unit_index_by_uid(source, frame.mark.sourceUid)
			gs._damage_avatar(owner, 3, source, idx)
		"charm-nightmare-after": nightmare_after(gs, owner, frame.instance)
		"charm-extra-draw": gs._draw(owner, int(frame.count))
		"charm-divination": gs.VerifiedRules.Divination.start(gs, owner, 1)
		"charm-spell-dream":
			for idx in frame.sources: attach(gs, owner, 1 - owner, 1, "nightmareMarks", int(idx))
		"charm-heal-avatar": gs._heal_avatar(owner, int(frame.amount))
		"charm-book-ink":
			var count := int(gs.player(owner).hand.size() / 2) + int(frame.bonus)
			gs.VerifiedRules.Eye.damage(gs, owner, int(frame.sourceIndex), frame.targetId, count)
		"charm-mengpo-discard":
			if gs.player(owner).hand.is_empty(): return true
			gs.pending_choice = {"type": "mengpo-discard", "playerIndex": owner, "sourceIndex": int(frame.sourceIndex), "zone": "hand", "instanceIds": gs.player(owner).hand.map(func(i): return str(i.instanceId)), "heading": "意 外 之 喜", "hint": "已抽两张牌 · 选择一张当前手牌弃掉"}; gs.phase = "choice"
		"charm-fortune-reset":
			gs.player(owner).avatarHp = mini(30, int(gs.player(owner).maxAvatarHp))
			gs.resolution_stack.append({"kind": "charm-reset-fire", "playerIndex": owner})
			gs._draw(owner, maxi(0, 10 - gs.player(owner).hand.size()))
		"charm-reset-fire": gs.VerifiedRules.Light.gain_fire(gs, owner, 3)
		"charm-fortune-fire":
			if gs.VerifiedRules.Light.roll(gs, owner, 4, 6, int(frame.sourceIndex)): gs.VerifiedRules.Light.gain_fire(gs, owner, 2 * gs.VerifiedRules.Fortune.last_repeats(gs, owner))
		_: return false
	return true

static func score_card(gs, owner: int, card: Dictionary):
	if not card.get("bondDreamRules", false): return null
	var idx: int = gs._source_index(owner, card)
	var unit: Dictionary = gs.player(owner).units[idx]
	if card.get("awakening", false): return -100 if unit.awakened else 85
	if card.type == "form":
		if card.get("formRules", {}).get("dreamBody", false): return -100 if nightmare_cards(gs, 1 - owner).is_empty() else 80
		return -100 if unit.get("form", {}).get("cardId") == card.id else 65
	if card.effect == "bond-moon": return 40 + gs.player(owner).units.filter(func(u): return active(u) and int(u.get("bondAffectedTurn", -1)) == gs.turn_counter).size() * 15
	return 60
