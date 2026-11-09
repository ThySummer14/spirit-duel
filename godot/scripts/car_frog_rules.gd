extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const CAR := "longche"
const ARMY := "stars-frog-army"
const FROGS := ["stars-frog-wind", "stars-frog-light", "stars-frog-blade", "stars-frog-gourd", "stars-frog-fist", "stars-frog-flower"]
const CHOICES := ["repair", "clean", "rest"]

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId":CAR})

static func frog(u: Dictionary) -> bool:
	return u.has("starsFrog") or u.has("starsFrogTransform")

static func front_frog(gs, owner: int) -> int:
	var idx: int = gs.front_index(owner)
	return idx if idx >= 0 and gs.player(owner).units[idx].has("starsFrog") else -1

static func spawn(gs, owner: int, src: int, id: String = "") -> int:
	if gs.winner >= 0 or src < 0: return -1
	var p: Dictionary = gs.player(owner)
	if id.is_empty(): id = FROGS[int(gs.next_random() % FROGS.size())]
	var def := Content.card_def(id)
	var config: Dictionary = def.value
	var buff := (1 if p.get("starsFrogEncouraged", false) else 0) + (1 if p.units[src].awakened else 0)
	var existing: int = gs.front_index(owner)
	if existing >= 0: gs.VerifiedRules.Movement.move_to(gs, owner, existing, 0)
	var u: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, owner, src, id, str(def.name), int(config.attack), int(config.hp), {"starsFrog":id, "starsFrogIncarnation":id == ARMY})
	if buff > 0: gs._grow_unit(u, buff, buff)
	if id != ARMY: p.starsFrogsSummoned = int(p.get("starsFrogsSummoned", 0)) + 1
	return gs._unit_index_by_uid(owner, u.uid)

static func projectile(gs, owner: int, src: int, damage: int) -> void:
	gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, damage)

static func spell_for(id: String, empowered: bool) -> Dictionary:
	var key := id.trim_prefix("stars-frog-")
	return Content.card_def("stars-frog-spell-" + key + ("-boost" if empowered else ""))

static func incarnation_pool(gs, owner: int) -> Array:
	var strong: bool = gs.VerifiedRules.ForestSpirit.has_realm(gs, owner, "stars-car-realm")
	return FROGS.map(func(id): return spell_for(id, strong)).filter(func(card): return not card.is_empty())

static func special(gs, owner: int, idx: int) -> void:
	var p: Dictionary = gs.player(owner)
	if idx < 0 or idx >= p.units.size(): return
	var u: Dictionary = p.units[idx]
	if int(u.hp) <= 0 or not frog(u): return
	var id := str(u.get("starsFrog", u.get("starsFrogTransform", "")))
	if id == ARMY: id = FROGS[int(gs.next_random() % FROGS.size())]
	var card := spell_for(id, gs.VerifiedRules.ForestSpirit.has_realm(gs, owner, "stars-car-realm"))
	if not card.is_empty(): gs._push_card_frames(owner, str(card.id), null, card, idx, 0, true)

static func exclusive(gs, owner: int, idx: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.hp) <= 0 or not frog(u): return
	var id := str(card.starsFrogKind)
	var strong := bool(card.starsFrogBoost)
	gs.VerifiedRules.event(gs, "frog-exclusive", {"player":owner,"uid":u.uid,"frog":id,"empowered":strong})
	match id:
		"stars-frog-wind":
			for foe in gs.VerifiedRules.FoxFlame.units(gs, 1 - owner):
				gs._damage_unit(1 - owner, gs._unit_index_by_uid(1 - owner, foe.uid), 2 if strong else 1, owner, idx)
		"stars-frog-light":
			for i in (5 if strong else 3): projectile(gs, owner, idx, 1)
		"stars-frog-blade":
			gs.VerifiedRules.DragonAbyss.attack(gs, owner, idx, null, {"immuneCombat":true,"starsFrogAbility":true}, 2 if strong else 0)
		"stars-frog-gourd":
			gs.VerifiedRules.DragonAbyss.attack(gs, owner, idx, null, {"unyielding":true,"starsFrogAbility":true}, 3 if strong else 1)
		"stars-frog-fist": gs._grow_unit(u, 3 if strong else 2, 0)
		"stars-frog-flower": gs._grant_unit_armor(u, 5 if strong else 3)

static func reduce_ko(gs, owner: int, src: int) -> void:
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) > 0 or int(u.knockout) <= 0: return
	u.knockout = int(u.knockout) - 1
	if int(u.knockout) == 0 and gs.VerifiedRules.Rebirth.can_revive(u):
		gs._resolve_action(owner, src, {}, {"action":"revive","target":"source","value":0}, null, {})

static func turn_start(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if int(u.hp) > 0 and frog(u) and u.get("starsFrog", "") != ARMY: reduce_ko(gs, owner, source(gs, owner))
	for side in 2:
		for u in gs.player(side).units:
			if int(u.get("starsFrogRestorePlayer", -1)) != owner: continue
			var form: Dictionary = u.get("starsFrogOldForm", {})
			gs.VerifiedRules.Fortune.restore(u)
			u.form = form.get("form", {})
			u.formRules = form.get("formRules", {})
			u.formHooks = form.get("formHooks", [])
			u.formAbility = form.get("formAbility", "")
			for key in ["starsFrogRestorePlayer", "starsFrogOldForm", "starsFrogTransform"]: u.erase(key)
			gs._recalc(u)

static func spell_bonus(gs, owner: int, src: int, combat: bool) -> int:
	if owner < 0 or src < 0 or combat: return 0
	var p: Dictionary = gs.player(owner)
	if src >= p.units.size(): return 0
	var caster: Dictionary = p.units[src]
	if caster.id != CAR and not frog(caster): return 0
	var idx := source(gs, owner)
	return 1 if idx >= 0 and int(p.units[idx].hp) > 0 and p.units[idx].get("formRules", {}).get("starsCarFrogs", false) else 0

static func damaged(gs, owner: int, idx: int, damage: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if u.id == CAR and not u.awakened and not u.get("baseRulesSuppressed", false) and int(u.level) > 0 and damage > 0:
		gs.resolution_stack.append({"kind":"stars-car-hurt","playerIndex":owner,"sourceIndex":idx})

static func transform(gs, owner: int, victim: int, idx: int) -> void:
	if idx < 0: return
	var u: Dictionary = gs.player(victim).units[idx]
	if int(u.hp) <= 0 or not gs.VerifiedRules.FoxFlame.is_shikigami(u): return
	if not u.has("starsFrogOldForm"):
		u.starsFrogOldForm = {"form":u.get("form", {}).duplicate(true),"formRules":u.get("formRules", {}).duplicate(true),"formHooks":u.get("formHooks", []).duplicate(true),"formAbility":u.get("formAbility", "")}
	var id := str(FROGS[int(gs.next_random() % FROGS.size())])
	var def := Content.card_def(id)
	gs.VerifiedRules.Fortune.transform(gs, victim, idx, false, id, str(def.name), int(def.value.hp))
	u.form.attackBonus = int(def.value.attack) - int(u.baseAttack)
	u.starsFrogRestorePlayer = owner
	u.starsFrogTransform = id
	gs._recalc(u)

static func replace_attack(gs, owner: int, src: int, options: Dictionary) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	if u.id != CAR or not u.awakened or u.get("baseRulesSuppressed", false) or not options.get("basicAttack", false): return false
	gs.VerifiedRules.StarRealms.choose(gs, owner, "car-maintain", CHOICES, src, "保养时间", {
		"labels":{"repair":"维修呱","clean":"清洗呱","rest":"摸鱼呱"},
		"details":{"repair":"召唤呱太并使其获得2护甲后发起攻击，胧车受到2点伤害。","clean":"召唤呱太并使用其专属牌，胧车受到2点伤害。","rest":"胧车恢复5点生命。"},
		"basic":options.get("basicAttack", false)})
	return true

static func choice(gs, owner: int, iid: String, data: Dictionary) -> bool:
	var src := int(data.sourceIndex)
	if data.type == "stars-car-select":
		spawn(gs, owner, src, iid)
		return true
	if data.type != "stars-car-maintain": return false
	if data.get("basic", false): gs.resolution_stack.push_front({"kind":"stars-action-after","playerIndex":owner})
	if iid == "rest":
		gs._heal_unit(gs.player(owner).units[src], 5)
		return true
	var idx := front_frog(gs, owner)
	if idx < 0 or gs.player(owner).units[idx].get("starsFrog", "") != ARMY: idx = spawn(gs, owner, src)
	if idx < 0: return true
	gs.resolution_stack.append({"kind":"stars-car-self-damage","playerIndex":owner,"sourceIndex":src})
	if iid == "clean": special(gs, owner, idx)
	else:
		gs._grant_unit_armor(gs.player(owner).units[idx], 2)
		gs.VerifiedRules.DragonAbyss.attack(gs, owner, idx, null, {"starsFrogAbility":true})
	return true

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	match str(effect.action):
		"stars-car-frog-exclusive": exclusive(gs, owner, src, card)
		"stars-car-dance":
			projectile(gs, owner, src, 4)
			gs._damage_unit(owner, src, 2, owner, src)
		"stars-car-encourage":
			var idx := spawn(gs, owner, src)
			if idx < 0: return true
			if p.get("starsFrogEncouraged", false): special(gs, owner, idx)
			else:
				p.starsFrogEncouraged = true
				for u in p.units:
					if u.has("starsFrog") and int(u.hp) > 0: gs._grow_unit(u, 1, 1)
		"stars-car-battle": gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, null, card.combatOption)
		"stars-car-awake":
			gs._heal_avatar(owner, 3)
			gs._heal_unit(p.units[src], 3)
			gs._awaken(owner, src, card, effect.value)
		"stars-car-transform":
			var side := owner if gs._unit_index_by_uid(owner, target_id) >= 0 else 1 - owner
			transform(gs, owner, side, gs._unit_index_by_uid(side, target_id))
		"stars-car-form":
			gs._apply_form(owner, src, card, effect.value)
			if not frog(gs.front_unit(owner)):
				gs.VerifiedRules.StarRealms.choose(gs, owner, "car-select", FROGS.duplicate(), src, "呱太降临", {"cardIds":true})
		"stars-car-army": spawn(gs, owner, src, ARMY)
		"abyss-stars-car-realm":
			gs._deploy_realm(owner, card)
			if str(gs.front_unit(owner).get("starsFrog", "")) != ARMY: spawn(gs, owner, src)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	match str(frame.kind):
		"stars-car-hurt": spawn(gs, int(frame.playerIndex), int(frame.sourceIndex))
		"stars-car-self-damage": gs._damage_unit(int(frame.playerIndex), int(frame.sourceIndex), 2, int(frame.playerIndex), int(frame.sourceIndex))
		_: return false
	return true
