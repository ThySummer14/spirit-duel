class_name BoneRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const BONE := "gunv"
const REMAINS := "gunv-remains"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": BONE})

static func realms(gs, owner: int, kind: String) -> Array:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm") == kind and int(r.hp) > 0)

static func countdown(gs, owner: int, unit: Dictionary, value: int) -> int:
	if owner < 0 or unit.get("summoned", false): return value
	var src := source(gs, owner)
	if src < 0: return value
	var bone: Dictionary = gs.player(owner).units[src]
	return 2 if bone.awakened and not bone.get("baseRulesSuppressed", false) else value

static func death_frames(gs, owner: int, unit: Dictionary, killer_owner: int, killer_idx: int) -> Array:
	if owner < 0 or unit.get("summoned", false): return []
	var src := source(gs, owner)
	if src < 0: return []
	var frames: Array = []
	if unit.id == BONE and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false):
		unit.boneDeaths = int(unit.get("boneDeaths", 0)) + 1
		frames.append({"kind": "bone-summon", "playerIndex": owner, "sourceIndex": src})
		if unit.get("formRules", {}).get("boneRevive", false):
			frames.append({"kind": "bone-revive", "playerIndex": owner, "sourceIndex": src})
	if int(unit.front) == 1:
		for realm in realms(gs, owner, "bone-bird"):
			frames.append({"kind": "bone-summon", "playerIndex": owner, "sourceIndex": src, "realmUid": realm.uid})
	if killer_owner == 1-owner and killer_idx >= 0:
		var killer: Dictionary = gs.player(killer_owner).units[killer_idx]
		if gs.VerifiedRules.OwlInsect.shikigami(killer) and not killer.get("summoned", false):
			for realm in realms(gs, owner, "bone-dream"):
				frames.append({"kind": "bone-retaliate", "playerIndex": owner, "targetId": killer.uid, "realmUid": realm.uid})
	frames.reverse()
	return frames

static func summon(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	var current: Dictionary = gs.front_unit(owner)
	if current.get("id", "") == REMAINS:
		gs._grow_unit(current, 1, 2)
		gs.VerifiedRules.event(gs, "summon-fused", {"player": owner, "uid": current.uid, "summonKind": REMAINS, "attack": current.attack, "hp": current.hp})
		return
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var remains := {
		"uid": "%s:bone-%d" % [p.id, gs.next_card_id], "id": REMAINS, "name": "骸",
		"title": "骨女召唤物", "art": Content.unit_def(BONE).art, "color": "#d0c0b0",
		"baseAttack": 1, "baseMaxHp": 2, "attack": 1, "maxHp": 2, "hp": 2, "level": 1,
		"shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0,
		"unyielding": false, "front": 1, "attackBonus": 0, "maxHpBonus": 0, "awakened": false,
		"form": {}, "formRules": {}, "formAbility": "融合。", "charge": 0, "passive_hooks": [],
		"summoned": true, "summon": true, "countsAsShikigami": true, "summonerUid": p.units[src].uid,
		"swift": not realms(gs, owner, "bone-dream").is_empty(),
	}
	gs.next_card_id += 1
	p.units.append(remains)
	var idx: int = p.units.size()-1
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": remains.uid, "sourceUid": remains.summonerUid, "summonKind": REMAINS})
	gs._fire_hooks(owner, idx, "unit-entered-front", {})
	gs.VerifiedRules.automatic_response(gs, 1-owner, "enemy-entered-front", remains.uid, {"kind": "response-complete"})

static func remove(gs, owner: int, unit: Dictionary) -> void:
	if unit.get("removed", false): return
	unit.hp = 0
	unit.knockout = 0
	unit.front = 0
	unit.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": unit.uid, "summonKind": REMAINS})

static func remove_departed(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if u.id == REMAINS and int(u.front) == 0: remove(gs, owner, u)

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") not in ["bone-blade", "bone-skin"]: return null
	var src := source(gs, owner)
	if src < 0: return []
	var level: int = gs.player(owner).units[src].level if card.effect == "bone-blade" else 99
	return gs.player(1-owner).units.filter(func(u):
		return int(u.hp) > 0 and int(u.level) <= level and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil")
	).map(func(u): return str(u.uid))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not card.get("boneRules", false): return false
	var u: Dictionary = gs.player(owner).units[src]
	var enemy := 1-owner
	match str(effect.action):
		"bone-bird":
			gs._deploy_realm(owner, card)
			gs.VerifiedRules.HairPower.grant_guard(gs, owner)
		"bone-skin":
			var idx: int = gs._unit_index_by_uid(enemy, target_id)
			if idx >= 0 and int(gs.player(enemy).units[idx].hp) > 0: gs.VerifiedRules.Stun.apply(gs, enemy, idx, 1, owner)
			summon(gs, owner, src)
		"bone-blade":
			var idx: int = gs._unit_index_by_uid(enemy, target_id)
			var legal := idx >= 0 and int(gs.player(enemy).units[idx].level) <= int(u.level)
			gs.VerifiedRules.Panguan.destroy(gs, owner, src, owner, src, card)
			if legal: gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, idx, card)
		"bone-awaken":
			var depth: int = gs.resolution_stack.size()
			summon(gs, owner, src)
			gs.resolution_stack.insert(depth, {"kind": "bone-awaken", "playerIndex": owner, "sourceIndex": src, "card": card, "value": effect.value})
		"bone-form":
			gs._apply_form(owner, src, card)
			gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
		"bone-dream":
			gs._deploy_realm(owner, card)
			summon(gs, owner, src)
		_: return false
	return true

static func combat_finished(gs, owner: int, src: int, defender: Dictionary, options: Dictionary) -> void:
	var mode := str(options.get("boneCombat", ""))
	if mode.is_empty() or defender.is_empty(): return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.get("boneDeaths", 0)) == int(options.get("boneDeaths", 0)): return
	var victim := int(options.get("combatVictim", 1-owner))
	var idx: int = gs._unit_index_by_uid(victim, defender.uid)
	var shikigami: bool = idx >= 0 and gs.VerifiedRules.OwlInsect.shikigami(defender)
	if mode == "destroy":
		if shikigami: gs.VerifiedRules.Panguan.destroy(gs, owner, src, victim, idx, options.get("combatCard", {}))
	else:
		if shikigami and int(defender.hp) > 0: gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
		gs.VerifiedRules.Stun.apply(gs, victim, -1, 1, owner)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("bone-"): return false
	var owner := int(frame.playerIndex)
	if frame.has("realmUid") and not gs.player(owner).realms.any(func(r): return r.uid == frame.realmUid and int(r.hp) > 0): return true
	match kind:
		"bone-summon": summon(gs, owner, int(frame.sourceIndex))
		"bone-revive":
			var src := int(frame.sourceIndex)
			gs.VerifiedRules.Peach.revive(gs, owner, src, gs.player(owner).units[src], false, false)
		"bone-retaliate":
			var src := source(gs, owner)
			var idx: int = gs._unit_index_by_uid(1-owner, frame.targetId)
			if src >= 0 and idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1-owner, idx)
		"bone-awaken": gs._awaken(owner, int(frame.sourceIndex), frame.card, frame.value)
		_: return false
	return true

static func score(gs, owner: int, card: Dictionary, target_id):
	if not card.get("boneRules", false): return null
	var idx: int = gs._unit_index_by_uid(1-owner, target_id)
	if idx < 0: return 63
	var target: Dictionary = gs.player(1-owner).units[idx]
	return 54 + int(target.attack) + int(target.hp)
