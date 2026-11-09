extends RefCounted

const Content := preload("res://scripts/content_loader.gd")

static func offer(gs, owner: int, kind: String, ids: Array, heading: String, context: Dictionary = {}) -> bool:
	if ids.is_empty(): return false
	gs.pending_choice = {"type": kind, "playerIndex": owner, "instanceIds": ids, "heading": heading}
	gs.pending_choice.merge(context)
	gs.phase = "choice"
	return true

static func matches(gs, owner: int, iid: String, prefix: String) -> bool:
	var c: Dictionary = gs.pending_choice
	return str(c.get("type", "")).begins_with(prefix) and int(c.get("playerIndex", -1)) == owner and iid in c.get("instanceIds", [])

static func accept(gs, owner: int, iid: String) -> Dictionary:
	var choice: Dictionary = gs.pending_choice
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": choice.type}, owner)
	return choice

static func finish(gs) -> void:
	gs._resolve_resolution_stack()
	gs.state_changed.emit()

static func face(id: String, name: String, description: String, art: String = "") -> Dictionary:
	return {"id": id, "name": name, "type": "spell", "text": description, "art": art}

static func sample(gs, pool: Array, size: int) -> Array:
	var picked: Array = []
	var candidates := pool.duplicate()
	while picked.size() < size and not candidates.is_empty():
		picked.append(candidates.pop_at(int(gs.next_random() % candidates.size())))
	return picked

static func give(gs, owner: int, id: String, fields: Dictionary = {}) -> Dictionary:
	var inst: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, id)
	inst.merge(fields, true)
	gs.VerifiedRules.Baize.put_hand(gs, owner, inst)
	return inst

static func live_units(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func targetable_shikigami(gs, owner: int, side: int) -> Array:
	var units := live_units(gs, side)
	if side == owner: return units
	return units.filter(func(u): return not gs.VerifiedRules.Combat.has(u, "veil"))

static func attack(gs, owner: int, src: int, target = null, options: Dictionary = {}) -> void:
	if src < 0 or not gs.VerifiedRules.Samurai.available(gs.player(owner).units[src]): return
	gs._resolve_combat(owner, src, 0, false, false, false, false, target, false, options)
