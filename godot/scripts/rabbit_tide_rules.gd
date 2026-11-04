class_name RabbitTideRules
extends RefCounted
## 兔丸真实运势、食物使用与千姬海原贝戟的实体生命周期。
const Content := preload("res://scripts/content_loader.gd")
const Cooking := preload("res://scripts/cooking_rules.gd")

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("rabbitTideRole", ""))
static func active(u: Dictionary) -> bool:
	return int(u.get("hp", 0)) > 0 and int(u.get("level", 0)) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)
static func live_spear(gs, owner: int) -> int:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if u.get("rtSpear", false) and int(u.hp) > 0 and int(u.front) == 1 and not u.get("removed", false): return i
	return -1
static func refresh(gs) -> void:
	for owner in 2:
		var present := live_spear(gs, owner) >= 0
		for u in gs.player(owner).units:
			u.rtSpearVeil = present and active(u) and bool(u.get("formRules", {}).get("rtEternal", false))
static func rule_event(gs, kind: String, details: Dictionary) -> void:
	var owner := int(details.get("player", -1))
	if owner < 0 or owner > 1: return
	if kind == "summon-revived":
		var idx: int = gs._unit_index_by_uid(owner, str(details.get("uid", "")))
		if idx >= 0 and gs.player(owner).units[idx].get("rtSpear", false): _spear_entered(gs, owner, idx)
	elif kind == "fortune-result" and not details.get("success", true):
		var src := int(details.get("sourceIndex", -1))
		if src < 0 or src >= gs.player(owner).units.size(): return
		var u: Dictionary = gs.player(owner).units[src]
		if role(u) != "rabbit" or not active(u): return
		if not u.awakened and int(u.get("rtFailureTurn", -1)) == gs.turn_counter: return
		u.rtFailureTurn = gs.turn_counter
		Cooking.gain_unknown(gs, owner, src)
	elif kind == "cooking":
		for i in gs.player(owner).units.size():
			var u: Dictionary = gs.player(owner).units[i]
			if not active(u) or not u.get("formRules", {}).get("rtLonely", false) or int(u.get("rtLonelyTurn", -1)) == gs.turn_counter: continue
			u.rtLonelyTurn = gs.turn_counter
			gs.resolution_stack.append({"kind": "rt-lonely-food", "playerIndex": owner, "sourceIndex": i})
	elif kind == "food-used" and int(details.get("targetOwner", owner)) != owner and details.get("kind", "") in ["unknown", "dark"]:
		gs.player(owner).rtEnemyFoodTurn = gs.turn_counter
		for i in gs.player(owner).units.size():
			var u: Dictionary = gs.player(owner).units[i]
			if active(u) and u.get("formRules", {}).get("rtCookingSoul", false):
				gs.resolution_stack.append({"kind": "rt-soul-damage", "playerIndex": owner, "sourceIndex": i, "targetUid": str(details.targetUid)})
static func begin_turn(gs, owner: int) -> void:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if role(u) == "tide" and not u.get("rtFirstTurnDone", false) and int(gs.player(owner).get("turnsTaken", 0)) == 1:
			u.rtFirstTurnDone = true
			# This explicitly named first-turn trigger precedes activation choices.
			if int(u.hp) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false): gs.resolution_stack.append({"kind": "rt-summon", "playerIndex": owner, "sourceIndex": i})
		if role(u) == "rabbit" and active(u) and u.awakened:
			gs.resolution_stack.append({"kind": "rt-awake-cook", "playerIndex": owner, "sourceIndex": i})
static func card_announced(gs, owner: int, src: int, _card: Dictionary) -> void:
	if src < 0 or src >= gs.player(owner).units.size() or role(gs.player(owner).units[src]) != "tide": return
	for inst in gs.player(owner).hand:
		if str(inst.get("definitionId", "")) == "qianji-song": inst.rtSongInstant = true
static func _fortune(gs, owner: int, src: int) -> bool:
	return gs._roll_fortune(owner, {"fortuneSourceIndex": src, "fortune": {"sides": 6, "threshold": 4}})
static func before_combat(gs, frame: Dictionary) -> bool:
	if frame.get("rtPrepared", false): return false
	frame.rtPrepared = true
	var owner := int(frame.playerIndex)
	var victim := int(frame.options.get("combatVictim", 1 - owner))
	var src := int(frame.sourceIndex)
	var idx := int(frame.defenderIndex)
	if idx < 0: return false
	var a: Dictionary = gs.player(owner).units[src]
	var d: Dictionary = gs.player(victim).units[idx]
	if not gs.VerifiedRules.OwlInsect.shikigami(d): return false
	var triggers: Array = []
	if active(a) and a.get("formRules", {}).get("rtTaste", false): triggers.append({"playerIndex": owner, "sourceIndex": src, "targetUid": str(d.uid), "fortune": true})
	if frame.options.get("combatCard", {}).get("rtFoodOnAttack", false): triggers.append({"playerIndex": owner, "sourceIndex": src, "targetUid": str(d.uid), "fortune": false})
	if active(d) and d.get("formRules", {}).get("rtTaste", false) and gs.VerifiedRules.OwlInsect.shikigami(a): triggers.append({"playerIndex": victim, "sourceIndex": idx, "targetUid": str(a.uid), "fortune": true})
	if triggers.is_empty(): return false
	gs.resolution_stack.append({"kind": "rt-combat-resume", "combat": frame.duplicate(true)})
	for i in range(triggers.size() - 1, -1, -1):
		var trigger: Dictionary = triggers[i]
		trigger.kind = "rt-combat-food"
		gs.resolution_stack.append(trigger)
	return true
static func _spear_left(gs, owner: int, u: Dictionary, reason: String, grant_song: bool = true) -> void:
	if not u.get("rtSpear", false) or u.get("rtLeaveResolved", false): return
	u.rtLeaveResolved = true
	var src: int = gs._unit_index_by_uid(owner, str(u.get("summonerUid", "")))
	u.hp = 0; u.front = 0; u.knockout = 0; u.removed = true
	refresh(gs)
	if grant_song and not gs.player(owner).hand.any(func(inst): return str(inst.definitionId) == "qianji-song"):
		if gs.player(owner).hand.size() < int(gs.rules.maxHandSize):
			gs.player(owner).hand.append({"definitionId": "qianji-song", "instanceId": "qianji-song-%d" % gs.next_card_id})
			gs.next_card_id += 1
			gs.VerifiedRules.event(gs, "card-generated", {"player": owner, "sourceIndex": src, "card": Content.card_def("qianji-song")})
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": u.uid, "reason": reason})
	if src >= 0 and active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules", {}).get("rtEternal", false):
		gs.resolution_stack.append({"kind": "rt-spear-wave", "playerIndex": owner, "sourceIndex": src})
static func remove_spear(gs, owner: int, u: Dictionary, reason: String = "离开战斗区", grant_song: bool = true) -> void:
	if not u.get("rtSpear", false) or u.get("removed", false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs, owner, gs._unit_index_by_uid(owner, str(u.uid)), reason)
	gs.VerifiedRules.Vine.remove_charm(gs, owner, gs._unit_index_by_uid(owner, str(u.uid)), reason, false)
	_spear_left(gs, owner, u, reason, grant_song)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	_spear_left(gs, owner, u, "气绝")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("rtSpear", false) and int(u.front) == 0 and int(u.hp) > 0: remove_spear(gs, owner, u)
	refresh(gs)
static func _spear_entered(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	u.rtLeaveResolved = false
	var src: int = gs._unit_index_by_uid(owner, str(u.get("summonerUid", "")))
	if src >= 0:
		var master: Dictionary = gs.player(owner).units[src]
		if master.awakened and not u.get("rtAwakeApplied", false): gs._grow_unit(u, 4, 0); u.rtAwakeApplied = true
		if active(master) and master.get("formRules", {}).get("rtEternal", false):
			var enemies: Array = gs.player(1 - owner).units.filter(func(enemy): return int(enemy.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(enemy))
			if not enemies.is_empty(): gs.VerifiedRules.Stun.apply(gs, 1 - owner, gs._unit_index_by_uid(1 - owner, str(enemies[int(gs.next_random() % enemies.size())].uid)), 1, owner)
	refresh(gs)
static func summon_spear(gs, owner: int, src: int) -> int:
	var def: Dictionary = Content.unit_def("qianji-spear")
	if def.is_empty() or not def.has("attack") or not def.has("maxHp"):
		gs.VerifiedRules.event(gs, "rt-definition-unverified", {"player": owner, "definitionId": "qianji-spear"})
		return -1
	var p: Dictionary = gs.player(owner)
	var master: Dictionary = p.units[src]
	var attack := int(def.attack)
	var hp := int(def.maxHp)
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var bonus := 4 if master.awakened else 0
	var u: Dictionary = {"uid": "%s:sea-spear-%d" % [p.id, gs.next_card_id], "id": "qianji-spear", "name": "海原贝戟", "title": "千姬召唤物", "art": "assets/official/tokens/qianji-spear.png", "color": str(Content.runtime_unit_def(master).get("color", "#87c4de")), "baseAttack": attack, "baseMaxHp": hp, "attack": attack + bonus, "maxHp": hp, "hp": hp, "shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0, "unyielding": false, "level": 1, "front": 1, "attackBonus": bonus, "maxHpBonus": 0, "awakened": false, "form": {}, "formRules": {}, "formAbility": str(def.get("passive", {}).get("text", "")), "charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "countsAsShikigami": bool(def.get("countsAsShikigami", true)), "rtSpear": true, "rtAwakeApplied": master.awakened, "summonerUid": str(master.uid), "cannotAttack": bool(def.get("cannotAttack", false))}
	gs.next_card_id += 1
	p.units.append(u)
	var idx: int = p.units.size() - 1
	# An entry food card must finish before the resulting master's attack.
	# LIFO: reserve the attack below summon-created observers' food frames.
	if active(master) and master.get("formRules", {}).get("rtTideShaper", false): gs.resolution_stack.append({"kind": "rt-master-attack", "playerIndex": owner, "sourceIndex": src})
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": u.uid, "sourceUid": master.uid, "summonKind": "sea-spear"})
	refresh(gs)
	if active(master):
		if master.get("formRules", {}).get("rtDeepSea", false): gs.VerifiedRules.StarBear.suppress(gs, owner, 2, 0)
	_spear_entered(gs, owner, idx)
	gs.VerifiedRules.Weaver.entered(gs, owner, idx)
	return idx
static func describe_card(gs, owner: int, card: Dictionary, entry: Dictionary = {}) -> Dictionary:
	if not card.get("rabbitTideRules", false): return card
	var c := card.duplicate(true)
	if c.id == "c25006" and int(gs.player(owner).get("rtEnemyFoodTurn", -1)) == gs.turn_counter:
		c.enhanced = true; c.combatOption.pursuit = true; c.target = "enemy-unit"
		if not c.keywords.has("pursuit"): c.keywords.append("pursuit")
	if c.id == "c25003":
		var seen: Array = gs.player(owner).get("cookingSeenKinds", [])
		c.currentCardStats = "本局已获得：" + "、".join(seen.map(func(k): return str(Cooking.KIND_NAMES.get(str(k), k))))
		c.enhanced = not seen.is_empty()
	if c.id == "qianji-song":
		var src: int = gs._source_index(owner, c)
		if entry.get("rtSongInstant", false) or (src >= 0 and gs.player(owner).units[src].awakened):
			if not c.keywords.has("instant"): c.keywords.append("instant")
	return c
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("effect", "") in ["rt-spear-attack", "rt-spear-hunt"]: return live_spear(gs, owner) >= 0
	if card.get("effect", "") == "rt-awaken":
		var src: int = gs._source_index(owner, card)
		return src >= 0 and not gs.player(owner).units[src].awakened
	return true
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("rabbitTideRules", false) or card.get("effect", "") not in ["rt-tide-dream", "rt-call-tide", "rt-spear-hunt"] and not card.get("rtEntryFood", false): return null
	var ids: Array = []
	for side in ([owner, 1 - owner] if card.get("target", "") == "any-living-unit" else [1 - owner]):
		for u in gs.player(side).units:
			if int(u.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
			if card.get("target", "") == "enemy-unit" and int(u.level) < 1: continue
			if side != owner and (gs.VerifiedRules.Combat.has(u, "veil") or gs.VerifiedRules.Movement.has_veil(u)): continue
			ids.append(str(u.uid))
	return ids
static func form_entered(gs, _owner: int, _src: int, _card: Dictionary) -> void:
	refresh(gs)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"rt-form":
			gs._install_form(owner, src, card, effect.value)
			refresh(gs)
			if card.get("rtEntryFood", false): Cooking.auto_use_generated(gs, owner, src, target_id, "unknown")
		"rt-awaken":
			if not u.awakened:
				gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
				if role(u) == "tide":
					var idx := live_spear(gs, owner)
					if idx >= 0 and not gs.player(owner).units[idx].get("rtAwakeApplied", false):
						gs._grow_unit(gs.player(owner).units[idx], 4, 0); gs.player(owner).units[idx].rtAwakeApplied = true
		"rt-rabbit-combat":
			var options: Dictionary = card.get("combatOption", {}).duplicate(true)
			options.combatCard = card.duplicate(true)
			gs.resolution_stack.append({"kind": "rt-rabbit-attack", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "targetId": target_id, "options": options})
			if card.get("rtForage", false) and _fortune(gs, owner, src): gs._draw(owner, gs.VerifiedRules.Fortune.last_repeats(gs, owner))
		"rt-recipe":
			gs._draw(owner, 1)
			var seen: Array = gs.player(owner).get("cookingSeenKinds", [])
			if seen.has("mountain"): gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 3, "兔丸特制食谱")
			if seen.has("sea"): gs._heal_avatar(owner, 5)
			if seen.has("vegetable"): gs.VerifiedRules.StarBear.suppress(gs, owner, 3, 3)
		"rt-summon": summon_spear(gs, owner, src)
		"rt-spear-attack", "rt-spear-hunt":
			var idx := live_spear(gs, owner)
			if idx >= 0:
				gs._grow_unit(gs.player(owner).units[idx], 5 if str(effect.action) == "rt-spear-hunt" else 4, 0)
				var options: Dictionary = {"immuneCombat": true, "rtSpearAttack": true}
				if str(effect.action) == "rt-spear-hunt": options.pursuit = true
				gs._resolve_combat(owner, idx, 0, false, false, false, false, target_id, false, options)
		"rt-tide-dream":
			var victim := owner if gs._unit_index_by_uid(owner, str(target_id)) >= 0 else 1 - owner
			var idx: int = gs._unit_index_by_uid(victim, str(target_id))
			if idx >= 0: gs._damage_unit(victim, idx, 3, owner, src)
			if live_spear(gs, owner) >= 0: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 3, "汐梦")
		"rt-call-tide":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(target_id))
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)
			gs.VerifiedRules.StarBear.suppress(gs, owner, 2, 0)
			if live_spear(gs, owner) >= 0: gs._draw(owner, 1)
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", 0))
	var src := int(frame.get("sourceIndex", -1))
	match str(frame.get("kind", "")):
		"rt-awake-cook":
			if active(gs.player(owner).units[src]) and _fortune(gs, owner, src):
				for _i in gs.VerifiedRules.Fortune.last_repeats(gs, owner): Cooking.cook(gs, owner, src)
		"rt-lonely-food":
			if active(gs.player(owner).units[src]) and _fortune(gs, owner, src):
				for _i in gs.VerifiedRules.Fortune.last_repeats(gs, owner): Cooking.auto_use_generated(gs, owner, src, gs.player(owner).units[src].uid, "ingredient")
		"rt-combat-food":
			var target: Dictionary = gs._unit_by_uid(gs._all_units(), str(frame.targetUid))
			if not target.is_empty() and int(target.hp) > 0 and (not frame.fortune or _fortune(gs, owner, src)):
				for _i in (gs.VerifiedRules.Fortune.last_repeats(gs, owner) if frame.fortune else 1): Cooking.auto_use_generated(gs, owner, src, frame.targetUid, "unknown")
		"rt-combat-resume":
			var continuation: Dictionary = frame.combat
			var a: Dictionary = gs.player(int(continuation.playerIndex)).units[int(continuation.sourceIndex)]
			continuation.pierce = bool(continuation.pierce) or gs.VerifiedRules.Combat.has(a, "pierce")
			continuation.combo = bool(continuation.combo) or gs.VerifiedRules.Combat.has(a, "combo")
			gs._offer_attack_responses(continuation)
		"rt-rabbit-attack":
			var c: Dictionary = frame.card
			gs._grant_unit_armor(gs.player(owner).units[src], int(frame.options.get("shield", 0)))
			gs._resolve_combat(owner, src, int(c.value), bool(frame.options.get("pierce", false)), false, false, false, frame.targetId, false, frame.options)
		"rt-soul-damage":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(frame.targetUid))
			if idx >= 0: gs._damage_unit(1 - owner, idx, 3, owner, src)
		"rt-summon": summon_spear(gs, owner, src)
		"rt-master-attack":
			if active(gs.player(owner).units[src]): gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"rtAutomatic": true})
		"rt-spear-wave":
			gs._damage_avatar(1 - owner, 2, owner, src)
			for idx in gs.player(1 - owner).units.size():
				if int(gs.player(1 - owner).units[idx].hp) > 0: gs._damage_unit(1 - owner, idx, 2, owner, src)
		_: return false
	return true
static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("rabbitTideRules", false): return null
	if not can_use(gs, owner, card): return -100
	if card.get("rtEntryFood", false) or card.get("effect", "") == "rt-tide-dream":
		if gs._unit_index_by_uid(owner, str(target_id)) >= 0: return -100
	if card.get("effect", "") == "rt-awaken": return 65 if not gs.player(owner).units[gs._source_index(owner, card)].awakened else -10
	if card.id == "c25003": return 36 + gs.player(owner).get("cookingSeenKinds", []).size() * 12
	return 52
static func marks(gs, owner: int, u: Dictionary) -> Array:
	var result: Array = []
	if role(u) == "rabbit":
		result.append("本回合敌方食物增强：" + ("已达成" if int(gs.player(owner).get("rtEnemyFoodTurn", -1)) == gs.turn_counter else "未达成"))
		if not u.awakened: result.append("运势失败食材：" + ("本回合已触发" if int(u.get("rtFailureTurn", -1)) == gs.turn_counter else "本回合可触发"))
	if role(u) == "tide": result.append("海原贝戟在场" if live_spear(gs, owner) >= 0 else "海原贝戟不在场")
	if u.get("rtSpear", false): result.append("离场时，若手中没有咏流则获得一张")
	return result
