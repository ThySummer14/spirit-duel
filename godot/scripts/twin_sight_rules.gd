class_name TwinSightRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const CAT := "ertong-cat-spirit"
const UNIT := "ertong"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": UNIT})

static func realm_count(gs, owner: int) -> int:
	return gs.player(owner).realms.filter(func(realm): return int(realm.hp) > 0).size()

static func cat(gs, owner: int) -> Dictionary:
	var front: Dictionary = gs.front_unit(owner)
	return front if front.get("id", "") == CAT else {}

static func summon(gs, owner: int) -> Dictionary:
	var existing := cat(gs, owner)
	if not existing.is_empty(): return existing
	var p: Dictionary = gs.player(owner)
	var src := source(gs, owner)
	if src < 0: return {}
	gs.VerifiedRules.Weaver.leave_front(gs, owner)
	var size := 2 + floori(float(p.get("twinSightRealmUses", 0)) / 3.0)
	var spirit := {
		"uid": "%s:cat-spirit-%d" % [p.id, gs.next_card_id], "id": CAT, "name": "猫灵",
		"title": "二瞳召唤物", "art": "assets/official/tokens/twin-sight-cat.png", "color": "#8ca9a8",
		"baseAttack": size, "baseMaxHp": size, "attack": size, "maxHp": size, "hp": size, "level": 1,
		"shield": 0, "shieldExpires": 0, "knockout": 0, "frozen": 0, "brittle": 0, "armorBreak": 0,
		"unyielding": false, "front": 1, "attackBonus": 0, "maxHpBonus": 0, "awakened": false,
		"form": {}, "formRules": {}, "formAbility": "本局每使用三张幻境，召唤时的基础身材+1/+1。",
		"charge": 0, "passive_hooks": [], "summoned": true, "summon": true, "countsAsShikigami": true,
		"summonerUid": p.units[src].uid,
	}
	gs.next_card_id += 1
	p.units.append(spirit)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": spirit.uid, "sourceUid": spirit.summonerUid, "summonKind": CAT})
	gs._fire_hooks(owner, p.units.size()-1, "unit-entered-front", {})
	gs.VerifiedRules.automatic_response(gs, 1-owner, "enemy-entered-front", spirit.uid, {"kind": "response-complete"})
	return spirit

static func remove(gs, owner: int, unit: Dictionary) -> void:
	if unit.get("removed", false): return
	unit.hp = 0
	unit.knockout = 0
	unit.front = 0
	unit.removed = true
	gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": unit.uid, "summonKind": CAT})

static func remove_departed(gs, owner: int) -> void:
	for unit in gs.player(owner).units:
		if unit.id == CAT and int(unit.front) == 0: remove(gs, owner, unit)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	if source(gs, owner) < 0: return
	var p: Dictionary = gs.player(owner)
	if card.get("type", "") == "realm":
		p.twinSightRealmUses = int(p.get("twinSightRealmUses", 0)) + 1
		var used: Array = p.get("twinSightRealmHistory", [])
		if str(card.id) not in used: used.append(str(card.id))
		p.twinSightRealmHistory = used
	elif not Content.is_spell(card): return
	var target = frame.get("targetId")
	if target == null: return
	var idx: int = gs._unit_index_by_uid(1-owner, target)
	if idx < 0 or not gs.VerifiedRules.OwlInsect.shikigami(gs.player(1-owner).units[idx]): return
	var realms: Array = p.realms.filter(func(r): return r.get("nativeRealm") == "twin-cycle" and int(r.hp) > 0)
	if realms.is_empty(): return
	for pending in gs.resolution_stack:
		if pending.kind == "card-complete" and int(pending.resolutionId) == int(frame.resolutionId):
			pending.twinCycleRealms = realms.map(func(r): return str(r.uid))
			break

static func completed(gs, frame: Dictionary) -> void:
	var realms: Array = frame.get("twinCycleRealms", []).duplicate()
	realms.reverse()
	for uid in realms:
		gs.resolution_stack.append({"kind": "twin-cycle", "playerIndex": frame.playerIndex, "targetId": frame.targetId, "realmUid": uid})

static func realm_left(gs, owner: int, realm: Dictionary) -> void:
	if realm.get("nativeRealm") == "twin-welcome": gs.resolution_stack.append({"kind": "twin-welcome", "playerIndex": owner})

static func realm_entered(gs, owner: int, realm: Dictionary) -> void:
	var frames: Array = []
	if realm.get("nativeRealm") == "twin-welcome":
		frames.append({"kind": "twin-welcome", "playerIndex": owner})
	for installed in gs.player(owner).realms:
		if installed.get("nativeRealm") != "twin-patrol" or int(installed.hp) <= 0 or int(installed.get("usedTurn", -1)) == gs.turn_counter: continue
		installed.usedTurn = gs.turn_counter
		frames.append({"kind": "twin-patrol", "playerIndex": owner, "realmUid": installed.uid})
	frames.reverse()
	gs.resolution_stack.append_array(frames)

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.BondDream.active(unit): return
	if unit.get("formRules", {}).get("twinGod", false):
		gs.resolution_stack.append({"kind": "twin-god", "playerIndex": owner, "remaining": 2})
	var count := realm_count(gs, owner)
	if count <= 0: return
	if unit.awakened:
		gs.resolution_stack.append({"kind": "twin-awake-start", "playerIndex": owner, "count": count})
	gs.resolution_stack.append({"kind": "twin-divine", "playerIndex": owner})

static func divined(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	var deck: Array = gs.player(owner).deck
	if gs.VerifiedRules.BondDream.active(u) and u.get("formRules", {}).get("twinKeeper", false) and not deck.is_empty() and _is_realm(deck.back()):
		gs.resolution_stack.append({"kind": "twin-draw", "playerIndex": owner, "remaining": 1})

static func _is_realm(inst: Dictionary) -> bool:
	return Content.card_def(str(inst.definitionId)).get("type", "") == "realm"

static func _find_realm(gs, owner: int, uid: String) -> Dictionary:
	for realm in gs.player(owner).realms:
		if str(realm.uid) == uid and int(realm.hp) > 0: return realm
	return {}

static func _attack(gs, owner: int, uid: String, target, immune: bool) -> void:
	var idx: int = gs._unit_index_by_uid(owner, uid)
	if idx < 0 or int(gs.player(owner).units[idx].hp) <= 0: return
	gs._resolve_combat(owner, idx, 0, false, false, false, false, target, false, {"immuneCombat": immune, "pursuit": target != null})

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.kind)
	if not kind.begins_with("twin-"): return false
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	var enemy := 1-owner
	match kind:
		"twin-welcome":
			var spirit := cat(gs, owner)
			if spirit.is_empty(): summon(gs, owner)
			else: _attack(gs, owner, str(spirit.uid), null, false)
		"twin-patrol", "twin-cycle":
			if _find_realm(gs, owner, str(frame.realmUid)).is_empty(): return true
			if kind == "twin-patrol":
				gs.resolution_stack.append({"kind": "twin-patrol-wear", "playerIndex": owner, "realmUid": frame.realmUid})
			var depth: int = gs.resolution_stack.size()
			var spirit := summon(gs, owner)
			if spirit.is_empty(): return true
			if kind == "twin-cycle":
				gs._grant_unit_armor(spirit, 2, false)
				gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, spirit.uid), 2)
				var idx: int = gs._unit_index_by_uid(enemy, frame.targetId)
				if idx < 0 or int(gs.player(enemy).units[idx].hp) <= 0: return true
			gs.resolution_stack.insert(depth, {"kind": "twin-attack", "playerIndex": owner, "uid": spirit.uid, "targetId": frame.get("targetId"), "immune": kind == "twin-patrol"})
		"twin-attack":
			_attack(gs, owner, str(frame.uid), frame.targetId, bool(frame.immune))
		"twin-patrol-wear":
			var realm := _find_realm(gs, owner, str(frame.realmUid))
			if not realm.is_empty(): gs.VerifiedRules.ArmorBlood.damage_realm(gs, owner, 3, realm)
		"twin-divine":
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		"twin-awake-start":
			if int(frame.count) >= 2: gs._heal_avatar(owner, 2)
			if int(frame.count) >= 3: gs.VerifiedRules.base_damage_projectile(gs, owner, source(gs, owner), 3)
		"twin-draw":
			if int(frame.remaining) > 1:
				var next := frame.duplicate()
				next.remaining -= 1
				gs.resolution_stack.append(next)
			gs._draw(owner, 1, -1, {"twinRealmInstant": frame.get("instant", false)})
		"twin-god":
			if int(frame.remaining) > 1:
				var next := frame.duplicate()
				next.remaining -= 1
				gs.resolution_stack.append(next)
			if realm_count(gs, owner) >= 2:
				var targets: Array = gs.player(enemy).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u))
				gs._shuffle(targets)
				for chosen in targets.slice(0, 2):
					gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, chosen.uid), 2, owner, source(gs, owner))
				return true
			var history: Array = p.get("twinSightRealmHistory", []).filter(func(id):
				return not p.realms.any(func(r): return str(r.cardId) == id))
			if history.is_empty(): return true
			var card: Dictionary = Content.card_def(str(history[gs.next_random() % history.size()])).duplicate(true)
			card.realm.hp = 2
			gs._deploy_realm(owner, card)
	return true

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id", "") != "c63108": return null
	return gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	if not str(effect.action).begins_with("twin-"): return false
	match str(effect.action):
		"twin-realm":
			gs._deploy_realm(owner, card)
			if card.id == "c63108" and not target.is_empty() and int(target.hp) > 0:
				target.twinZeroTurn = gs.turn_counter
				gs._recalc(target)
		"twin-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c63107": gs.resolution_stack.append({"kind": "twin-god", "playerIndex": owner, "remaining": 2})
			else: gs.VerifiedRules.Divination.start(gs, owner, 1)
		"twin-discover":
			var deck: Array = gs.player(owner).deck.duplicate()
			gs._shuffle(deck)
			var realms := deck.filter(func(i): return _is_realm(i)).slice(0, 2)
			var rest := deck.filter(func(i): return i not in realms)
			if not rest.is_empty(): realms.append(rest[0])
			gs.VerifiedRules.SandBook.offer(gs, owner, owner, "charm-twin-discover", realms, "通阴晓阳", "选择一张牌置入手牌。")
		"twin-awaken":
			summon(gs, owner)
			gs._awaken(owner, src, card, effect.value)
		"twin-incense":
			gs.resolution_stack.append({"kind": "twin-draw", "playerIndex": owner, "remaining": 2, "instant": true})
	return true

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if int(inst.get("twinInstantTurn", -1)) != gs.turn_counter: return card
	var view := card.duplicate(true)
	view.keywords = view.get("keywords", []).duplicate()
	if not gs._kw(view, "instant"): view.keywords.append("instant")
	return view

static func score(gs, owner: int, card: Dictionary, target_id):
	if not str(card.get("effect", "")).begins_with("twin-"): return null
	match str(card.id):
		"c63101": return 54 if cat(gs, owner).is_empty() else 68
		"c63103": return 56 if not gs.player(owner).deck.is_empty() else -90
		"c63105": return 59
		"c63106": return 43 if gs.player(owner).deck.size() > 2 else -80
		"c63107": return 50 + 8 * realm_count(gs, owner)
		"c63108":
			var enemy: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, target_id)
			return 42 + maxi(0, int(enemy.get("attack", 0))) * 4 + 8 * int(enemy.get("front", 0))
	return 50
