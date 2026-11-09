extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Flow := preload("res://scripts/dragon_flow_rules.gd")
const CAT := "maozhanggui-huanyan"
const REMODELS := ["blueprint-remodel-0","blueprint-remodel-1","blueprint-remodel-2"]
const SERVERS := ["blueprint-server-1","blueprint-server-2","blueprint-server-3","blueprint-server-4","blueprint-server-5"]

static func threshold(realm: Dictionary) -> int:
	var id := str(realm.get("nativeRealm", ""))
	if id in REMODELS: return 6
	if id == "blueprint-meal": return 10
	if id == "blueprint-festival": return 15
	return 0

static func boards(gs, owner: int) -> Array:
	return gs.player(owner).realms.filter(func(r): return int(r.hp) > 0 and threshold(r) > 0)

static func find_board(gs, owner: int, uid: String) -> Dictionary:
	for r in boards(gs, owner):
		if r.uid == uid: return r
	return {}

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("id") == "c65805":
		var out := card.duplicate(true)
		var origin := Content.card_def("c24601").duplicate(true)
		origin.unitId = CAT
		out.originCard = origin
		return out
	if card.get("id") == "c65804":
		var out := card.duplicate(true)
		out.value = 5 if int(gs.player(owner).get("blueprintRealmLeftTurn", -1)) == gs.turn_counter else 3
		out.effects[0].value = out.value
		out.currentCardStats = "降低力量与生命各%d" % out.value
		return out
	if card.get("neutralFood", false) and inst.get("blueprintFeastInstant", false) and gs.VerifiedRules.Cooking.food_kind(card) == "feast":
		var out := card.duplicate(true)
		if "instant" not in out.keywords: out.keywords.append("instant")
		return out
	return card

static func targets(gs, owner: int, card: Dictionary):
	if card.get("target") != "blueprint-choice": return null
	return boards(gs, owner).map(func(realm): return str(realm.uid))

static func remodel(gs, owner: int) -> void:
	var id: String = REMODELS[int(gs.next_random() % REMODELS.size())]
	gs._deploy_realm(owner, Content.card_def(id))

static func turn_start(gs, owner: int) -> void:
	var src := Flow.active(gs, owner, CAT)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.awakened or not boards(gs,owner).any(func(r): return r.nativeRealm in REMODELS):
		remodel(gs, owner)

static func realm_tick(gs, owner: int, r: Dictionary) -> bool:
	if threshold(r) <= 0: return false
	gs.VerifiedRules.Huang.gain(gs, owner, r, 2)
	return true

static func realm_entered(gs, owner: int, r: Dictionary) -> void:
	var src := Flow.active(gs, owner, CAT)
	if src >= 0 and gs.player(owner).units[src].awakened:
		gs.VerifiedRules.Huang.gain(gs, owner, r, 1)

static func durability(gs, owner: int, uid: String) -> void:
	var r := find_board(gs, owner, uid)
	if r.is_empty(): return
	var src := Flow.source(gs, owner, CAT)
	if r.nativeRealm == "blueprint-festival":
		if int(r.hp) >= 8 and not r.get("blueprintEight", false):
			r.blueprintEight = true
			Flow.all_damage(gs, owner, src, 3, false)
		if int(r.hp) >= 11 and not r.get("blueprintEleven", false):
			r.blueprintEleven = true
			gs._set_fire(owner, int(gs.player(owner).energy)+2)
	if int(r.hp) >= threshold(r): complete(gs, owner, src, r, false)

static func gain_random(gs, owner: int, n: int) -> void:
	var pick := Choice.sample(gs, boards(gs, owner), 1)
	if not pick.is_empty(): gs.VerifiedRules.Huang.gain(gs, owner, pick[0], n)

static func permanent_delta(gs, owner: int, src: int, victim: int, idx: int, attack: int, health: int, temporary: bool = false) -> void:
	if idx < 0: return
	var u: Dictionary = gs.player(victim).units[idx]
	if int(u.hp) <= 0: return
	var hp := int(u.hp)
	if temporary:
		u.blueprintTempAttack = int(u.get("blueprintTempAttack", 0))+attack
		u.blueprintTempHealth = int(u.get("blueprintTempHealth", 0))+health
		u.blueprintTempTurn = gs.turn_counter
	else: gs.VerifiedRules.Glutton.record_permanent(u, attack, health)
	gs._grow_unit(u, attack, health)
	u.hp = maxi(0, mini(int(u.hp), hp + health))
	if int(u.hp) == 0: gs._knockout_unit(u, owner, src)

static func end_turn(gs, _owner: int) -> void:
	for side in 2:
		for u in gs.player(side).units:
			if int(u.get("blueprintTempTurn",-1)) != gs.turn_counter: continue
			var atk := int(u.get("blueprintTempAttack",0))
			var health := int(u.get("blueprintTempHealth",0))
			u.erase("blueprintTempAttack")
			u.erase("blueprintTempHealth")
			u.erase("blueprintTempTurn")
			var hp := int(u.hp)
			gs._grow_unit(u, -atk, -health)
			if hp > 0: u.hp = hp

static func cooked_meal(gs, owner: int, src: int, dish: Array, targets: Array) -> void:
	var cooking = gs.VerifiedRules.Cooking
	var inst: Dictionary = cooking._instance(gs, {"kind":"feast","quality":3,"parts":dish})
	var card: Dictionary = cooking.describe_food(gs, owner, inst)
	card.cookingAbilitySource = src
	var ordered := targets.duplicate()
	ordered.reverse()
	for ally in ordered: cooking._push_food(gs, owner, card, ally.uid, false, true)

static func complete(gs, owner: int, src: int, r: Dictionary, forced: bool) -> void:
	if r.is_empty() or (not forced and r.get("blueprintFinished", false)): return
	var p: Dictionary = gs.player(owner)
	var rank := int(p.units[src].level) if src >= 0 else 1
	if not forced:
		r.blueprintFinished = true
		p.blueprintCompleted = int(p.get("blueprintCompleted",0))+1
		gs.VerifiedRules.Huang.destroy(gs, owner, r, "蓝图完成")
	gs.VerifiedRules.event(gs, "blueprint-completed", {"player":owner,"realm":r.uid,"id":r.nativeRealm,"forced":forced})
	var active := Flow.active(gs, owner, CAT)
	if active >= 0 and p.units[active].get("formRules", {}).get("blueprintProjection", false):
		gs.resolution_stack.append({"kind":"cosmos-blueprint-projectile","playerIndex":owner,"sourceIndex":active})
	match r.nativeRealm:
		"blueprint-remodel-0": gs.VerifiedRules.Cooking.cook(gs, owner, src)
		"blueprint-remodel-1": gs.VerifiedRules.HairPower.grant_guard(gs, owner, 1+int(rank>=2), 1+int(rank>=3))
		"blueprint-remodel-2": permanent_delta(gs, owner, src, 1-owner, gs.front_index(1-owner), -1-int(rank>=2), -1-int(rank>=3), true)
		"blueprint-meal":
			var cooking = gs.VerifiedRules.Cooking
			cooking.gain_feast(gs, owner, src, cooking.random_feast_parts(gs, owner, src))
			for inst in p.hand:
				if cooking.food_kind(inst) == "feast": inst.blueprintFeastInstant = true
		"blueprint-festival":
			for u in p.units.duplicate():
				if gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u):
					gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
			var dish: Array = gs.VerifiedRules.Cooking.random_feast_parts(gs, owner, src)
			cooked_meal(gs, owner, src, dish, Choice.live_units(gs, owner))

static func moved(gs, owner: int, idx: int, previous: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if previous == 1 or int(u.front) != 1 or not gs.VerifiedRules.OwlInsect.shikigami(u): return
	for _realm in gs.VerifiedRules.DuskCycle.realms(gs, owner, "blueprint-meal"):
		gs.VerifiedRules.Cooking.auto_use_generated(gs, owner, Flow.source(gs, owner, CAT), u.uid, "ingredient")

static func choice_card(gs, owner: int, id: String):
	return Content.card_def(id) if Choice.matches(gs, owner, id, "cosmos-server") else null

static func resolve_choice(gs, owner: int, id: String) -> bool:
	if not Choice.matches(gs, owner, id, "cosmos-server"): return false
	Choice.accept(gs, owner, id)
	var p: Dictionary = gs.player(owner)
	if not p.has("blueprintServed"): p.blueprintServed = []
	p.blueprintServed.append(id)
	Choice.give(gs, owner, id)
	Choice.finish(gs)
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex",-1))
	var src := int(frame.get("sourceIndex",-1))
	match frame.get("kind"):
		"cosmos-blueprint-projectile": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, "回馈计划")
		"cosmos-server-choice":
			var seen: Array = gs.player(owner).get("blueprintServed", [])
			Choice.offer(gs, owner, "cosmos-server", SERVERS.filter(func(id): return id not in seen), "猫侍应招来")
		"cosmos-blueprint-assault":
			if int(gs.player(owner).units[src].hp) > 0: Flow.assault(gs, owner, src, frame.card)
		_: return false
	return true

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	if src < 0: return false
	var p: Dictionary = gs.player(owner)
	match effect.action:
		"blueprint-1":
			gs.resolution_stack.append({"kind":"cosmos-blueprint-assault","playerIndex":owner,"sourceIndex":src,"card":card})
			gain_random(gs, owner, 3)
		"blueprint-2":
			gs.resolution_stack.append({"kind":"cosmos-server-choice","playerIndex":owner,"sourceIndex":src})
			gain_random(gs, owner, 3)
		"blueprint-3":
			gs._apply_form(owner, src, card, effect.value)
			for side in 2:
				for r in gs.player(side).realms.duplicate(): gs.VerifiedRules.Huang.gain(gs, side, r, 2)
		"blueprint-4":
			permanent_delta(gs, owner, src, 1-owner, gs._unit_index_by_uid(1-owner,target_id), -int(effect.value), -int(effect.value))
		"blueprint-5": gs._deploy_realm(owner, card)
		"blueprint-6":
			Choice.give(gs, owner, "c65802")
			remodel(gs, owner)
			gs._awaken(owner, src, card, effect.value)
		"blueprint-7":
			gs._deploy_realm(owner, card)
			var r: Dictionary = p.realms.back()
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 3, card.name)
			gs.VerifiedRules.Huang.gain(gs, owner, r, int(p.get("blueprintCompleted",0)))
		"blueprint-8":
			complete(gs, owner, src, find_board(gs, owner, str(target_id)), true)
			gs._heal_avatar(owner, 4)
		"blueprint-server":
			match int(card.serverId):
				1:
					if gs.VerifiedRules.Peach.revive(gs, owner, src, target, false, false):
						gs.VerifiedRules.Glutton.record_permanent(target, 1, 1)
						gs._grow_unit(target,1,1)
				2:
					gs.VerifiedRules.Cooking.cook(gs, owner, src)
					var size := 2+floori(float(p.get("blueprintRealmUsed",0))/3.0)
					gs.VerifiedRules.NativeSummons.summon(gs, owner, src, "blueprint-cat-spirit", "猫灵", size, size)
				3:
					var idx: int = gs._unit_index_by_uid(owner, target_id)
					gs.VerifiedRules.HairPower.give(gs, owner, idx, 1)
					Choice.attack(gs, owner, idx, null, {"immuneCombat":true})
				4:
					gs.VerifiedRules.Cooking.cook(gs, owner, src)
					gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 5, card.name)
				5:
					gs.VerifiedRules.Cooking.cook(gs, owner, src)
					if not target.is_empty(): cooked_meal(gs, owner, src, [{"attack":1},{"hp":1},{"keyword":"pierce"}], [target])
		_: return false
	return true
