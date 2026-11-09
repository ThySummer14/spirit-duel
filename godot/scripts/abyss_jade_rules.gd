extends RefCounted

const ID := "dayueling-yuxin"
const OATH := "abyss-jade-oath"

static func source(gs, owner: int) -> int:
	return gs.VerifiedRules.DragonAbyss.source(gs, owner, ID)

static func carrier(gs, owner: int) -> Dictionary:
	for side in 2:
		for u in gs.player(side).units:
			if owner in u.get("abyssJades", []): return {"side": side, "unit": u}
	return {}

static func has(u: Dictionary, owner: int) -> bool:
	return owner in u.get("abyssJades", [])

static func power(gs, u: Dictionary) -> int:
	var out := 0
	for owner in u.get("abyssJades", []):
		var stacks: int = gs.player(owner).get("abyssJadeAura", 0)
		out += stacks if gs._unit_index_by_uid(owner, u.uid) >= 0 else -stacks
	return out

static func remove(gs, owner: int, side: int, u: Dictionary) -> void:
	if not has(u, owner): return
	u.abyssJades.erase(owner)
	gs._recalc(u)
	gs.VerifiedRules.event(gs, "charm-removed", {"player": side, "uid": u.uid, "charm": "八尺琼勾玉"})
	if side == owner: return
	var src := source(gs, owner)
	if src < 0: return
	for r in gs.player(owner).realms:
		if r.get("nativeRealm") == "abyss-jade-sea" and int(r.hp) > 0:
			gs.resolution_stack.append({"kind": "abyss-jade-removed", "playerIndex": owner, "sourceIndex": src, "targetId": u.uid})

static func give(gs, owner: int, side: int, u: Dictionary) -> void:
	if u.is_empty() or int(u.hp) <= 0 or has(u, owner): return
	if gs.VerifiedRules.ZenMisfortune.protect(gs, side, u, owner): return
	var src := source(gs, owner)
	if src < 0: return
	var old := carrier(gs, owner)
	var host: Dictionary = gs.player(owner).units[src]
	var former_enemy := not old.is_empty() and int(old.side) != owner
	if not old.is_empty(): remove(gs, owner, int(old.side), old.unit)
	if not u.has("abyssJades"): u.abyssJades = []
	u.abyssJades.append(owner)
	gs._recalc(u)
	gs.VerifiedRules.event(gs, "charm-attached", {"player": side, "uid": u.uid, "charm": "八尺琼勾玉", "sourcePlayer": owner})
	if gs.VerifiedRules.OwlInsect.active(host) and host.awakened:
		gs.resolution_stack.append({"kind": "abyss-jade-random", "playerIndex": owner, "sourceIndex": src, "side": side, "targetId": u.uid, "result": int(gs.next_random() % 4)})
	if u == host and former_enemy and host.get("formRules", {}).get("abyssJadePrince", false):
		gs._grant_unit_armor(u, 3)
		gs.resolution_stack.append({"kind": "abyss-jade-follow", "playerIndex": owner, "sourceIndex": src, "targetId": old.unit.uid, "immune": false})
	if side == 1-owner and host.get("formRules", {}).get("abyssJadeKing", false) and int(host.get("abyssJadeKingTurn", -1)) != gs.turn_counter:
		host.abyssJadeKingTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "abyss-jade-king", "playerIndex": owner, "sourceIndex": src, "targetId": u.uid})

static func attack_started(gs, owner: int, src: int) -> void:
	var idx := source(gs, owner)
	if idx < 0: return
	var p: Dictionary = gs.player(owner)
	var host: Dictionary = p.units[idx]
	if not gs.VerifiedRules.OwlInsect.active(host): return
	if host.awakened and int(host.get("abyssJadeStartTurn", -1)) != gs.turn_counter:
		host.abyssJadeStartTurn = gs.turn_counter
		give(gs, owner, owner, p.units[src])
	elif src == idx and carrier(gs, owner).is_empty(): give(gs, owner, owner, host)

static func clash(gs, owner: int, src: int, enemy: int, idx: int) -> void:
	if enemy == owner: return
	var attacker: Dictionary = gs.player(owner).units[src]
	var target: Dictionary = gs.player(enemy).units[idx]
	for side in [owner, enemy]:
		var host := source(gs, side)
		if host < 0 or not gs.VerifiedRules.OwlInsect.active(gs.player(side).units[host]): continue
		if not has(attacker, side) and not has(target, side): continue
		var from_attacker := has(attacker, side)
		var receiver: Dictionary = target if from_attacker else attacker
		var receiver_side := enemy if from_attacker else owner
		gs.resolution_stack.append({"kind": "abyss-jade-clash-transfer", "playerIndex": side, "targetSide": receiver_side, "targetId": receiver.uid})
		gs.resolution_stack.append({"kind": "abyss-jade-shot", "playerIndex": side, "sourceIndex": host})

static func knocked(gs, side: int, u: Dictionary) -> void:
	if side < 0: return
	for owner in u.get("abyssJades", []).duplicate(): remove(gs, owner, side, u)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("id") != "c64602": return card
	var view := card.duplicate(true)
	var origin := ContentLoader.card_def("c19002").duplicate(true)
	origin.unitId = ID
	view.originCard = origin
	return view

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "abyss-jade-sea": return false
	if not gs.player(owner).hand.any(func(inst): return inst.definitionId == OATH): gs.VerifiedRules.DragonAbyss.put(gs, owner, OATH)
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var side := owner
	if target_id != null and gs._unit_index_by_uid(owner, target_id) < 0: side = 1-owner
	match str(e.action):
		"abyss-jade-mark", "abyss-jade-oath": give(gs, owner, side, target)
		"abyss-jade-aura":
			p.abyssJadeAura = int(p.get("abyssJadeAura", 0)) + 1
			give(gs, owner, side, target)
			if not target.is_empty(): gs._recalc(target)
		"abyss-jade-move":
			var old := carrier(gs, owner)
			give(gs, owner, side, target)
			if not target.is_empty():
				var idx: int = gs._unit_index_by_uid(side, target.uid)
				gs.VerifiedRules.HairPower.give(gs, side, idx, 1)
				target.abyssPierceTurn = gs.turn_counter
			if not old.is_empty() and int(old.side) == 1-owner and int(old.unit.hp) > 0:
				gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, old.unit.uid), 3, owner, src)
		"abyss-jade-form":
			gs._apply_form(owner, src, card, e.value)
			give(gs, owner, side, target)
		"abyss-jade-sea":
			gs._deploy_realm(owner, card)
			trigger_realm(gs, owner, p.realms.back())
		"abyss-jade-awake": gs._awaken(owner, src, card, e.value)
		"abyss-jade-combat":
			var cfg: Dictionary = card.get("combatOption", {}).duplicate()
			if card.id == "c64603":
				cfg.pursuit = true
				cfg.lethal = true
				cfg.immuneCombat = has(u, owner)
			else:
				var mark := carrier(gs, owner)
				if not mark.is_empty():
					if int(mark.side) == owner:
						cfg.abyssJadeFollow = mark.unit.uid
					else:
						gs.resolution_stack.append({"kind": "abyss-jade-base", "playerIndex": owner, "sourceIndex": src, "card": card})
						gs.VerifiedRules.DragonAbyss.attack(gs, owner, src, mark.unit.uid, {"pursuit": true, "immuneCombat": true})
						return true
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, target_id, cfg)
		_: return false
	return true

static func finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if not options.has("abyssJadeFollow"): return
	var idx: int = gs._unit_index_by_uid(owner, options.abyssJadeFollow)
	if idx >= 0: gs.resolution_stack.append({"kind": "abyss-jade-follow", "playerIndex": owner, "sourceIndex": idx, "targetId": null, "immune": true})

static func resolve_frame(gs, f: Dictionary) -> bool:
	var owner := int(f.get("playerIndex", -1))
	var src := int(f.get("sourceIndex", -1))
	match f.get("kind"):
		"abyss-jade-shot": gs.VerifiedRules.base_damage_projectile(gs, owner, src, 1, "八尺琼勾玉")
		"abyss-jade-clash-transfer":
			if gs.winner < 0: give(gs, owner, int(f.targetSide), gs._unit_by_uid(gs.player(int(f.targetSide)).units, f.targetId))
		"abyss-jade-base": gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, f.card, null)
		"abyss-jade-follow": gs.VerifiedRules.DragonAbyss.attack(gs, owner, src, f.targetId, {"pursuit": f.targetId != null, "immuneCombat": f.immune})
		"abyss-jade-king", "abyss-jade-removed":
			var idx: int = gs._unit_index_by_uid(1-owner, f.targetId)
			if idx < 0: return true
			if f.kind == "abyss-jade-removed": gs._damage_unit(1-owner, idx, 3, owner, src)
			else:
				gs.VerifiedRules.Stun.apply(gs, 1-owner, idx, 1, owner)
				for u in gs.VerifiedRules.DragonAbyss.living(gs, 1-owner):
					if u.uid != f.targetId: gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, u.uid), 2, owner, src)
		"abyss-jade-random":
			var side := int(f.side)
			var idx: int = gs._unit_index_by_uid(side, f.targetId)
			if idx < 0: return true
			var u: Dictionary = gs.player(side).units[idx]
			if side == owner:
				match int(f.result):
					0: gs._grow_unit(u, 1, 0)
					1: gs._grant_unit_armor(u, 2)
					2: gs.VerifiedRules.HairPower.give(gs, side, idx, 2)
					3: u.swift = true
			else:
				match int(f.result):
					0:
						u.abyssJadeDebuff = 2
						gs._recalc(u)
					1: u.enraged = true
					2: gs._damage_unit(side, idx, 2, owner, src)
					3:
						var realms: Array = gs.player(side).realms
						if not realms.is_empty():
							var r: Dictionary = realms[int(gs.next_random() % realms.size())]
							r.hp = maxi(0, int(r.hp)-4)
							gs.VerifiedRules.event(gs, "realm-durability", {"player": side, "realm": r.uid, "amount": 4, "remaining": r.hp})
							if int(r.hp) == 0: gs.VerifiedRules.Huang.destroy(gs, side, r, "三明六通")
		_: return false
	return true
