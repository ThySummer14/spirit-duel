extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const ID := "yimulian-linglai"
const GUARD := "fengfushou"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	match str(card.get("id", "")):
		"c61304":
			var copy := card.duplicate(true)
			var origin := Content.card_def("c11803").duplicate(true)
			origin.unitId = ID
			copy.originCard = origin
			return copy
		"c61306":
			var src := source(gs, owner)
			if src < 0 or gs.player(owner).units[src].get("form", {}).is_empty(): return card
			var copy := card.duplicate(true)
			copy.value = 2
			copy.effects[0].value = 2
			return copy
	return card

static func guard(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.OwlInsect.active(u): return
	var form := Content.card_def(GUARD).duplicate(true)
	if gs.player(owner).get("windGuardBlessed", false):
		form.formRules.substitute = true
		form.formRules.windGuardCrit = true
		form.formAbility += "\n攻击时暴击，替身。"
	gs._push_card_frames(owner, GUARD, null, form, src, 0, true)

static func on_stun(gs, owner: int, victim: int, source_idx: int) -> void:
	if owner < 0 or owner == victim: return
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.OwlInsect.active(u) or int(u.get("windStunTurn", -1)) == gs.turn_counter: return
	if u.awakened:
		if gs.current_player != owner: return
	elif src != source_idx: return
	u.windStunTurn = gs.turn_counter
	guard(gs, owner, src)

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, hit: Dictionary, options: Dictionary, was_stunned: bool) -> void:
	if idx < 0 or owner == victim or int(hit.get("dealt", 0)) <= 0: return
	var target: Dictionary = gs.player(victim).units[idx]
	if int(target.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(target): return
	if was_stunned and gs.player(owner).realms.any(func(r): return r.get("nativeRealm") == "wind-forest" and int(r.hp) > 0):
		if gs.VerifiedRules.Panguan.destroy(gs, owner, src, victim, idx, options.get("combatCard", {})): hit.knocked = true
	if int(target.hp) > 0 and options.get("windCombatStun", false):
		gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner, src)

static func guard_entered(gs, owner: int, src: int) -> void:
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm") != "wind-valley" or int(realm.hp) <= 0 or int(realm.get("windGuardTurn", -1)) == gs.turn_counter: continue
		realm.windGuardTurn = gs.turn_counter
		gs.resolution_stack.append({"kind": "wind-guard-bolt", "playerIndex": owner, "sourceIndex": src})

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	if not card.get("linglaiRules", false): return false
	var enemy := 1-owner
	var idx: int = gs._unit_index_by_uid(enemy, target_id)
	match str(effect.action):
		"ling-guard":
			if not gs.player(owner).units[src].get("form", {}).is_empty():
				gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1, 1)
			gs._apply_form(owner, src, card, effect.value)
			guard_entered(gs, owner, src)
		"ling-rest":
			gs.VerifiedRules.Peach.revive(gs, owner, src, gs.player(owner).units[src], false, false)
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, enemy, idx, 1, owner, src)
		"ling-forest":
			gs._deploy_realm(owner, card)
			var front: int = gs.front_index(enemy)
			if front >= 0 and gs.VerifiedRules.OwlInsect.shikigami(gs.player(enemy).units[front]):
				gs.VerifiedRules.Stun.apply(gs, enemy, front, 1, owner, src)
		"ling-gale":
			if idx >= 0:
				gs.VerifiedRules.Stun.apply(gs, enemy, idx, 1, owner, src)
				gs._damage_unit(enemy, idx, int(effect.value), owner, src)
		"ling-awake":
			gs._awaken(owner, src, card, effect.value)
			guard(gs, owner, src)
		"ling-bless":
			gs.player(owner).windGuardBlessed = true
			gs.resolution_stack.append({"kind": "wind-bless-attack", "playerIndex": owner, "sourceIndex": src, "card": card, "targetId": target_id})
			guard(gs, owner, src)
		"ling-valley":
			gs._deploy_realm(owner, card)
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, enemy, idx, 1, owner, src)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	match frame.get("kind"):
		"wind-guard-bolt":
			var enemy := 1-owner
			var pool := Choice.live_units(gs, enemy).filter(func(u): return int(u.frozen) == 0)
			if pool.is_empty(): gs._damage_avatar(enemy, 5, owner, int(frame.sourceIndex))
			else: gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, pool[int(gs.next_random() % pool.size())].uid), 5, owner, int(frame.sourceIndex))
		"wind-bless-attack":
			gs._resolve_action(owner, int(frame.sourceIndex), frame.card, {"action": "assault", "value": 0}, frame.targetId, {})
		_: return false
	return true
