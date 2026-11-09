extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const ID := "chili"
const TREASURES := ["chili-mirror", "chili-vase", "chili-talisman", "chili-scroll", "chili-tower", "chili-pearl"]
const FACTIONS := {"红莲": "red", "紫岩": "purple", "青岚": "blue", "苍叶": "green"}

static func source(gs, owner: int) -> int:
	return gs.VerifiedRules.DragonAbyss.source(gs, owner, ID)

static func count(gs, owner: int) -> int:
	return int(gs.player(owner).get("chiliDiscards", 0))

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("unitId") != ID: return card
	var c := card.duplicate(true)
	if c.id == "c64704" and count(gs, owner) >= 3:
		c.value.attack = 7
		c.effects[0].value = c.value
		c.currentCardStats = "增强 · 7力量/6生命 · 迅捷"
	if c.id in ["c64704", "c64707"] and not c.has("currentCardStats"): c.currentCardStats = "本局弃牌 %d/3" % count(gs, owner)
	return c

static func request_discard(gs, owner: int, src: int) -> void:
	var ids: Array = gs.player(owner).hand.map(func(c): return c.instanceId)
	gs.VerifiedRules.DragonAbyss.choose(gs, owner, "chili-discard", ids, src, "螭璃 · 选择弃牌", {"zone": "hand"})

static func choice(gs, owner: int, iid: String, c: Dictionary) -> bool:
	match str(c.type):
		"abyss-chili-discard":
			var i: int = gs.player(owner).hand.find_custom(func(inst): return inst.instanceId == iid)
			if i >= 0:
				var old: Dictionary = gs._card_effect_context
				gs._card_effect_context = {"definitionId": "c647-choice"}
				gs.discard_hand_card(owner, i)
				gs._card_effect_context = old
		"abyss-chili-treasure", "abyss-chili-exclusive": gs.VerifiedRules.DragonAbyss.put(gs, owner, iid)
		_: return false
	return true

static func discarded(gs, holder: int, inst: Dictionary) -> void:
	var card := Content.card_def(str(inst.definitionId))
	var holder_src := source(gs, holder)
	if card.get("id") == "c64703" and holder_src >= 0:
		gs.resolution_stack.append({"kind": "chili-dragon-jump", "playerIndex": holder, "sourceIndex": holder_src})
		gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": holder, "count": 1})
	var context: Dictionary = gs._card_effect_context
	var owner := int(context.get("playerIndex", holder))
	var source_card := str(context.get("definitionId", ""))
	var src := source(gs, owner)
	if src < 0: return
	var p: Dictionary = gs.player(owner)
	var host: Dictionary = p.units[src]
	if owner != holder and not (host.awakened and source_card == "c62205"): return
	p.chiliDiscards = count(gs, owner)+1
	var original: int = gs._source_index(owner, card)
	for r in p.realms:
		if r.get("nativeRealm") == "chili-pavilion" and int(r.hp) > 0 and original >= 0:
			gs.VerifiedRules.HairPower.give(gs, owner, original, 1)
			gs._grant_unit_armor(p.units[original], 1)
	if not gs.VerifiedRules.OwlInsect.active(host) or int(host.get("chiliStoredTurn", -1)) == gs.turn_counter: return
	if not host.awakened and not source_card.begins_with("c647"): return
	var faction := Factions.printed({"id": str(card.get("unitId", ""))})
	var name: String = FACTIONS.get(faction, "neutral")
	var derived := Content.card_def("chili-%s-%s" % ["cloud" if host.awakened else "breath", name])
	host.chiliStoredTurn = gs.turn_counter
	host.lanternStored = {"card": derived, "turn": gs.turn_counter, "order": gs.next_rule_event_id}
	gs.VerifiedRules.event(gs, "lantern-stored", {"player": owner, "uid": host.uid, "card": derived})

static func gain_random(gs, owner: int, prioritize_living: bool) -> void:
	var p: Dictionary = gs.player(owner)
	var pool: Array = p.units.filter(func(u): return not u.get("removed", false) and not u.get("summoned", false) and not gs.VerifiedRules.DragonAbyss.exclusive(u).is_empty())
	if prioritize_living:
		var living := pool.filter(func(u): return int(u.hp) > 0)
		if not living.is_empty(): pool = living
	for i in 2:
		if not pool.is_empty(): gs.VerifiedRules.DragonAbyss.Travel.gain_exclusive(gs, owner, pool[int(gs.next_random() % pool.size())])

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	if p.get("chiliVoid", false): gain_random(gs, owner, true)
	for u in p.units:
		if int(u.hp) > 0 and u.get("chiliJourney", false):
			u.swift = true
			u.inspired = true

static func describe_hand(gs, owner: int, card: Dictionary, from_hand: bool) -> Dictionary:
	if not from_hand or not gs.player(owner).get("chiliVoid", false) or int(gs.player(owner).get("chiliUsedHandTurn", -1)) == gs.turn_counter: return card
	var view := card.duplicate(true)
	view.chiliHandFree = true
	return view

static func announced(gs, owner: int, card: Dictionary) -> void:
	if card.get("usedFromHand", false): gs.player(owner).chiliUsedHandTurn = gs.turn_counter

static func resolve_token(gs, owner: int, src: int, card: Dictionary, action: String, target: Dictionary) -> bool:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var enemy := 1-owner
	match action:
		"abyss-chili-breath", "abyss-chili-cloud":
			var cloud := action == "abyss-chili-cloud"
			match str(card.id).get_slice("-", 2):
				"red":
					if cloud: gs.VerifiedRules.Glutton.record_permanent(u, 1, 1)
					gs._grow_unit(u, 1, 1)
				"purple": gs.VerifiedRules.HairPower.grant_guard(gs, owner, 2 if cloud else 1, 1 if cloud else 0)
				"blue":
					var idx: int = gs.front_index(enemy)
					if cloud: gs._damage_avatar(enemy, 1, owner, src)
					for i in gs.player(enemy).units.size():
						if int(gs.player(enemy).units[i].hp) > 0: gs._damage_unit(enemy, i, 2 if cloud and i == idx else 1, owner, src)
				"green":
					if cloud: gs.VerifiedRules.DragonAbyss.attack(gs, owner, src, null, {"immuneCombat": true}, 1)
					else: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, "蟠息")
				"neutral": gs._heal_avatar(owner, 4 if cloud else 2)
		"abyss-chili-mirror":
			u.barrier = true
			gs.VerifiedRules.Glutton.record_permanent(u, 1, 1)
			gs._grow_unit(u, 1, 1)
		"abyss-chili-vase":
			if target.is_empty(): return true
			var side := owner if gs._unit_index_by_uid(owner, target.uid) >= 0 else enemy
			var idx: int = gs._unit_index_by_uid(side, target.uid)
			gs.raise_unit_level(side, idx)
			var pool: Array = gs.VerifiedRules.DragonAbyss.exclusive(target)
			var ids: Array = []
			for i in mini(3, pool.size()): ids.append(pool.pop_at(int(gs.next_random() % pool.size())).id)
			gs.VerifiedRules.DragonAbyss.choose(gs, owner, "chili-exclusive", ids, src, "九转玉露瓶", {"useCardIds": true})
		"abyss-chili-talisman":
			if target.is_empty(): return true
			target.swift = true
			target.inspired = true
			if card.get("focusPaid", false): target.chiliJourney = true
		"abyss-chili-scroll":
			gs._apply_encourage(owner, 0, 3, 3)
			gs._apply_encourage(enemy, -3, -3)
		"abyss-chili-tower":
			var idx: int = gs.front_index(enemy)
			if idx >= 0: gs._damage_unit(enemy, idx, 8, owner, src)
		"abyss-chili-pearl":
			for side in [owner, enemy]:
				for target_unit in gs.player(side).units:
					if gs.VerifiedRules.Peach.revive(gs, side, -1, target_unit, false, false):
						gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 3, "北冥定魂珠")
		_: return false
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var enemy := 1-owner
	var side := owner if not target.is_empty() and gs._unit_index_by_uid(owner, target_id) >= 0 else enemy
	var idx: int = -1 if target.is_empty() else gs._unit_index_by_uid(side, target_id)
	match str(e.action):
		"abyss-chili-roar":
			if idx >= 0:
				target.enraged = true
				gs._damage_unit(side, idx, 4, owner, src)
			if gs.winner < 0: request_discard(gs, owner, src)
		"abyss-chili-pavilion":
			gs._deploy_realm(owner, card)
			if idx >= 0:
				gs.resolution_stack.append({"kind": "chili-pavilion", "playerIndex": owner, "sourceIndex": idx, "side": side})
			request_discard(gs, owner, src)
		"abyss-chili-jump":
			var front: int = gs.front_index(enemy)
			if front >= 0: gs._damage_unit(enemy, front, int(u.attack), owner, src)
		"abyss-chili-form":
			gs._apply_form(owner, src, card, e.value)
			if count(gs, owner) >= 3: u.swift = true
		"abyss-chili-bite":
			if idx >= 0:
				var hit: Dictionary = gs._damage_unit(side, idx, 6, owner, src)
				if side != owner and int(hit.get("overkill", 0)) > 0: gs._damage_avatar(side, int(hit.overkill), owner, src)
			if gs.winner < 0: request_discard(gs, owner, src)
		"abyss-chili-awake":
			gs.resolution_stack.append({"kind": "chili-awaken", "playerIndex": owner, "sourceIndex": src, "card": card, "stats": e.value})
			request_discard(gs, owner, src)
		"abyss-chili-treasure":
			var pool := TREASURES.duplicate()
			var picks: Array = []
			for i in 3: picks.append(pool.pop_at(int(gs.next_random() % pool.size())))
			if count(gs, owner) >= 3:
				for id in picks: gs.VerifiedRules.DragonAbyss.put(gs, owner, id)
			else: gs.VerifiedRules.DragonAbyss.choose(gs, owner, "chili-treasure", picks, src, "龙宫秘宝", {"useCardIds": true})
		"abyss-chili-void":
			p.chiliVoid = true
			var depth: int = gs.resolution_stack.size()
			var n: int = p.hand.size()
			for i in n: gs.discard_hand_card(owner, 0)
			gs.resolution_stack.insert(depth, {"kind": "chili-void-gain", "playerIndex": owner})
		_: return resolve_token(gs, owner, src, card, str(e.action), target)
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var owner := int(f.get("playerIndex", -1))
	var src := int(f.get("sourceIndex", -1))
	match f.get("kind"):
		"chili-dragon-jump":
			var idx: int = gs.front_index(1-owner)
			if idx >= 0: gs._damage_unit(1-owner, idx, 3, owner, src)
		"chili-awaken":
			var depth: int = gs.resolution_stack.size()
			gs.resolution_stack.insert(depth, {"kind": "chili-awaken-complete", "playerIndex": owner, "sourceIndex": src, "card": f.card, "stats": f.stats})
			gs._draw(owner, 1)
		"chili-awaken-complete": gs._awaken(owner, src, f.card, f.stats)
		"chili-pavilion":
			var side := int(f.side)
			var u: Dictionary = gs.player(side).units[src]
			u.abyssPierceTurn = gs.turn_counter
			gs.VerifiedRules.HairPower.give(gs, side, src, 1)
		"chili-void-gain": gain_random(gs, owner, false)
		_: return false
	return true
