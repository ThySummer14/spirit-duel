extends RefCounted

const ID := "yixienamei"
const SNAKE := "izanami-snakes"
const Factions := preload("res://scripts/faction_rules.gd")

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func form(gs, owner: int, key: String) -> bool:
	var src := source(gs, owner)
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	return int(u.hp) > 0 and u.get("formRules", {}).get(key, false)

static func protected(gs, owner: int, u: Dictionary) -> bool:
	return int(u.hp) == 1 and gs.VerifiedRules.OwlInsect.shikigami(u) and form(gs, owner, "izanamiKiss")

static func living(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("id") != "c62503": return card
	if not living(gs, owner).any(func(u): return Factions.get_faction(u) == "苍叶"): return card
	var out := card.duplicate(true)
	out.keywords.append("instant")
	return out

static func summon(gs, owner: int, src: int, power: int = 0) -> Dictionary:
	var enemy: Dictionary = gs.front_unit(1-owner)
	var fast: bool = not enemy.is_empty() and gs.VerifiedRules.OwlInsect.shikigami(enemy)
	var fields := {"swift": fast, "inspired": fast, "izanamiFastTurn": gs.turn_counter if fast else -1}
	var unit: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, owner, src, SNAKE, "蛇群", 2, 1, fields)
	if power > 0: gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, unit.uid), power)
	return unit

static func changed(gs, owner: int, u: Dictionary, prior_hp: int) -> void:
	if prior_hp == 1 or int(u.hp) != 1 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	one_hp(gs, owner, u)
	gs.VerifiedRules.Wave7Reworks.spirit_health(gs, owner, u, prior_hp)

static func summon_entered(gs, details: Dictionary) -> void:
	var owner := int(details.get("player", -1))
	if owner < 0 or owner >= gs.players.size(): return
	var u: Dictionary = gs._unit_by_uid(gs.player(owner).units, details.get("uid"))
	if u.is_empty() or not u.get("summoned", false) or int(u.hp) != 1: return
	one_hp(gs, owner, u)

static func one_hp(gs, side: int, u: Dictionary) -> void:
	for owner in 2:
		var src := source(gs, owner)
		if src < 0: continue
		var izanami: Dictionary = gs.player(owner).units[src]
		var frames: Array = []
		if gs.VerifiedRules.OwlInsect.active(izanami) and (side == owner or izanami.awakened):
			frames.append({"kind": "izanami-trigger", "playerIndex": owner, "sourceIndex": src, "awakened": izanami.awakened, "targetId": u.uid})
		if side == owner and owner == gs.current_player:
			for realm in gs.player(owner).realms:
				if realm.get("nativeRealm") != "izanami-sea" or int(realm.hp) <= 0 or int(realm.get("izanamiTurn", -1)) == gs.turn_counter: continue
				realm.izanamiTurn = gs.turn_counter
				frames.append({"kind": "izanami-sea-draw", "playerIndex": owner, "realmUid": realm.uid})
		frames.reverse()
		gs.resolution_stack.append_array(frames)

static func set_one(gs, owner: int, u: Dictionary) -> void:
	var before := int(u.hp)
	if before <= 1: return
	u.hp = 1
	gs.VerifiedRules.Hanafuda.reduce_shared(gs, owner, u, before - 1)
	gs.VerifiedRules.TreeSakura.sync_power(u)
	gs.VerifiedRules.event(gs, "izanami-life-set", {"player": owner, "uid": u.uid, "priorHp": before})
	changed(gs, owner, u, before)

static func strongest(gs, owner: int) -> void:
	for side in [owner, 1-owner]:
		var pool := living(gs, side)
		if pool.is_empty(): continue
		var best := -10000
		for u in pool: best = maxi(best, int(u.attack))
		var ties := pool.filter(func(u): return int(u.attack) == best)
		set_one(gs, side, ties[int(gs.next_random() % ties.size())])

static func combat_dealt(gs, owner: int, victim: int, idx: int, hit: Dictionary, options: Dictionary) -> void:
	if owner == victim or idx < 0 or options.get("izanamiCounterstrike", false) or int(hit.get("dealt", 0)) <= 0 or not form(gs, owner, "izanamiDance"): return
	var u: Dictionary = gs.player(victim).units[idx]
	if gs.VerifiedRules.OwlInsect.shikigami(u): set_one(gs, victim, u)

static func expire(gs) -> void:
	for side in 2:
		for u in gs.player(side).units:
			if u.id == SNAKE and int(u.get("izanamiFastTurn", -1)) == gs.turn_counter:
				u.swift = false
				u.erase("inspired")
				u.erase("izanamiFastTurn")

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.action):
		"izanami-dance", "izanami-kiss":
			gs._apply_form(owner, src, card, effect.value)
			summon(gs, owner, src, 4 if effect.action == "izanami-kiss" else 0)
		"izanami-sea":
			gs._deploy_realm(owner, card)
			var target: Dictionary = gs._unit_by_uid(gs._all_units(), target_id)
			if not target.is_empty() and int(target.hp) > 0: target.unyielding = true
		"izanami-create": summon(gs, owner, src)
		"izanami-awake":
			gs._awaken(owner, src, card, effect.value)
			summon(gs, owner, src)
		"izanami-goddess":
			gs._apply_form(owner, src, card, effect.value)
			strongest(gs, owner)
		"izanami-break":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx < 0: continue
				if Factions.get_faction(gs.player(side).units[idx]) == "青岚":
					gs.resolution_stack.append({"kind": "izanami-break-summon", "playerIndex": owner, "sourceIndex": src})
				gs._damage_unit(side, idx, int(effect.value), owner, src)
				break
		"izanami-pick":
			var pool := living(gs, 1-owner)
			pool.reverse()
			for target in pool:
				gs.resolution_stack.append({"kind": "izanami-pick-summon", "playerIndex": owner, "sourceIndex": src, "targetId": target.uid})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	match frame.get("kind"):
		"izanami-trigger":
			var enemies := living(gs, 1-owner)
			if not enemies.is_empty():
				var target: Dictionary = enemies[int(gs.next_random() % enemies.size())]
				gs.VerifiedRules.base_damage_unit(gs, owner, int(frame.sourceIndex), 1-owner, gs._unit_index_by_uid(1-owner, target.uid), 1)
			if frame.awakened and gs.winner < 0: gs.VerifiedRules.base_damage_avatar(gs, owner, int(frame.sourceIndex), 1-owner, 1)
		"izanami-sea-draw":
			if gs.player(owner).realms.any(func(r): return r.uid == frame.realmUid):
				gs.resolution_stack.append({"kind": "izanami-sea-drain", "playerIndex": owner, "realmUid": frame.realmUid})
				gs._draw(owner, 1)
		"izanami-sea-drain":
			for realm in gs.player(owner).realms.duplicate():
				if realm.uid != frame.realmUid: continue
				realm.hp = maxi(0, int(realm.hp)-2)
				gs.VerifiedRules.event(gs, "realm-durability", {"player": owner, "realm": realm.uid, "amount": 2, "remaining": realm.hp})
				if int(realm.hp) == 0: gs.VerifiedRules.Huang.destroy(gs, owner, realm, "虚无之海耗尽")
				break
		"izanami-pick-summon":
			var depth: int = gs.resolution_stack.size()
			var unit := summon(gs, owner, int(frame.sourceIndex))
			gs.resolution_stack.insert(depth, {"kind": "izanami-pick-attack", "playerIndex": owner, "uid": unit.uid, "targetId": frame.targetId})
		"izanami-break-summon":
			summon(gs, owner, int(frame.sourceIndex))
		"izanami-pick-attack":
			var src: int = gs._unit_index_by_uid(owner, frame.uid)
			var idx: int = gs._unit_index_by_uid(1-owner, frame.targetId)
			if src >= 0 and idx >= 0 and int(gs.player(owner).units[src].hp) > 0 and int(gs.player(1-owner).units[idx].hp) > 0:
				gs._resolve_combat(owner, src, 0, false, false, false, false, frame.targetId, false, {"pursuit": true})
		_: return false
	return true
