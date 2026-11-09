extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "yatiangou-qiuye"
const CHARMS := ["sword", "fire", "water"]
const NAMES := {"sword": "剑神通", "fire": "火神通", "water": "水神通"}
const PRACTICE := "akiba-practice"

static func charms(u: Dictionary) -> Array:
	return u.get("akibaCharms", [])

static func form_barrier(u: Dictionary) -> void:
	if u.get("formRules", {}).get("akibaForm", false) and "water" in charms(u): u.barrier = true

static func give(gs, owner: int, u: Dictionary, key: String) -> void:
	if key in charms(u): return
	if not u.has("akibaCharms"): u.akibaCharms = []
	u.akibaCharms.append(key)
	form_barrier(u)
	gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": u.uid, "charm": NAMES[key]})

static func moved(gs, owner: int, idx: int, prior: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.hp) <= 0 or int(u.front) == prior: return
	if u.get("formRules", {}).get("akibaForm", false) and "sword" in charms(u):
		u.akibaMoveBonus = int(u.get("akibaMoveBonus", 0)) + 1
		gs._recalc(u)
	if int(u.front) == 1 and "sword" in charms(u):
		gs.resolution_stack.append({"kind": "akiba-sword", "playerIndex": owner, "sourceIndex": idx})

static func turn_start(gs, owner: int) -> void:
	var src: int = gs.VerifiedRules.DragonAbyss.source(gs, owner, ID)
	if src >= 0 and int(gs.player(owner).turnsTaken) == 1: gs.VerifiedRules.DragonAbyss.put(gs, owner, PRACTICE)

static func end_turn(gs, owner: int) -> void:
	for idx in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[idx]
		if int(u.hp) > 0 and "water" in charms(u):
			gs._heal_unit(u, 1)
			gs._grant_unit_armor(u, 1)
	for side in 2:
		for u in gs.player(side).units:
			if u.has("akibaMoveBonus") or u.has("akibaFireBonus"):
				u.erase("akibaMoveBonus")
				u.erase("akibaFireBonus")
				u.erase("akibaFireUnyielding")
				gs._recalc(u)

static func bonus(source: Dictionary, target: Dictionary) -> int:
	if target.is_empty(): return 0
	return int("fire" in charms(source)) + (2 if target.get("akibaWeakness", "") in charms(source) else 0)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.get("unitId") != ID: return card
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	var view := card.duplicate(true)
	match str(card.id):
		"c64202":
			if "sword" in charms(u): view.keywords.append("instant")
		"c64207":
			view.value = 1 + charms(u).size()
			view.combatOption.shield = view.value
			view.effects[0].value = view.value
			view.currentCardStats = "+%d力量/+%d护甲" % [int(view.value), int(view.value)]
		"c64201", "c64205":
			var origin := Content.card_def("c13901" if card.id == "c64201" else "c13902").duplicate(true)
			if not origin.is_empty():
				origin.unitId = ID
				view.originCard = origin
	return view

static func targets(gs, owner: int, card: Dictionary):
	match card.get("effect", ""):
		"abyss-akiba-wind":
			return gs.VerifiedRules.DragonAbyss.units(gs, owner, [1-owner]).filter(func(uid):
				var u: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, uid)
				return int(u.front) == 0 and not gs.VerifiedRules.Bingyong.replacement_blocked(gs, 1-owner, u)
			)
		"abyss-akiba-sword":
			var src: int = gs._source_index(owner, card)
			if src < 0: return []
			return gs.VerifiedRules.DragonAbyss.units(gs, owner, [owner]).filter(func(uid): return uid != gs.player(owner).units[src].uid)
	return null

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if card.get("id") != "c64208": return true
	var src: int = gs._source_index(owner, card)
	return src >= 0 and not charms(gs.player(owner).units[src]).is_empty()

static func choose_charm(gs, owner: int, src: int, idx: int, attack_after: bool = false) -> void:
	gs.VerifiedRules.DragonAbyss.choose(gs, owner, "akiba-charm", CHARMS, src, "选择神通", {"labels": NAMES, "targetIndex": idx, "attackAfter": attack_after})

static func choice(gs, owner: int, key: String, c: Dictionary) -> bool:
	var src := int(c.sourceIndex)
	var u: Dictionary = gs.player(owner).units[src]
	match str(c.type):
		"abyss-akiba-charm":
			var idx := int(c.targetIndex)
			var target: Dictionary = gs.player(owner).units[idx]
			give(gs, owner, target, key)
			if c.attackAfter:
				gs._grow_unit(target, 1, 1)
				gs.VerifiedRules.DragonAbyss.attack(gs, owner, idx)
		"abyss-akiba-practice":
			var id := "akiba-exercise-" + key
			gs._push_card_frames(owner, id, null, Content.card_def(id), src, 0, true)
		_: return false
	return true

static func exercise(gs, owner: int, src: int, key: String) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var enemy := 1-owner
	match key:
		"sword":
			gs.VerifiedRules.move_unit(gs, owner, u)
			for target in gs.VerifiedRules.DragonAbyss.living(gs, enemy):
				gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, target.uid), 4 if target.get("akibaWeakness") == key else 2, owner, src)
		"fire":
			u.akibaFireBonus = 2
			u.akibaFireUnyielding = true
			gs._recalc(u)
			var pool: Array = gs.VerifiedRules.DragonAbyss.living(gs, enemy)
			var frames: Array = []
			for i in mini(2, pool.size()):
				var weak := pool.filter(func(t): return t.get("akibaWeakness") == "fire")
				var candidates := pool if weak.is_empty() else weak
				var t: Dictionary = candidates[int(gs.next_random() % candidates.size())]
				pool.erase(t)
				frames.append({"kind": "akiba-fire-attack", "playerIndex": owner, "sourceIndex": src, "targetId": t.uid})
			frames.reverse()
			gs.resolution_stack.append_array(frames)
		"water":
			for target in gs.VerifiedRules.DragonAbyss.living(gs, owner):
				gs._heal_unit(target, int(target.maxHp))
				gs._grant_unit_armor(target, 3)
			for target in gs.VerifiedRules.DragonAbyss.living(gs, enemy):
				if target.get("akibaWeakness") == key: gs.VerifiedRules.Izanami.set_one(gs, enemy, target)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, e: Dictionary, target: Dictionary) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	match str(e.action):
		"abyss-akiba-start": choose_charm(gs, owner, src, src)
		"abyss-akiba-exercise": exercise(gs, owner, src, str(card.id).get_slice("-", 2))
		"abyss-akiba-wind":
			if target.is_empty() or int(target.hp) <= 0: return true
			var idx: int = gs._unit_index_by_uid(1-owner, target.uid)
			gs.VerifiedRules.Movement.move_to(gs, 1-owner, idx, 1)
			if "fire" in charms(u): gs._damage_unit(1-owner, idx, 3, owner, src)
			if "water" in charms(u): gs.VerifiedRules.Stun.apply(gs, 1-owner, idx, 1, owner)
		"abyss-akiba-form":
			gs._apply_form(owner, src, card, e.value)
			form_barrier(u)
		"abyss-akiba-awake":
			gs._awaken(owner, src, card, e.value)
			for target_unit in gs.player(1-owner).units:
				if not target_unit.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(target_unit):
					target_unit.akibaWeakness = CHARMS[int(gs.next_random() % CHARMS.size())]
			choose_charm(gs, owner, src, src)
		"abyss-akiba-sword":
			if not target.is_empty(): choose_charm(gs, owner, src, gs._unit_index_by_uid(owner, target.uid), true)
		"abyss-akiba-combat": gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, null)
		"abyss-akiba-practice":
			var labels := {"sword": "修验·剑", "fire": "修验·火", "water": "修验·水"}
			gs.VerifiedRules.DragonAbyss.choose(gs, owner, "akiba-practice", charms(u).duplicate(), src, "修验", {"labels": labels})
		_: return false
	return true

static func prepare_combat(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> void:
	if options.get("combatCard", {}).get("id") != "c64202" or not gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]): return
	if "fire" in charms(gs.player(owner).units[src]):
		gs.VerifiedRules.HairPower.give(gs, owner, src, 2)
		options.akibaPierce = true

static func finished(gs, owner: int, src: int, options: Dictionary) -> void:
	if options.get("combatCard", {}).get("id") == "c64206":
		var keys := charms(gs.player(owner).units[src]).duplicate()
		var fox: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, owner, src, "akiba-fox", "白狐", 2, 2)
		for key in keys: give(gs, owner, fox, key)
		if "sword" in keys: gs.resolution_stack.append({"kind": "akiba-sword", "playerIndex": owner, "sourceIndex": gs._unit_index_by_uid(owner, fox.uid)})

static func resolve_frame(gs, f: Dictionary) -> bool:
	match f.get("kind"):
		"akiba-sword": gs.VerifiedRules.base_damage_projectile(gs, int(f.playerIndex), int(f.sourceIndex), 1, "剑神通")
		"akiba-fire-attack":
			var owner := int(f.playerIndex)
			var target: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, f.targetId)
			if not target.is_empty() and int(target.hp) > 0:
				var weak: bool = target.get("akibaWeakness") == "fire"
				gs.VerifiedRules.DragonAbyss.attack(gs, owner, int(f.sourceIndex), f.targetId, {"pursuit": true, "pierce": weak, "penetration": weak})
		_: return false
	return true
