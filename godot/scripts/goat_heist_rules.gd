extends RefCounted

const GOAT := "guijinyang"
const NOTICE := "stars-goat-notice"
const Content := preload("res://scripts/content_loader.gd")

static func index(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId":GOAT})

static func amount(u: Dictionary) -> int:
	return 2 if u.awakened else 1

static func realm(gs, owner: int) -> bool:
	return gs.VerifiedRules.ForestSpirit.has_realm(gs, owner, "stars-goat-realm")

static func direct(gs, owner: int, u: Dictionary) -> bool:
	if u.id != GOAT or u.get("baseRulesSuppressed", false) or not realm(gs, owner): return false
	var front: Dictionary = gs.front_unit(1 - owner)
	return not front.is_empty() and gs.VerifiedRules.OwlInsect.shikigami(front) and int(front.attack) >= 5

static func temporary(gs, owner: int, src: int, target: Dictionary) -> void:
	if target.is_empty() or int(target.hp) <= 0: return
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var stolen := amount(u)
	if not p.has("starsGoatDebts"): p.starsGoatDebts = []
	p.starsGoatDebts.append({"uid":target.uid,"amount":stolen,"sourceUid":u.uid})
	target.starsGoatAttack = int(target.get("starsGoatAttack", 0)) - stolen
	u.starsGoatAttack = int(u.get("starsGoatAttack", 0)) + stolen
	p.starsGoatStolenAttack = int(p.get("starsGoatStolenAttack", 0)) + stolen
	gs._recalc(target)
	gs._recalc(u)

static func steal_hp(gs, owner: int, src: int, target: Dictionary) -> void:
	if target.is_empty() or int(target.hp) <= 0: return
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	var stolen := mini(int(target.maxHp) - 1, amount(u))
	if stolen <= 0: return
	var life := int(target.hp)
	gs._grow_unit(target, 0, -stolen)
	target.hp = maxi(0, life - stolen)
	gs._grow_unit(u, 0, stolen)
	p.starsGoatStolenHp = int(p.get("starsGoatStolenHp", 0)) + stolen
	if int(target.hp) == 0: gs._knockout_unit(target, owner, src)

static func avatar_steal(gs, owner: int, src: int, victim: int) -> int:
	var p: Dictionary = gs.player(owner)
	var foe: Dictionary = gs.player(victim)
	var stolen := mini(int(foe.maxAvatarHp) - 1, amount(p.units[src]))
	if stolen <= 0: return 0
	foe.maxAvatarHp -= stolen
	foe.avatarHp = maxi(0, int(foe.avatarHp) - stolen)
	p.maxAvatarHp += stolen
	gs._heal_avatar(owner, stolen)
	p.starsGoatStolenHp = int(p.get("starsGoatStolenHp", 0)) + stolen
	gs._check_winner()
	return stolen

static func avatar_hit(gs, owner: int, src: int, victim: int, dealt: int) -> void:
	if owner < 0 or owner == victim or src < 0 or dealt <= 0: return
	if gs.player(owner).units[src].id == GOAT and realm(gs, owner): avatar_steal(gs, owner, src, victim)

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var src := index(gs, owner)
	if src < 0: return
	var u: Dictionary = p.units[src]
	for debt in p.get("starsGoatDebts", []):
		var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, debt.uid)
		if not target.is_empty():
			target.starsGoatAttack = int(target.get("starsGoatAttack", 0)) + int(debt.amount)
			gs._recalc(target)
		u.starsGoatAttack = int(u.get("starsGoatAttack", 0)) - int(debt.amount)
	p.starsGoatDebts = []
	gs._recalc(u)
	var stolen := int(p.get("starsGoatFire", 0))
	if stolen > 0: gs._set_fire(owner, int(p.energy) + stolen)
	p.erase("starsGoatFire")
	if gs.VerifiedRules.GiftEnergy.active(u) and not p.hand.any(func(inst): return inst.definitionId == NOTICE):
		gs.VerifiedRules.DragonAbyss.put(gs, owner, NOTICE)

static func after_action(gs, owner: int) -> void:
	if owner != gs.current_player or int(gs.player(owner).energy) < 2 or gs.winner >= 0: return
	gs.VerifiedRules.automatic_response(gs, 1 - owner, "stars-goat-after-action", null, {"kind":"response-complete"})

static func after_combat(gs, owner: int, options: Dictionary) -> void:
	if options.get("starsGoatEndTurn", false):
		gs.resolution_stack.push_front({"kind":"stars-goat-end-turn","playerIndex":gs.current_player})
	if options.get("basicAttack", false): after_action(gs, owner)

static func respond_combat(gs, owner: int, src: int, cid: int, card: Dictionary) -> void:
	for frame in gs.resolution_stack:
		if frame.kind != "combat-hit" or int(frame.get("combatId", -1)) != cid: continue
		frame.defenderImmuneCombat = true
		frame.defenderBonus = int(frame.get("defenderBonus", 0)) + int(card.value)
		frame.defenderPierce = true
		frame.starsGoatCounterCrit = true
		frame.options.starsGoatEndTurn = true
		break

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var p: Dictionary = gs.player(owner)
	var enemy := 1 - owner
	var u: Dictionary = p.units[src]
	match str(effect.action):
		"stars-goat-combat":
			match str(card.id):
				"c65201": temporary(gs, owner, src, target)
				"c65202":
					steal_hp(gs, owner, src, target)
					if int(p.get("starsGoatNoticeTurn", -1)) == gs.turn_counter:
						for i in amount(u):
							var pool: Array = gs.VerifiedRules.FoxFlame.hand_pool(gs, enemy, true)
							if pool.is_empty() or p.hand.size() >= int(gs.rules.get("maxHandSize", 12)): break
							var iid := str(pool[int(gs.next_random() % pool.size())].instanceId)
							gs.VerifiedRules.Baize.put_hand(gs, owner, gs.VerifiedRules.FoxFlame.take(gs, enemy, iid, false))
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, null, {"starsGoatEndTurn":card.id == "c65208"})
		"abyss-stars-goat-realm": gs._deploy_realm(owner, card)
		"stars-goat-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c65207":
				gs._grow_unit(u, int(p.get("starsGoatStolenAttack", 0)), int(p.get("starsGoatStolenHp", 0)))
		"stars-goat-awake":
			temporary(gs, owner, src, target)
			gs._awaken(owner, src, card, effect.value)
		"stars-goat-fire":
			var taken := mini(1, int(gs.player(enemy).energy))
			if taken > 0:
				gs._set_fire(enemy, int(gs.player(enemy).energy) - taken)
				p.starsGoatFire = int(p.get("starsGoatFire", 0)) + taken
		"stars-goat-notice":
			p.starsGoatNoticeTurn = gs.turn_counter
			var front: int = gs.front_index(enemy)
			if front < 0: gs._damage_avatar(enemy, 1, owner, src)
			else: gs._damage_unit(enemy, front, 1, owner, src)
			u.starsGoatBounty = int(u.get("starsGoatBounty", 0)) + 1
			if u.get("formRules", {}).get("starsGoatSilent", false):
				u.starsGoatNoticePower = int(u.get("starsGoatNoticePower", 0)) + 2
				if not u.get("swift", false):
					u.swift = true
					u.starsShopSwift = true
				gs._recalc(u)
			if u.get("formRules", {}).get("starsGoatChain", false):
				gs.VerifiedRules.DragonAbyss.attack(gs, owner, src, null, {"directAvatar":true})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.kind != "stars-goat-end-turn": return false
	var owner := int(frame.playerIndex)
	if owner != gs.current_player: return true
	var previous: bool = gs.is_resolving
	gs.is_resolving = false
	gs.end_turn(owner)
	gs.is_resolving = previous
	return true
