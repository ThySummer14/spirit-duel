extends RefCounted

const Content := preload("res://scripts/content_loader.gd")

static func summon(gs, owner: int, src: int, id: String, name: String, attack: int, hp: int, fields: Dictionary = {}) -> Dictionary:
	var p: Dictionary = gs.player(owner)
	var source: Dictionary = p.units[src]
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var unit := {
		"uid": "%s:%s-%d" % [p.id, id, gs.next_card_id], "id": id, "name": name,
		"title": "%s召唤物" % source.name, "art": source.get("art", ""), "color": source.get("color", "#d0c0b0"),
		"baseAttack": attack, "baseMaxHp": hp, "attack": attack, "maxHp": hp, "hp": hp, "level": 1,
		"shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0,
		"unyielding": false, "front": 1, "attackBonus": 0, "maxHpBonus": 0, "awakened": false,
		"form": {}, "formRules": {}, "formAbility": "", "charge": 0, "passive_hooks": [],
		"summoned": true, "summon": true, "countsAsShikigami": true, "summonerUid": source.uid,
		"nativeFieldSummon": true,
	}
	unit.merge(fields, true)
	gs.next_card_id += 1
	p.units.append(unit)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": unit.uid, "sourceUid": source.uid, "summonKind": id})
	gs._fire_hooks(owner, p.units.size()-1, "unit-entered-front", {})
	gs.VerifiedRules.automatic_response(gs, 1-owner, "enemy-entered-front", unit.uid, {"kind": "response-complete"})
	return unit

static func remove(gs, owner: int, unit: Dictionary) -> void:
	if unit.get("removed", false): return
	unit.hp = 0
	unit.knockout = 0
	unit.front = 0
	unit.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": unit.uid, "summonKind": unit.id})

static func remove_departed(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if u.get("nativeFieldSummon", false) and int(u.front) == 0: remove(gs, owner, u)
