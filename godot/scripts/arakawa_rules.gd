class_name ArakawaRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")

static func source(u: Dictionary) -> bool:
	return Content.runtime_unit_def(u).get("arakawaRules", false)

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func count(gs, owner: int) -> int:
	return int(gs.player(owner).get("arkUsed", 0)) if int(gs.player(owner).get("arkCountTurn", -1)) == gs.turn_counter else 0

static func announced(gs, frame: Dictionary, _card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	p.arkUsed = count(gs, owner) + 1; p.arkCountTurn = gs.turn_counter
	var observers: Array = []
	for u in p.units:
		if source(u) and active(u): observers.append({"uid": str(u.uid), "fish": u.get("formRules", {}).get("arkFish", false), "home": u.get("formRules", {}).get("arkHome", false)})
	for observer in observers:
		if observer.home and int(p.arkUsed) in [2,3,4]:
			gs.resolution_stack.append({"kind":"ark-home","playerIndex":owner,"sourceIndex":gs._unit_index_by_uid(owner,str(observer.uid)),"ordinal":int(p.arkUsed)})
	for queued in gs.resolution_stack:
		if queued.get("kind") == "card-complete" and int(queued.get("resolutionId", -1)) == int(frame.resolutionId):
			queued.arkOrdinal = int(p.arkUsed); queued.arkObservers = observers.duplicate(true)

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex); var ordinal := int(frame.get("arkOrdinal", 0))
	# Trigger objects present at declaration; a just-installed form cannot
	# retroactively observe its own declaration.
	for saved in frame.get("arkObservers", []):
		var src: int = gs._unit_index_by_uid(owner, str(saved.uid))
		if src < 0 or not active(gs.player(owner).units[src]): continue
		if ordinal == 2:
			gs.resolution_stack.append({"kind": "ark-second", "playerIndex": owner, "sourceIndex": src})
			if saved.fish and gs.player(owner).units[src].get("formRules", {}).get("arkFish", false): gs.resolution_stack.append({"kind": "ark-fish", "playerIndex": owner, "sourceIndex": src})
	if str(card.id) in ["c27101", "c27102", "c27106"] and card.get("usedFromHand", not frame.get("automatic", false) and not card.get("lilyFromDeck", false) and not card.get("twoFacesFromDeck", false)):
		gs.resolution_stack.append({"kind": "ark-store", "playerIndex": owner, "sourceIndex": int(frame.sourceIndex), "card": card.duplicate(true)})

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("id") != "c27104": return card
	var c := card.duplicate(true)
	c.enhanced = count(gs, owner) >= 2
	c.value = 6 if c.enhanced else 4; c.effects[0].value = c.value
	c.currentCardStats = "本回合已用%d张其他牌 · %d伤害" % [count(gs, owner), int(c.value)]
	return c

static func targets(gs, owner: int, card: Dictionary):
	if str(card.get("id", "")) not in ["c27104", "c27107", "arakawa-annihilate"]: return null
	var ids: Array = []
	for side in [owner, 1-owner]:
		for u in gs.player(side).units:
			if int(u.hp) > 0 and not u.get("removed", false) and int(u.level)>0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil")): ids.append(str(u.uid))
	return ids

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("id") != "c27107" or not gs.player(owner).units[gs._source_index(owner, card)].has("lanternStored")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"ark-fire": gs._set_fire(owner, int(gs.player(owner).energy) + 1)
		"ark-projectile": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2 + int(u.get("spellPower", 0)), "聚流")
		"ark-torrent":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, str(target_id))
				if idx >= 0: gs._damage_unit(side, idx, int(card.value) + int(u.get("spellPower", 0)), owner, src)
		"ark-divine-draw":
			gs.resolution_stack.append({"kind": "ark-draw", "playerIndex": owner, "sourceIndex": src})
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		"ark-devour":
			var target: Dictionary = gs._unit_by_uid(gs._all_units(), str(target_id))
			if target.is_empty() or int(target.hp) <= 0: return true
			var c: Dictionary = Content.card_def("arakawa-annihilate").duplicate(true)
			if gs.VerifiedRules.ChargedPair.store_copy(gs, owner, src, c, target_id):
				for side in 2:
					var idx: int = gs._unit_index_by_uid(side, str(target_id))
					if idx >= 0: gs.VerifiedRules.Movement.hold(gs, owner, src, side, idx)
				u.arkHeldTarget = str(target_id)
		"ark-annihilate":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, str(target_id))
				if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, side, idx, card)
		"ark-awaken":
			if not u.awakened: gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
			else:
				gs.VerifiedRules.Glutton.record_permanent(u, 1, 1, true); gs.VerifiedRules.SunSmoke.remember_permanent(u, 1, 1); gs._grow_unit(u, 1, 1)
		_: return false
	return true

static func refresh_hold(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if u.has("arkHeldTarget") and not u.has("lanternStored"):
				gs.VerifiedRules.Movement.clear_hold(gs, u); u.erase("arkHeldTarget")
			if u.get("arkFish", false) and not u.get("removed", false) and (int(u.hp) <= 0 or int(u.front) == 0): remove_fish(gs, gs.players.find(p), u)

static func remove_fish(gs, owner: int, u: Dictionary) -> void:
	if not u.get("arkFish", false) or u.get("removed", false): return
	var idx: int = gs._unit_index_by_uid(owner, str(u.uid))
	gs.VerifiedRules.Otakemaru.remove_charm(gs, owner, idx, "游鱼离场")
	gs.VerifiedRules.Vine.remove_charm(gs, owner, idx, "游鱼离场", false)
	u.hp = 0; u.front = 0; u.knockout = 0; u.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": u.uid, "reason": "游鱼离开战斗区"})

static func summon_fish(gs, owner: int, src: int) -> void:
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var p: Dictionary = gs.player(owner)
	var u := {"id": "arakawa-youyu", "name": "游鱼", "title": "荒川之主召唤物", "uid": "%s:youyu-%d" % [p.id, gs.next_card_id], "art": Content.unit_def("huangchuanzhizhu").art, "color": "#81b8de", "baseAttack": 2, "baseMaxHp": 2, "attack": 2, "maxHp": 2, "hp": 2, "attackBonus": 0, "maxHpBonus": 0, "shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0, "unyielding": false, "level": 1, "front": 1, "awakened": false, "form": {}, "formRules": {}, "formAbility": "", "charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "countsAsShikigami": true, "arkFish": true, "summonerUid": str(p.units[src].uid)}
	u.awakenedArt = u.art; gs.next_card_id += 1; p.units.append(u)
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": u.uid, "sourceUid": u.summonerUid, "summonKind": "游鱼"})
	gs._fire_hooks(owner, p.units.size()-1, "unit-entered-front", {})
	gs._run_form_hooks(owner, p.units.size()-1, "unit-entered-front", {})
	gs.VerifiedRules.automatic_response(gs, 1-owner, "enemy-entered-front", u.uid, {"kind": "response-complete"})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("ark-"): return false
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	match kind:
		"ark-store": gs.VerifiedRules.ChargedPair.store_copy(gs, owner, src, frame.card, null)
		"ark-draw": gs._draw(owner, 1)
		"ark-fish":
			if active(u) and u.get("formRules", {}).get("arkFish", false): summon_fish(gs, owner, src)
		"ark-second":
			if not active(u): return true
			if u.awakened:
				gs.VerifiedRules.base_damage_avatar(gs, owner, src, 1-owner, 2)
				gs.VerifiedRules.Stun.apply(gs, 1-owner, -1, 1, owner)
			else:
				var pool: Array = gs.player(1-owner).units.filter(func(t): return int(t.hp)>0 and not t.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(t))
				if not pool.is_empty():
					var high := 0
					for target in pool: high = maxi(high, int(target.attack))
					pool = pool.filter(func(t): return int(t.attack) == high)
					var target: Dictionary = pool[int(gs.next_random() % pool.size())]
					gs.VerifiedRules.base_damage_unit(gs, owner, src, 1-owner, gs._unit_index_by_uid(1-owner, str(target.uid)), 1)
		"ark-home":
			if not active(u) or not u.get("formRules", {}).get("arkHome", false): return true
			match int(frame.ordinal):
				2:
					var old: Dictionary = gs._card_effect_context; gs._card_effect_context = {}
					for target in gs.player(1-owner).units.duplicate():
						if int(target.hp) > 0 and not target.get("removed", false): gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, str(target.uid)), 1, owner, src)
					gs._damage_avatar(1-owner, 1, owner, src); gs._card_effect_context = old
				3: gs.VerifiedRules.Divination.start(gs, owner, 2)
				4:
					for target in gs.player(owner).units: gs._heal_unit(target, 3)
					gs._heal_avatar(owner, 3)
	return true

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("arakawaRules", false): return null
	if str(card.id) in ["c27104", "c27107", "arakawa-annihilate"] and gs._unit_index_by_uid(owner, str(target_id)) >= 0: return -100
	if card.id == "c27108": return 65 if not gs.player(owner).units[gs._source_index(owner, card)].awakened else 5
	return 45

static func marks(gs, owner: int, u: Dictionary) -> Array:
	var result: Array = []
	if source(u): result.append("本回合用牌%d张 · 第二张%s" % [count(gs, owner), "对牌手2伤并眩晕" if u.awakened else "最大力量敌方式神1伤"])
	if u.has("arkHeldTarget"): result.append("吞噬 · 蓄力期间持续眩晕")
	if u.get("arkFish", false): result.append("游鱼 · 2/2 · 离开战斗区移除")
	return result
