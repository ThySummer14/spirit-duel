class_name RainRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "yunv"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func heal_avatar(gs, owner: int, amount: int) -> void:
	var p: Dictionary = gs.player(owner)
	if p.get("avatarToxicPoisoned", false): return
	var excess := maxi(0, int(p.avatarHp) + amount - int(p.maxAvatarHp))
	gs._heal_avatar(owner, amount)
	gs._grant_avatar_armor(owner, excess)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("insightFromZone", false) or not dedicated(card): return card
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm") != "rain-home" or int(realm.hp) <= 0 or int(realm.get("rainKeepTurn", -1)) == gs.turn_counter: continue
		var view := card.duplicate(true)
		view.insightKeeps = true
		view.rainKeepRealm = realm.uid
		if "instant" not in view.get("keywords", []): view.keywords.append("instant")
		view.text += "\n雨居：瞬发，使用后保持启悟。"
		return view
	return card

static func dedicated(card: Dictionary) -> bool:
	return not card.get("neutral", false) and not str(card.get("unitId", "")).is_empty()

static func announced(gs, owner: int, card: Dictionary) -> void:
	if not card.get("insightFromZone", false): return
	for realm in gs.player(owner).realms:
		if str(realm.get("uid", "")) == card.get("rainKeepRealm", "") and card.has("rainKeepRealm"):
			realm.rainKeepTurn = gs.turn_counter
			break
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.Astral.active(u): return
	if u.awakened:
		for ally in gs.player(owner).units:
			if int(ally.hp) > 0: gs._heal_unit(ally, 1)
	heal_avatar(gs, owner, 1)
	if u.awakened and dedicated(card): heal_avatar(gs, owner, 2)

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") != "rain-lament": return null
	var ids: Array = ["avatar-%d" % owner]
	for u in gs.player(owner).units:
		if int(u.hp) > 0 and not u.get("removed", false): ids.append(u.uid)
	for u in gs.player(1-owner).units:
		if int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil"): ids.append(u.uid)
	return ids

static func entered(gs, owner: int) -> void:
	for realm in gs.player(owner).realms:
		if realm.get("nativeRealm") == "rain-bridge" and int(realm.hp) > 0 and int(realm.get("rainGuardTurn", -1)) != gs.turn_counter:
			realm.rainGuardTurn = gs.turn_counter
			gs.VerifiedRules.HairPower.grant_guard(gs, owner)
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.Astral.active(u) or not u.get("formRules", {}).get("rainTear", false) or int(u.get("rainTearTurn", -1)) == gs.turn_counter: return
	u.rainTearTurn = gs.turn_counter
	summon(gs, owner, src)

static func summon(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var tear := {"uid": "%s:rain-%d" % [p.id, gs.next_card_id], "id": "rain-tear", "name": "天之泪",
		"title": "雨女召唤物", "art": Content.unit_def(ID).art, "color": "#80b0d0",
		"baseAttack": 2, "baseMaxHp": 2, "attack": 2, "maxHp": 2, "hp": 2, "level": 1,
		"shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0,
		"unyielding": false, "front": 1, "attackBonus": 0, "maxHpBonus": 0, "awakened": false, "form": {},
		"formRules": {}, "formAbility": "", "charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "summonerUid": p.units[src].uid}
	gs.next_card_id += 1
	p.units.append(tear)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": tear.uid, "sourceUid": tear.summonerUid, "summonKind": "rain-tear"})
	gs.VerifiedRules.automatic_response(gs, 1-owner, "enemy-entered-front", tear.uid, {"kind": "response-complete"})

static func remove_departed(gs) -> void:
	for owner in gs.players.size():
		for u in gs.player(owner).units:
			if u.id == "rain-tear" and not u.get("removed", false) and (int(u.front) == 0 or int(u.hp) <= 0):
				u.hp = 0
				u.knockout = 0
				u.front = 0
				u.removed = true
				gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": u.uid, "summonKind": "rain-tear"})

static func enter_and_draw(gs, owner: int) -> void:
	var depth: int = gs.resolution_stack.size()
	gs.VerifiedRules.Insight.enter(gs, owner)
	if gs.winner >= 0: return
	if gs.resolution_stack.size() > depth:
		gs.resolution_stack.insert(depth, {"kind": "charm-extra-draw", "playerIndex": owner, "count": 1})
	else: gs._draw(owner, 1)

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var repeats := int(p.get("rainRepeats", 0))
	p.erase("rainRepeats")
	for i in repeats:
		if gs.winner >= 0: break
		enter_and_draw(gs, owner)

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "rain-home": return false
	enter_and_draw(gs, owner)
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not card.get("rainRules", false): return false
	var p: Dictionary = gs.player(owner)
	match str(effect.get("action", "")):
		"rain-draw": enter_and_draw(gs, owner)
		"rain-bridge":
			gs._deploy_realm(owner, card)
			gs.VerifiedRules.Insight.enter(gs, owner)
		"rain-tear":
			gs._apply_form(owner, src, card)
			gs.VerifiedRules.Insight.enter(gs, owner)
		"rain-repeat":
			p.rainRepeats = int(p.get("rainRepeats", 0)) + 1
			enter_and_draw(gs, owner)
		"rain-awaken":
			gs.VerifiedRules.Insight.enter(gs, owner)
			gs._awaken(owner, src, card, effect.value)
		"rain-lament":
			var amount: int = gs.VerifiedRules.Insight.zone(gs, owner).size()
			var enemy: int = gs._unit_index_by_uid(1-owner, target_id)
			var ally: int = gs._unit_index_by_uid(owner, target_id)
			if enemy >= 0: gs._damage_unit(1-owner, enemy, amount, owner, src)
			elif ally >= 0: gs._heal_unit(p.units[ally], amount)
			elif str(target_id) == "avatar-%d" % owner: gs._heal_avatar(owner, amount)
		"rain-revive":
			var owners: Array = gs.VerifiedRules.Insight.zone(gs, owner).map(func(i): return Content.card_def(i.definitionId).get("unitId", ""))
			for u in p.units:
				if gs.VerifiedRules.OwlInsect.shikigami(u) and u.id in owners and int(u.hp) <= 0:
					gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
			gs.VerifiedRules.Insight.enter(gs, owner)
		"rain-home":
			gs._deploy_realm(owner, card)
			enter_and_draw(gs, owner)
		_: return false
	return true
