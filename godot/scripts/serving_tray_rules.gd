extends RefCounted

const ID := "sibing"
const MEAL := "sibing-meal"

static func source(gs, owner: int) -> int:
	return gs.VerifiedRules.DragonAbyss.source(gs, owner, ID)

static func has(u: Dictionary) -> bool:
	return u.get("servingTray", false)

static func markers(gs, owner: int) -> Array:
	var marked: Array = gs.player(owner).units.filter(func(u): return u.get("servingMarked", false))
	marked.sort_custom(func(a, b): return int(a.get("servingMarkedOrder", 0)) < int(b.get("servingMarkedOrder", 0)))
	return marked

static func mark(gs, owner: int, target: Dictionary, capacity: int) -> void:
	if target.get("servingMarked", false): return
	var marked := markers(gs, owner)
	for old in marked.slice(0, maxi(0, marked.size() - capacity + 1)):
		old.erase("servingMarked")
		old.erase("servingMarkedOrder")
	target.servingMarked = true
	target.servingMarkedOrder = gs.next_rule_event_id
	gs.VerifiedRules.event(gs, "serving-marked", {"player": owner, "uid": target.uid})

static func give(gs, owner: int, u: Dictionary) -> void:
	var src := source(gs, owner)
	if src < 0 or int(u.hp) <= 0 or has(u): return
	var p: Dictionary = gs.player(owner)
	var host: Dictionary = p.units[src]
	var carriers: Array = p.units.filter(func(a): return has(a))
	var max_trays := 2 if host.awakened else 1
	if carriers.size() >= max_trays:
		carriers.sort_custom(func(a,b): return int(a.servingTrayOrder) < int(b.servingTrayOrder))
		var old: Dictionary = carriers[0]
		old.erase("servingTray")
		gs._recalc(old)
	u.servingTray = true
	u.servingTrayOrder = gs.next_rule_event_id
	gs._recalc(u)
	gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": u.uid, "charm": "折敷"})
	if u == host:
		if u.get("formRules", {}).get("servingArtisan", false):
			u.swift = true
			if int(p.get("servingPermanent", 0)) < 4:
				p.servingPermanent = int(p.get("servingPermanent", 0)) + 1
				gs.VerifiedRules.Glutton.record_permanent(u, 1, 0)
				gs._grow_unit(u, 1, 0)
		if u.get("formRules", {}).get("servingButler", false):
			gs.resolution_stack.append({"kind": "serving-butler", "playerIndex": owner, "sourceIndex": src})
	if int(u.get("servingAttackTurn", -1)) == gs.turn_counter: return
	if p.realms.any(func(r): return r.get("nativeRealm") == "serving-lotus" and int(r.hp) > 0):
		u.servingAttackTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "serving-attack", "playerIndex": owner, "sourceIndex": gs._unit_index_by_uid(owner, u.uid)})

static func meal(gs, owner: int, src: int) -> void:
	var card: Dictionary = ContentLoader.card_def(MEAL)
	gs._push_card_frames(owner, MEAL, null, card, src, 0, true)

static func knocked(gs, owner: int, u: Dictionary) -> void:
	if owner < 0 or not has(u): return
	u.erase("servingTray")
	if int(u.front) == 1:
		var src := source(gs, owner)
		if src >= 0: gs.resolution_stack.append({"kind": "serving-meal", "playerIndex": owner, "sourceIndex": src})

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var p: Dictionary = gs.player(owner)
	var host: Dictionary = p.units[src]
	var marked := markers(gs, owner)
	var first := maxi(0, marked.size() - (2 if host.awakened else 1))
	for idx in marked.size():
		var u: Dictionary = marked[idx]
		u.erase("servingMarked")
		u.erase("servingMarkedOrder")
		if idx >= first: give(gs, owner, u)
	if gs.VerifiedRules.OwlInsect.active(host) and ((host.awakened and not has(host)) or not p.units.any(func(u): return has(u))): give(gs, owner, host)

static func attack_started(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if u.id == ID and u.get("formRules", {}).get("servingButler", false): give(gs, owner, u)

static func described(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("unitId") != ID: return card
	var src := source(gs, owner)
	if src < 0: return card
	var c := card.duplicate(true)
	var used: bool = int(gs.player(owner).get("servingMealTurn", -1)) == gs.turn_counter
	match str(c.id):
		"c64501":
			if inst.get("abyssReflectionUsed", false): c.keywords.erase("bounce")
		"c64504":
			c.value = 6 if used else 4
			c.effects[0].value = c.value
			c.currentCardStats = "当前伤害 %d" % c.value
		"c64507":
			if int(gs.player(owner).units[src].level) < int(c.level):
				c.level = 1
				c.combatOption.firstStrike = true
				c.keywords.append("first-strike")
			elif used:
				c.combatOption.combo = true
				c.keywords.append("combo")
	return c

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	match str(e.action):
		"abyss-serving-meal":
			p.servingMealTurn = gs.turn_counter
			var pool: Array = gs.VerifiedRules.DragonAbyss.living(gs, owner)
			if not pool.is_empty():
				var selected: Dictionary = pool[int(gs.next_random() % pool.size())]
				if u.get("formRules", {}).get("servingArtisan", false): give(gs, owner, selected)
				else: mark(gs, owner, selected, 2 if u.awakened else 1)
			for r in p.realms:
				if r.get("nativeRealm") != "serving-shop" or int(r.hp) <= 0: continue
				var rivals: Array = gs.VerifiedRules.DragonAbyss.living(gs, 1-owner)
				if not rivals.is_empty():
					var foe: Dictionary = rivals[int(gs.next_random() % rivals.size())]
					gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, foe.uid), 2, owner, src)
		"abyss-serving-courtesy":
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 1, "接物之道")
			gs.VerifiedRules.DragonAbyss.reflect_card(gs, owner, card)
			if gs.winner < 0: meal(gs, owner, src)
		"abyss-serving-form": gs._apply_form(owner, src, card, e.value)
		"abyss-serving-realm":
			gs._deploy_realm(owner, card)
			if not target.is_empty(): give(gs, owner, target)
		"abyss-serving-art":
			if not target.is_empty(): gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, target.uid), int(e.value), owner, src)
			if gs.winner < 0: meal(gs, owner, src)
		"abyss-serving-combat":
			if card.id == "c64505":
				gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
				give(gs, owner, u)
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, target_id)
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var owner := int(f.get("playerIndex", -1))
	var src := int(f.get("sourceIndex", -1))
	match f.get("kind"):
		"serving-meal": meal(gs, owner, src)
		"serving-attack": gs.VerifiedRules.DragonAbyss.attack(gs, owner, src, null, {"immuneCombat": true})
		"serving-butler":
			for u in gs.VerifiedRules.DragonAbyss.living(gs, 1-owner): gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, u.uid), 1, owner, src)
		_: return false
	return true
