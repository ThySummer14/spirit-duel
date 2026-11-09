extends RefCounted

const BROTHER := "tiaotiaogege"
const FAMILY := [BROTHER, "tiaotiaodidi", "tiaotiaomeimei"]
const Choice := preload("res://scripts/restored_card_choices.gd")

static func active(u: Dictionary) -> bool:
	return u.id == BROTHER and not u.get("baseRulesSuppressed", false) and int(u.hp) > 0 and int(u.level) > 0

static func timer(u: Dictionary) -> Dictionary:
	return u.get("jumpCoffin", u.get("jumpSlow", {}))

static func stunned(u: Dictionary) -> bool:
	return u.has("jumpSlow") and not u.get("baseRulesSuppressed", false)

static func queue(gs, kind: String, owner: int, idx: int, data: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": kind, "playerIndex": owner, "sourceIndex": idx, "coffinData": data})

static func defer_combat(gs, owner: int, idx: int, bonus: int, pierce: bool, remote: bool, combo: bool, first: bool, target, crit: bool, options: Dictionary) -> bool:
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u) or options.has("jumpEncourage"): return false
	if not options.get("basicAttack", false) and not options.has("combatCard"): return false
	if stunned(u): return true
	var attack := options.duplicate(true)
	attack.jumpEncourage = gs.VerifiedRules.TomatoFire.attack_encourage(gs, owner, attack)
	u.jumpSlow = {"jumpKind": "jump-release", "remaining": 2, "reset": 2, "order": gs.next_card_id,
		"options": attack, "bonus": bonus, "pierce": pierce, "remote": remote, "combo": combo, "first": first,
		"target": target, "crit": crit, "coffinStrike": attack.get("combatCard", {}).get("id") == "c18301"}
	gs.next_card_id += 1
	gs.VerifiedRules.event(gs, "jump-slow-attached", {"player": owner, "uid": u.uid, "remaining": 2})
	gs._log("%s 结附迟钝，倒计时2后发起攻击。" % u.name, gs.TONE_CARD)
	return true

static func can_transform(u: Dictionary) -> bool:
	return not u.get("removed", false) and not u.get("summoned", false) and not u.has("jumpCoffin")

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id") != "c18303": return null
	var valid: Array = []
	for side in [owner, 1-owner]:
		for u in Choice.live_units(gs, side):
			if can_transform(u) and (side == owner or not gs.VerifiedRules.Combat.has(u, "veil")):
				valid.append(u.uid)
	return valid

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id") == "c18304":
		return gs.player(owner).units.any(func(u): return int(u.hp) <= 0 and int(u.knockout) > 0 and can_transform(u))
	return true

static func make_coffin(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.hp) > 0 or int(u.knockout) <= 0 or not can_transform(u): return
	var original := u.duplicate(true)
	u.clear()
	u.merge(gs._make_unit(str(gs.player(owner).id), str(original.id)))
	u.merge({"uid": original.uid, "name": "棺材", "level": original.level, "baseAttack": 0, "attack": 0,
		"baseMaxHp": 3, "maxHp": 3, "hp": 3, "baseRulesSuppressed": true, "cannotAttack": true,
		"factionOverride": "", "passive_hooks": [], "art": "assets/official/cards/jump-coffin.png",
		"jumpCoffin": {"jumpKind": "jump-open", "remaining": 1, "reset": 1, "order": gs.next_card_id, "original": original}}, true)
	gs.next_card_id += 1
	gs.VerifiedRules.event(gs, "jump-coffin-created", {"player": owner, "uid": u.uid})

static func open_coffin(gs, owner: int, idx: int, broken: bool) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if not u.has("jumpCoffin"): return
	var original: Dictionary = u.jumpCoffin.original
	u.clear()
	u.merge(original, true)
	if broken:
		u.knockout = 3
		gs.VerifiedRules.event(gs, "jump-coffin-broken", {"player": owner, "uid": u.uid})
		return
	if not gs.VerifiedRules.Peach.revive(gs, owner, -1, u, false, false): return
	gs.VerifiedRules.event(gs, "jump-coffin-opened", {"player": owner, "uid": u.uid})
	if u.id in FAMILY:
		Choice.attack(gs, owner, idx, null, {"unyielding": true})

static func reached_zero(gs, owner: int, idx: int, clock: Dictionary) -> bool:
	var kind := str(clock.get("jumpKind", ""))
	if kind.is_empty(): return false
	if clock.get("queued", false): return true
	clock.queued = true
	if kind == "jump-release": gs.player(owner).units[idx].erase("jumpSlow")
	queue(gs, kind, owner, idx, clock)
	return true

static func sort_timers(gs, owner: int, indices: Array) -> void:
	indices.sort_custom(func(a, b):
		var first := int(timer(gs.player(owner).units[a]).get("order", -1))
		var second := int(timer(gs.player(owner).units[b]).get("order", -1))
		return int(a) < int(b) if first == second else first < second)

static func knockout_snapshot(gs, victim: int, u: Dictionary) -> Dictionary:
	if victim < 0: return {}
	var kind := ""
	if u.has("jumpCoffin"): kind = "jump-break"
	elif can_transform(u) and (u.get("formRules", {}).get("jumpSelfCoffin", false) or int(u.get("jumpCoffinTurn", -1)) == gs.turn_counter):
		kind = "jump-make"
	u.erase("jumpSlow")
	u.erase("jumpCoffinTurn")
	if kind.is_empty(): return {}
	return {"kind": kind, "playerIndex": victim, "sourceIndex": gs._unit_index_by_uid(victim, u.uid)}

static func knocked_out(gs, victim: int, u: Dictionary, source_owner: int, source_index: int, saved: Dictionary) -> void:
	if victim < 0: return
	if not saved.is_empty(): gs.resolution_stack.append(saved)
	for owner in 2:
		for idx in gs.player(owner).units.size():
			var brother: Dictionary = gs.player(owner).units[idx]
			if brother == u or not active(brother): continue
			if brother.get("jumpSlow", {}).get("coffinStrike", false): gs._grow_unit(brother, 1, 1)
			var rules: Dictionary = brother.get("formRules", {})
			if rules.get("jumpDeathCountdown", false) or (rules.get("jumpReleaseAura", false) and owner == source_owner and idx == source_index):
				gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1)

static func turn_start(gs, turn_owner: int) -> void:
	for owner in [1-turn_owner, turn_owner]:
		for idx in gs.player(owner).units.size():
			var u: Dictionary = gs.player(owner).units[idx]
			if active(u) and u.get("formRules", {}).get("jumpReleaseAura", false): queue(gs, "jump-aura", owner, idx)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	match action:
		"jump-strike": gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"combatCard": card})
		"jump-form": gs._apply_form(owner, src, card, effect.value)
		"jump-mark":
			if not target.is_empty() and can_transform(target): target.jumpCoffinTurn = gs.turn_counter
		"jump-team":
			for idx in gs.player(owner).units.size(): make_coffin(gs, owner, idx)
		"jump-bury":
			if target.is_empty(): return true
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx < 0: continue
				if gs.VerifiedRules.Panguan.destroy(gs, owner, src, side, idx, card) and can_transform(target):
					queue(gs, "jump-make", side, idx)
				break
		"jump-awaken": gs._awaken(owner, src, card, effect.value)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("jump-"): return false
	var owner := int(frame.playerIndex)
	var idx := int(frame.sourceIndex)
	match kind:
		"jump-make": make_coffin(gs, owner, idx)
		"jump-break": open_coffin(gs, owner, idx, true)
		"jump-open": open_coffin(gs, owner, idx, false)
		"jump-release":
			var data: Dictionary = frame.coffinData
			var u: Dictionary = gs.player(owner).units[idx]
			if active(u) and not gs.VerifiedRules.Stun.blocks(gs, owner, u):
				gs._resolve_combat(owner, idx, int(data.bonus), bool(data.pierce), bool(data.remote), bool(data.combo), bool(data.first), data.target, bool(data.crit), data.options)
		"jump-aura":
			var u: Dictionary = gs.player(owner).units[idx]
			if not active(u) or not u.get("formRules", {}).get("jumpReleaseAura", false): return true
			for target in Choice.live_units(gs, 1-owner):
				gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, target.uid), 1, owner, idx)
			gs._damage_avatar(1-owner, 1, owner, idx)
	return true

static func marks(u: Dictionary) -> Array:
	if u.has("jumpCoffin"): return ["棺材 · 倒计时%d，结束时复活原式神" % int(u.jumpCoffin.remaining)]
	if stunned(u): return ["迟钝 · 眩晕，倒计时%d后发起攻击" % int(u.jumpSlow.remaining)]
	return []
