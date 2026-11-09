extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const FOX := "baizangzhu-lixin"

static func marked(u: Dictionary) -> int:
	return int(u.get("foxFlameBlue", 0)) + int(u.get("foxFlameRed", 0))

static func units(gs, owner: int, marked_only: bool = false) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and (not u.get("summoned", false) or u.get("countsAsShikigami", false)) and (not marked_only or marked(u) > 0))

static func attach(gs, owner: int, src: int, u: Dictionary, red := false) -> void:
	if src < 0 or u.is_empty() or int(u.hp) <= 0: return
	var fox: Dictionary = gs.player(owner).units[src]
	var key := "foxFlameRed" if red or fox.awakened else "foxFlameBlue"
	u[key] = int(u.get(key, 0)) + 1
	gs.VerifiedRules.event(gs, "fox-flame-attached", {"player":owner,"uid":fox.uid,"target":u.uid,"color":key})
	if int(fox.hp) <= 0 or not fox.get("formRules", {}).get("starsFoxAttack", false) or int(fox.get("foxFlameAttackTurn", -1)) == gs.turn_counter: return
	fox.foxFlameAttackTurn = gs.turn_counter
	gs.resolution_stack.append({"kind":"stars-fox-followup","playerIndex":owner,"sourceIndex":src,"targetId":u.uid})

static func damage_delta(gs, victim: int, target: Dictionary, owner: int, src: int, combat: bool) -> int:
	if src < 0 or owner < 0 or owner == victim: return 0
	var attacker: Dictionary = gs.player(owner).units[src]
	if not is_shikigami(attacker) or not is_shikigami(target): return 0
	var snapshot: Dictionary = gs.fox_flame_snapshot if combat else {}
	var source_marks: int = int(snapshot.get(attacker.uid, {}).get("total", marked(attacker)))
	var red: int = int(snapshot.get(target.uid, {}).get("red", target.get("foxFlameRed", 0)))
	return (1 if red > 0 else 0) - (1 if source_marks > 0 else 0)

static func snapshot(a: Dictionary, b: Dictionary) -> Dictionary:
	return {a.uid:{"total":marked(a),"red":int(a.get("foxFlameRed",0))},b.uid:{"total":marked(b),"red":int(b.get("foxFlameRed",0))}}

static func is_shikigami(u: Dictionary) -> bool:
	return not u.get("summoned", false) or u.get("countsAsShikigami", false)

static func spent(gs, victim: int, target: Dictionary, owner: int, src: int, dealt: int) -> void:
	if owner < 0 or src < 0 or owner == victim or dealt <= 0: return
	var source: Dictionary = gs.player(owner).units[src]
	if not is_shikigami(source) or not is_shikigami(target): return
	if int(source.get("foxFlameRed", 0)) > 0: source.foxFlameRed -= 1
	elif int(source.get("foxFlameBlue", 0)) > 0: source.foxFlameBlue -= 1
	if int(target.get("foxFlameRed", 0)) > 0: target.foxFlameRed -= 1

static func completed(gs, owner: int, src: int) -> void:
	var idx: int = gs._source_index(1 - owner, {"unitId":FOX})
	if src < 0 or idx < 0: return
	var fox: Dictionary = gs.player(1 - owner).units[idx]
	var enemy: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.GiftEnergy.active(fox) or int(fox.get("foxFlameTurn", -1)) == gs.turn_counter or int(enemy.hp) <= 0 or not is_shikigami(enemy): return
	fox.foxFlameTurn = gs.turn_counter
	attach(gs, 1 - owner, idx, enemy)

static func neutral(card: Dictionary) -> bool:
	return card.get("faction", "") == "neutral" or card.get("unitId", "") in ["", "neutral"] or card.get("neutralFood", false) or card.get("neutralEssence", false) or card.get("nativeNeutral", false)

static func hand_pool(gs, owner: int, only_neutral := false) -> Array:
	var hand: Array = gs.player(owner).hand
	return hand.filter(func(inst): return not only_neutral or neutral(Content.card_def(str(inst.definitionId))))

static func take(gs, owner: int, iid: String, discard: bool) -> Dictionary:
	var hand: Array = gs.player(owner).hand
	for i in hand.size():
		if str(hand[i].instanceId) != iid: continue
		return gs.discard_hand_card(owner, i) if discard else hand.pop_at(i)
	return {}

static func copy_neutral(gs, owner: int) -> void:
	var pool := hand_pool(gs, 1 - owner, true)
	if pool.is_empty(): return
	var inst: Dictionary = pool[int(gs.next_random() % pool.size())]
	var copy: Dictionary = inst.duplicate(true)
	copy.instanceId = gs.VerifiedRules.GiftEnergy.fresh_instance(gs, owner, str(inst.definitionId)).instanceId
	gs.VerifiedRules.Baize.put_hand(gs, owner, copy)

static func lure(gs, owner: int, src: int) -> void:
	var pool := hand_pool(gs, 1 - owner).duplicate()
	var ids: Array = []
	while not pool.is_empty() and ids.size() < 2: ids.append(str(pool.pop_at(int(gs.next_random() % pool.size())).instanceId))
	gs.VerifiedRules.StarRealms.choose(gs, owner, "fox-lure", ids, src, "狐诱之计", {"zoneOwner":1 - owner,"zone":"hand"})

static func choice(gs, owner: int, iid: String, data: Dictionary) -> bool:
	if data.type != "stars-fox-lure": return false
	var src := int(data.sourceIndex)
	for inst in hand_pool(gs, 1 - owner):
		if inst.instanceId != iid: continue
		var card := Content.card_def(str(inst.definitionId))
		var idx: int = gs._source_index(1 - owner, card)
		if neutral(card):
			gs._damage_avatar(1 - owner, 1, owner, src)
		elif idx >= 0:
			gs._damage_unit(1 - owner, idx, 1, owner, src)
			attach(gs, owner, src, gs.player(1 - owner).units[idx])
		break
	return true

static func realm_trigger(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm", "") != "stars-fox-realm": return false
	var src: int = gs._source_index(owner, {"unitId":FOX})
	var enemy := 1 - owner
	var pool := units(gs, enemy)
	if not pool.is_empty(): attach(gs, owner, src, pool[int(gs.next_random() % pool.size())])
	var shadow := int(gs.next_random() % 6)
	var candidates := units(gs, enemy, shadow != 5)
	var target: Dictionary = {} if candidates.is_empty() else candidates[int(gs.next_random() % candidates.size())]
	var idx: int = gs._unit_index_by_uid(enemy, target.get("uid",""))
	match shadow:
		0:
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, enemy, idx, 1, owner, src)
		1: copy_neutral(gs, owner)
		2:
			if idx >= 0: gs._damage_unit(enemy, idx, 4, owner, src)
		3:
			if idx >= 0:
				gs.VerifiedRules.Movement.move_to(gs, enemy, idx, 1)
				target.starsFoxWeak = int(target.get("starsFoxWeak", 0)) + 1
				target.brittle = int(target.brittle) + 1
				gs._recalc(target)
		4:
			var front: int = gs.front_index(owner)
			if front >= 0: gs._grant_unit_armor(gs.player(owner).units[front], 2)
			else: gs._grant_avatar_armor(owner, 2)
		5: attach(gs, owner, src, target)
	realm.hp -= 2
	if int(realm.hp) <= 0: gs.VerifiedRules.Huang.destroy(gs, owner, realm, "狐影消散")
	return true

static func counter(gs, frame: Dictionary) -> bool:
	if not frame.get("usedFromHand", false): return false
	var next := frame.duplicate(true)
	next.kind = "card-counter-check"
	return gs.VerifiedRules.automatic_response(gs, 1 - int(frame.playerIndex), "stars-fox-counter", null, next)

static func basic_targets(gs, owner: int, u: Dictionary):
	if not u.get("formRules", {}).get("starsFoxHowl", false): return null
	var enemy := 1 - owner
	var result := units(gs, enemy).filter(func(x): return not gs.VerifiedRules.Combat.has(x, "veil") and (marked(x) > 0 or int(x.front) == 1)).map(func(x): return str(x.uid))
	if gs.front_index(enemy) < 0: result.push_front("avatar-%d" % enemy)
	return result

static func prepare_combat(gs, owner: int, src: int, victim: int, target: int) -> int:
	if target < 0 or not gs.player(owner).units[src].get("formRules", {}).get("starsFoxHowl", false): return 0
	var defender: Dictionary = gs.player(victim).units[target]
	if not is_shikigami(defender): return 0
	var bonus := marked(defender)
	if bonus <= 0: return 0
	gs.VerifiedRules.HairPower.give(gs, owner, src, bonus)
	gs._grant_unit_armor(gs.player(owner).units[src], bonus)
	return 0

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	var enemy := 1 - owner
	match str(effect.action):
		"stars-fox-guard":
			attach(gs, owner, src, target)
			gs._draw(owner, 1)
		"stars-fox-form":
			gs._apply_form(owner, src, card, effect.value)
			match str(card.id):
				"c65102": lure(gs, owner, src)
				"c65106": u.swift = true
				"c65107": attach(gs, owner, src, target)
		"abyss-stars-fox-realm":
			gs._deploy_realm(owner, card)
			realm_trigger(gs, owner, gs.player(owner).realms.back())
		"stars-fox-discipline":
			if card.has("starsFoxCounter"):
				var original: Dictionary = card.starsFoxCounter
				var rid := int(original.resolutionId)
				gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != rid)
				var denied: Dictionary = original.get("cardOverride", Content.card_def(str(original.definitionId)))
				gs.VerifiedRules.event(gs, "card-nullified", {"player":enemy,"resolutionId":rid,"card":denied})
				if neutral(denied): gs.VerifiedRules.Stun.apply(gs, enemy, -1, 1, owner, src)
			else:
				var pool := hand_pool(gs, enemy, true)
				if not pool.is_empty(): take(gs, enemy, str(pool[int(gs.next_random() % pool.size())].instanceId), true)
		"stars-fox-awake":
			gs._awaken(owner, src, card, effect.value)
			for foe in gs.player(enemy).units:
				foe.foxFlameRed = marked(foe)
				foe.erase("foxFlameBlue")
			var pool := units(gs, enemy)
			for i in mini(2, pool.size()): attach(gs, owner, src, pool.pop_at(int(gs.next_random() % pool.size())), true)
		"stars-fox-blaze":
			for foe in units(gs, enemy, true): gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, foe.uid), marked(foe) + 3, owner, src)
		"stars-fox-blaze-trick":
			if not target.is_empty() and marked(target) > 0: gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, target.uid), 4, owner, src)
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.kind == "stars-fox-lure-turn":
		lure(gs, int(frame.playerIndex), int(frame.sourceIndex))
		return true
	if frame.kind != "stars-fox-followup": return false
	gs.VerifiedRules.DragonAbyss.attack(gs, int(frame.playerIndex), int(frame.sourceIndex), frame.targetId, {"pursuit":true,"immuneCombat":true})
	return true
