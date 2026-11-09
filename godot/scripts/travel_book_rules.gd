extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "shuweng-zhixing"
const ORIGINS := ["abyss-travel-mulligan", "abyss-travel-draw", "abyss-travel-ink", "abyss-travel-form", "abyss-travel-revive", "abyss-travel-final"]

static func source(gs, owner: int) -> int:
	return gs.VerifiedRules.DragonAbyss.source(gs, owner, ID)

static func gain(gs, owner: int, amount: int = 1) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	u.travelNotes = int(u.get("travelNotes", 0)) + amount
	gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": u.uid, "charm": "游记", "amount": amount})

static func spend(gs, owner: int) -> bool:
	var src := source(gs, owner)
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.get("travelNotes", 0)) <= 0: return false
	u.travelNotes -= 1
	gs.VerifiedRules.event(gs, "travel-note-spent", {"player": owner, "uid": u.uid})
	return true

static func realm(gs, owner: int, kind: String) -> Array:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm", "") == kind and int(r.hp) > 0)

static func units_aura(gs, unit: Dictionary) -> int:
	if not gs.VerifiedRules.OwlInsect.shikigami(unit): return 0
	for owner in gs.players.size():
		if gs._unit_index_by_uid(owner, unit.uid) >= 0 and not realm(gs, 1-owner, "travel-mist").is_empty(): return -1
	return 0

static func refresh_mist(gs, owner: int) -> void:
	for u in gs.player(1-owner).units: gs._recalc(u)
	for u in gs.player(1-owner).units:
		if int(u.hp) <= 0 and int(u.knockout) == 0 and not u.get("removed", false): gs._knockout_unit(u)

static func described(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("unitId") != ID: return card
	var view := card.duplicate(true)
	var src := source(gs, owner)
	var notes := 0 if src < 0 else int(gs.player(owner).units[src].get("travelNotes", 0))
	view.currentCardStats = "游记 %d" % notes
	if card.id == "c64301" and inst.get("abyssReflectionUsed", false): view.keywords.erase("bounce")
	return view

static func announced(gs, owner: int, src: int, card: Dictionary) -> void:
	var depth: int = gs.resolution_stack.size()
	for r in realm(gs, 1-owner, "travel-mist"):
		r.hp -= 1
		gs.VerifiedRules.event(gs, "realm-durability", {"player": 1-owner, "realm": r.uid, "amount": 1, "remaining": r.hp})
		if int(r.hp) <= 0: gs.VerifiedRules.Huang.destroy(gs, 1-owner, r, "夙雾盘岭耗尽")
	var book := source(gs, owner)
	if book < 0: return
	var u: Dictionary = gs.player(owner).units[book]
	if int(u.hp) <= 0 or int(u.level) <= 0 or u.get("baseRulesSuppressed", false): return
	if src >= 0 and card.get("usedFromHand", false):
		u.travelHandUses = int(u.get("travelHandUses", 0)) + 1
		if bool(u.awakened) or int(u.travelHandUses) % 2 == 0: gain(gs, owner)
	if owner != gs.current_player or src < 0 or src == book: return
	for r in realm(gs, owner, "travel-canon"):
		if int(r.get("travelUsedTurn", -1)) == gs.turn_counter: continue
		r.travelUsedTurn = gs.turn_counter
		if spend(gs, owner):
			gs.resolution_stack.insert(depth, {"kind": "travel-canon", "playerIndex": owner, "sourceIndex": book, "targetIndex": src, "option": int(gs.next_random() % 4)})

static func turns_boundary(gs) -> void:
	for owner in 2:
		for r in realm(gs, owner, "travel-mist"): r.hp = 3

static func turn_start(gs, owner: int) -> void:
	if gs.player(owner).get("travelFinal", false):
		gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})

static func empty_draw(gs, owner: int) -> bool:
	if not gs.player(owner).get("travelFinal", false): return false
	gs._damage_avatar(1-owner, 10, owner, source(gs, owner))
	return true

static func turn_draw(gs, owner: int) -> bool:
	var src := source(gs, owner)
	var deck: Array = gs.player(owner).deck
	if src < 0 or deck.is_empty(): return false
	var u: Dictionary = gs.player(owner).units[src]
	if not u.awakened or not gs.VerifiedRules.OwlInsect.active(u) or not spend(gs, owner): return false
	var ids: Array = deck.slice(maxi(0, deck.size()-3)).map(func(c): return c.instanceId)
	ids.reverse()
	gs.VerifiedRules.DragonAbyss.choose(gs, owner, "travel-draw", ids, src, "翰墨逸香")
	return true

static func choice(gs, owner: int, iid: String, c: Dictionary) -> bool:
	if c.get("type") != "abyss-travel-draw": return false
	var inst: Dictionary = gs.VerifiedRules.Baize.take_deck_instance(gs, owner, iid)
	if not inst.is_empty(): gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
	gs._shuffle(gs.player(owner).deck)
	return true

static func trigger_realm(gs, owner: int, r: Dictionary) -> bool:
	if r.get("nativeRealm") != "travel-sea": return false
	var deck: Array = gs.player(owner).deck
	var matches: Array = deck.filter(func(c): return Content.card_def(str(c.definitionId)).get("unitId") == ID)
	if not matches.is_empty() and spend(gs, owner):
		var inst: Dictionary = matches[int(gs.next_random() % matches.size())]
		deck.erase(inst)
		gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
	return true

static func gain_exclusive(gs, owner: int, u: Dictionary, instant: bool = false) -> void:
	var pool: Array = gs.VerifiedRules.DragonAbyss.exclusive(u)
	if pool.is_empty(): return
	var card: Dictionary = pool[int(gs.next_random() % pool.size())]
	var inst: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, card.id)
	if instant: inst.travelInstant = true
	gs.VerifiedRules.Baize.put_hand(gs, owner, inst)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary) -> bool:
	var p: Dictionary = gs.player(owner)
	var enemy := 1-owner
	match str(e.action):
		"abyss-travel-far":
			if not target.is_empty() and (spend(gs, owner) or int(gs.next_random() % 2) == 1): gain_exclusive(gs, owner, target)
			gs.VerifiedRules.DragonAbyss.reflect_card(gs, owner, card)
		"abyss-travel-journal":
			gain(gs, owner)
			gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		"abyss-travel-canon":
			gs._deploy_realm(owner, card)
			gain(gs, owner)
		"abyss-travel-pen":
			var full := spend(gs, owner)
			gs.resolution_stack.append({"kind": "travel-pen", "playerIndex": owner, "sourceIndex": src, "heal": 5 if full else 2 + int(gs.next_random() % 4)})
			gs._draw(owner, 2 if full else 1 + int(gs.next_random() % 2))
		"abyss-travel-mist":
			gs._deploy_realm(owner, card)
			refresh_mist(gs, owner)
		"abyss-travel-awake": gs._awaken(owner, src, card, e.value)
		"abyss-travel-read":
			if card.get("trickMode", false):
				if not target.is_empty(): gs._grow_unit(target, 1, 1)
				gain(gs, owner)
			else:
				var maxed := spend(gs, owner)
				var attack := 0
				var life := 0
				for repeat in 3: attack += 1 if maxed else int(gs.next_random() % 2)
				for repeat in 3: life += 1 if maxed else int(gs.next_random() % 2)
				for u in gs.VerifiedRules.DragonAbyss.living(gs, owner): gs._grow_unit(u, attack, life)
		"abyss-travel-sea":
			p.deck = p.deck.filter(func(inst): return Content.card_def(str(inst.definitionId)).get("unitId") != ID)
			for id in ORIGINS: p.deck.append(gs.VerifiedRules.Insight.instance(gs, owner, id))
			gs._shuffle(p.deck)
			gs._deploy_realm(owner, card)
			trigger_realm(gs, owner, p.realms.back())
		"abyss-travel-mulligan":
			if p.hand.is_empty() or int(p.get("travelMulligans", 0)) >= 9: return true
			p.travelMulligans = int(p.get("travelMulligans", 0)) + 1
			var n: int = p.hand.size()
			p.deck.append_array(p.hand)
			p.hand.clear()
			gs._shuffle(p.deck)
			gs._draw(owner, n)
			if int(p.travelMulligans) < 9:
				var inst: Dictionary = card.get("playedInstance", {})
				if not inst.is_empty(): gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
		"abyss-travel-draw": gs._draw(owner, 4)
		"abyss-travel-ink":
			var full := spend(gs, owner)
			var pool: Array = gs.VerifiedRules.DragonAbyss.living(gs, enemy)
			pool.append({})
			for i in mini(5, pool.size()):
				var u: Dictionary = pool.pop_at(int(gs.next_random() % pool.size()))
				var amount := 5 if full else int(gs.next_random() % 6)
				if u.is_empty(): gs._damage_avatar(enemy, amount, owner, src)
				else: gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, u.uid), amount, owner, src)
		"abyss-travel-form": gs._apply_form(owner, src, card, e.value)
		"abyss-travel-revive":
			for u in p.units:
				if u == p.units[src]: continue
				if gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false): gain_exclusive(gs, owner, u, true)
		"abyss-travel-final":
			p.travelFinal = true
			gs._awaken(owner, src, card, e.value)
		_: return false
	return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var owner := int(f.get("playerIndex", -1))
	match f.get("kind"):
		"travel-pen":
			gs._heal_avatar(owner, int(f.heal))
			gs.VerifiedRules.NativeSummons.summon(gs, owner, int(f.sourceIndex), "travel-ink", "不尽墨", 3, 3, {"barrier": true})
		"travel-canon":
			var src := int(f.sourceIndex)
			match int(f.option):
				0: gs._grow_unit(gs.player(owner).units[int(f.targetIndex)], 1, 1)
				1: gs._draw(owner, 1)
				2: gs.VerifiedRules.base_damage_projectile(gs, owner, src, 2, "志行无量书")
				3:
					for idx in gs.player(owner).units.size(): gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1, owner, false)
		"travel-ink-left": gs._draw(owner, 1)
		_: return false
	return true
