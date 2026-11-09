class_name GuishiheiRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")

static func source(unit: Dictionary) -> bool:
	return Content.runtime_unit_def(unit).get("guishiheiRules", false)

static func living(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))

static func marked(unit: Dictionary, owner: int) -> bool:
	return int(unit.get("ghSoulOwner", -1)) == owner

static func attach(gs, owner: int, unit: Dictionary) -> void:
	if unit.is_empty() or int(unit.hp) <= 0 or marked(unit, owner): return
	if gs.VerifiedRules.ZenMisfortune.protect(gs, 1-owner, unit, owner): return
	unit.ghSoulOwner = owner
	gs.VerifiedRules.event(gs, "soul-charm-attached", {"player": owner, "uid": unit.uid, "carrierPlayer": 1-owner})

static func attack_targets(gs, owner: int, src: int):
	if not source(gs.player(owner).units[src]) and not gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "gh-awake" and int(r.hp) > 0): return null
	var enemy := 1 - owner
	var marks := living(gs, enemy).filter(func(u): return marked(u, owner))
	if marks.is_empty(): return null
	var front: Dictionary = gs.front_unit(enemy)
	var targets: Array = [] if front.is_empty() else [front.uid]
	for unit in marks:
		if int(unit.front) == 0 and not gs.VerifiedRules.Combat.has(unit, "veil"): targets.append(unit.uid)
	return targets

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	var src: int = gs._source_index(owner, card) if card.get("guishiheiRules", false) or card.get("type") == "combat" else -1
	if src < 0: return card
	if card.id == "c62807" and int(gs.player(owner).units[src].level) < int(card.level):
		var view := card.duplicate(true)
		view.printedLevel = card.level
		view.level = 1
		view.target = "enemy-unit"
		view.ghTrick = true
		view.currentCardStats = "戏法：只结附索魂"
		return view
	if card.get("type") == "combat" and card.get("effect") == "assault" and card.get("target", "auto") in ["auto", "enemy-unit"] and attack_targets(gs, owner, src) != null:
		var view := card.duplicate(true)
		view.target = "enemy-unit"
		view.ghAttackTarget = true
		return view
	return card

static func card_targets(gs, owner: int, card: Dictionary):
	if card.get("ghAttackTarget", false):
		return attack_targets(gs, owner, gs._source_index(owner, card))
	if card.get("guishiheiRules", false) and card.get("target") == "enemy-unit":
		return living(gs, 1-owner).filter(func(u): return not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return u.uid)
	return null

static func mark_reserve(gs, owner: int) -> void:
	var pool := living(gs, 1-owner).filter(func(u): return int(u.front) == 0)
	if not pool.is_empty(): attach(gs, owner, pool[int(gs.next_random() % pool.size())])

static func turn_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "gh-parting": return false
	mark_reserve(gs, owner)
	return true

static func prepare_hit(gs, owner: int, src: int, target: Dictionary, frame: Dictionary) -> void:
	if target.is_empty() or frame.get("ghPrepared", false): return
	frame.ghPrepared = true
	var unit: Dictionary = gs.player(owner).units[src]
	if source(unit) and unit.get("formRules", {}).get("ghFeather", false) and marked(target, owner):
		frame.options.immuneCombat = true
	if int(target.front) == 0 and gs.VerifiedRules.OwlInsect.shikigami(unit) and gs.VerifiedRules.OwlInsect.shikigami(target):
		for realm in gs.player(owner).realms:
			if realm.get("nativeRealm") != "gh-parting" or int(realm.hp) <= 0: continue
			gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
			frame.pierce = true

static func grow(gs, unit: Dictionary, attack: int, hp: int) -> void:
	gs.VerifiedRules.Glutton.record_permanent(unit, attack, hp)
	gs._grow_unit(unit, attack, hp)

static func killed(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if owner == victim or idx < 0 or not (result.get("bodyKnocked", false) or result.get("knocked", false)): return
	var target: Dictionary = gs.player(victim).units[idx]
	if target.get("summoned", false) and not target.get("countsAsShikigami", false): return
	var unit: Dictionary = gs.player(owner).units[src]
	for observer in gs.player(owner).units:
		if not source(observer) or int(observer.hp) <= 0 or int(observer.level) < 1: continue
		if observer.awakened:
			grow(gs, observer, 1, 0)
		elif observer == unit and gs.current_player == owner and int(unit.get("ghKills", 0)) < 3 and int(unit.get("ghKillTurn", -1)) != gs.turn_counter:
			unit.ghKills = int(unit.get("ghKills", 0)) + 1
			unit.ghKillTurn = gs.turn_counter
			grow(gs, unit, 1, 0)
	if not source(unit) or int(unit.hp) <= 0: return
	if options.get("combatCard", {}).get("id") == "c62806" and not options.get("ghBladeGrown", false):
		options.ghBladeGrown = true
		grow(gs, unit, 1, 1)
	if unit.get("formRules", {}).get("ghWatch", false) and int(unit.get("ghWatchTurn", -1)) != gs.turn_counter:
		unit.ghWatchTurn = gs.turn_counter
		gs.player(owner).attackUsed = false
		gs._set_fire(owner, int(gs.player(owner).energy) + 1)

static func end_turn(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if unit.erase("ghZeroTurn"): gs._recalc(unit)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	if not card.get("guishiheiRules", false): return false
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"gh-revive":
			gs.VerifiedRules.Peach.revive(gs, owner, src, unit, false, false)
			var pool: Array = gs.VerifiedRules.RedPurple.faction_units(gs, owner, "苍叶", false, unit.uid)
			pool = pool.filter(func(u): return int(u.hp) <= 0 and gs.VerifiedRules.Rebirth.can_revive(u))
			if not pool.is_empty(): gs.VerifiedRules.Peach.revive(gs, owner, src, pool[int(gs.next_random() % pool.size())], false, false)
		"gh-parting":
			gs._deploy_realm(owner, card)
			mark_reserve(gs, owner)
		"gh-awake":
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			gs._deploy_realm(owner, card)
			attach(gs, owner, target)
		"gh-form":
			if card.id == "c62808" and not gs.VerifiedRules.RedPurple.faction_units(gs, 1-owner, "青岚", true).is_empty():
				card = card.duplicate(true)
				card.formRules.combatKeywords.append("veil")
			gs._apply_form(owner, src, card)
			if card.id in ["c62802", "c62804"]: attach(gs, owner, target)
			if card.id == "c62808": unit.swift = true
		"gh-bind":
			if card.get("ghTrick", false): attach(gs, owner, target)
			else:
				for enemy in living(gs, 1-owner):
					attach(gs, owner, enemy)
					enemy.ghZeroTurn = gs.turn_counter
					gs._recalc(enemy)
		_: return false
	return true

static func marks(unit: Dictionary) -> Array:
	var out: Array = []
	if unit.has("ghSoulOwner"): out.append("索魂：鬼使黑可以攻击此式神")
	if unit.has("ghZeroTurn"): out.append("锁魂夺魄：本回合力量为0")
	return out

static func score_card(gs, owner: int, card: Dictionary, _target):
	if not card.get("guishiheiRules", false): return null
	if card.id == "c62801":
		var source_index: int = gs._source_index(owner, card)
		if source_index >= 0 and int(gs.player(owner).units[source_index].hp) <= 0: return 80
		return 60 if gs.VerifiedRules.RedPurple.faction_units(gs, owner, "苍叶").any(func(u): return int(u.hp) <= 0) else -100
	return 65
