extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Shop := preload("res://scripts/battle_shop_rules.gd")
const COVENANTS := ["stars-bond-red", "stars-bond-purple", "stars-bond-blue", "stars-bond-green"]
const DHARMA := ["stars-dharma-growth", "stars-dharma-move", "stars-dharma-bounty", "stars-dharma-attack"]

static func targets(gs, owner: int, card: Dictionary):
	match str(card.get("id", "")):
		"stars-shop-drum":
			return gs.VerifiedRules.FoxFlame.units(gs, 1 - owner).filter(func(u): return int(u.front) == 0 and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
		"stars-shop-dew":
			return gs.player(owner).units.filter(func(u): return int(u.hp) <= 0 and gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)).map(func(u): return str(u.uid))
		"stars-shop-staff":
			return gs.player(1 - owner).realms.filter(func(r): return int(r.hp) > 0).map(func(r): return str(r.uid))
	return null

static func variant(card: Dictionary, name: String, level: int, target: String, action: String, details: String, typ := "spell") -> Dictionary:
	var out := card.duplicate(true)
	out.erase("originCard")
	out.name = name
	out.type = typ
	out.typeLabel = "法术牌" if typ == "spell" else "起源牌"
	out.level = level
	out.target = target
	out.text = details
	out.effects = [{"action":action,"target":target}]
	out.effect = action
	out.keywords = []
	return out

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if card.id not in ["c64903","c64908","c65004","c65006","c65008"]: return card
	var out := card.duplicate(true)
	match str(card.id):
		"c64903": out.value = Shop.used_count(gs, owner) * 2
		"c64908": out.originCard = variant(card, "豪赌·戏法", 2, "auto", "stars-mouse-trick", "投射3点伤害，获得1张「成本控制」。")
		"c65004","c65006":
			var id := "c12303" if card.id == "c65004" else "c12304"
			var origin := Content.card_def(id).duplicate(true)
			origin.unitId = Shop.BIRD
			out.originCard = origin
			var src := Shop.source(gs, owner, Shop.BIRD)
			if card.id == "c65006" and src >= 0 and not gs.player(owner).units[src].get("starsAmbush", []).is_empty(): out.keywords.append("instant")
		"c65008": out.originCard = variant(card, "千羽庇佑·戏法", 2, "auto", "stars-bird-trick", "使以津真天·千寻获得1战力和迅捷，突袭：获得2赏金。")
	return out

static func active(gs, owner: int, role: String) -> int:
	var idx := Shop.source(gs, owner, role)
	return idx if idx >= 0 and gs.VerifiedRules.GiftEnergy.active(gs.player(owner).units[idx]) else -1

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	if Shop.unlocked(gs, owner): Shop.refresh(gs, owner)
	elif Shop.source(gs, owner, Shop.BOND) >= 0 and int(p.get("turnsTaken", 0)) == 0: Shop.open(gs, owner)
	for debt in p.get("starsFluteDebts", []):
		var foe: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, debt)
		if not foe.is_empty():
			foe.starsFlutePower = int(foe.get("starsFlutePower", 0)) + 2
			gs._recalc(foe)
	p.starsFluteDebts = []
	for i in int(p.get("starsDharmaChoices", 0)):
		gs.resolution_stack.append({"kind":"stars-dharma-choice","playerIndex":owner})
	p.starsDharmaChoices = 0

static func realm_trigger(gs, owner: int, realm: Dictionary) -> bool:
	match str(realm.get("nativeRealm", "")):
		"stars-bond-lives": Shop.gain_bounty(gs, owner, 1)
		"stars-bond-covenant":
			var p: Dictionary = gs.player(owner)
			p.starsCovenantGrowth = int(p.get("starsCovenantGrowth", 0)) + 1
		_: return false
	return true

static func realm_destroyed(gs, owner: int, realm: Dictionary) -> void:
	if realm.nativeRealm == "stars-bond-lives" and not realm.get("starsLivesReturned", false):
		Shop.queue(gs, owner, "c64803")

static func basic_targets(gs, owner: int, unit: Dictionary):
	if not unit.get("formRules", {}).get("starsBondBook", false): return null
	var result: Array = ["avatar-%d" % owner]
	for u in gs.player(owner).units:
		if u.uid != unit.uid and int(u.hp) > 0 and not u.get("removed", false):
			result.append(str(u.uid))
	var enemy_front: Dictionary = gs.front_unit(1 - owner)
	if enemy_front.is_empty(): result.append("avatar-%d" % (1 - owner))
	elif not gs.VerifiedRules.Combat.has(enemy_front, "veil"): result.append(str(enemy_front.uid))
	return result

static func friendly_attack(gs, owner: int, src: int, target_id, options: Dictionary) -> bool:
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	if not options.get("basicAttack", false) or not u.get("formRules", {}).get("starsBondBook", false): return false
	var target: Dictionary = gs._unit_by_uid(p.units, target_id)
	if str(target_id) == "avatar-%d" % owner: gs._heal_avatar(owner, int(u.attack))
	elif not target.is_empty() and str(target.uid) != str(u.uid): gs._heal_unit(target, int(u.attack))
	else: return false
	Shop.gain_bounty(gs, owner, 2)
	return true

static func ambush(gs, owner: int, src: int, defender_idx: int, options: Dictionary) -> int:
	var u: Dictionary = gs.player(owner).units[src]
	var power := 0
	for realm in gs.player(owner).realms:
		if realm.nativeRealm == "stars-shop-hall" and realm.get("starsHallFaction", "") == gs.VerifiedRules.Factions.get_faction(u):
			power += 1
			gs._grant_unit_armor(u, 1)
	var effects: Array = u.get("starsAmbush", [])
	if effects.is_empty() or not options.get("basicAttack", false): return power
	if u.id == Shop.BIRD and u.get("formRules", {}).get("starsBirdVengeful", false):
		gs._grant_unit_armor(u, 2)
		Shop.add_hand(gs, owner, Shop.GUIDE)
	if defender_idx < 0: return power
	var victim := int(options.get("combatVictim", 1 - owner))
	if not gs.VerifiedRules.FoxFlame.is_shikigami(gs.player(victim).units[defender_idx]): return power
	u.erase("starsAmbush")
	for data in effects:
		power += int(data.get("power", 0))
		if data.get("pierce", false): options.pierce = true
		if int(data.get("health", 0)) > 0: gs.VerifiedRules.TomatoFire.temp_stats(gs, u, 0, int(data.health))
		Shop.gain_bounty(gs, owner, int(data.get("bounty", 0)))
	return power

static func give_ambush(gs, u: Dictionary, data: Dictionary, temporary: bool = true) -> void:
	var effects: Array = u.get("starsAmbush", [])
	effects.append(data.merged({"expiresTurn":gs.turn_counter if temporary else -1}))
	u.starsAmbush = effects

static func expire(gs) -> void:
	for side in gs.players:
		for unit in side.units:
			if unit.has("starsAmbush"):
				# Older saves did not record the permanent grant from 千羽庇佑 separately.
				unit.starsAmbush = unit.starsAmbush.filter(func(entry):
					var expiration := int(entry.get("expiresTurn", -1 if entry.has("bounty") else entry.get("turn", gs.turn_counter)))
					return expiration < 0 or expiration > gs.turn_counter)
				if unit.starsAmbush.is_empty(): unit.erase("starsAmbush")
			if unit.get("starsShopSwift", false):
				unit.swift = false
				unit.erase("starsShopSwift")
			if unit.has("starsFoxWeak"):
				unit.erase("starsFoxWeak")
				gs._recalc(unit)

static func mouse_damage(gs, owner: int, src: int, amount: int) -> void:
	if owner != gs.current_player or src < 0 or amount <= 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.id != Shop.MOUSE or u.get("baseRulesSuppressed", false) or int(u.level) <= 0: return
	if not u.awakened and int(u.get("starsMouseDamageTurn", -1)) == gs.turn_counter: return
	u.starsMouseDamageTurn = gs.turn_counter
	Shop.add_hand(gs, owner, Shop.COST, 2)

static func destroyed(gs, victim: int, u: Dictionary) -> void:
	if victim < 0: return
	u.erase("starsAmbush")
	u.erase("starsShopSwift")
	var n := int(u.get("starsGoatBounty", 0))
	if n > 0: Shop.gain_bounty(gs, 1 - victim, n)
	u.erase("starsGoatBounty")

static func product_used(gs, owner: int, frame: Dictionary, card: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	var bird := active(gs, owner, Shop.BIRD)
	for field in p.realms:
		if int(field.hp) <= 0 or int(field.get("starsShopTriggerTurn", -1)) == gs.turn_counter: continue
		match str(field.nativeRealm):
			"stars-bird-wind":
				if bird < 0: continue
				field.starsShopTriggerTurn = gs.turn_counter
				gs.VerifiedRules.reduce_countdown(gs, owner, bird, 1)
			"stars-mouse-bribe":
				if card.get("starsBribeCopy", false): continue
				field.starsShopTriggerTurn = gs.turn_counter
				var copy := card.duplicate(true)
				copy.starsBribeCopy = true
				Shop.play_copy(gs, owner, copy, frame.targetId)

static func stack_used(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.has("shopStack") or not frame.get("usedFromHand", false) or card.get("starsDiceCopy", false): return
	var owner := int(frame.playerIndex)
	var src := active(gs, owner, Shop.MOUSE)
	if src < 0 or not gs.player(owner).units[src].get("formRules", {}).get("starsMouseDice", false): return
	if not gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src): return
	var copy := card.duplicate(true)
	copy.starsDiceCopy = true
	Shop.play_copy(gs, owner, copy, frame.targetId)

static func next_covenant(gs, owner: int) -> void:
	var used: Array = gs.player(owner).get("starsCovenants", [])
	var pool := COVENANTS.filter(func(id): return id not in used)
	Shop.queue(gs, owner, "stars-bond-final" if pool.is_empty() else str(pool[int(gs.next_random() % pool.size())]), true)

static func covenant(gs, owner: int, src: int, card: Dictionary, target: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	var enemy := 1 - owner
	var growth := int(p.get("starsCovenantGrowth", 0))
	if not p.has("starsCovenants"): p.starsCovenants = []
	if not p.starsCovenants.has(card.id): p.starsCovenants.append(card.id)
	match str(card.id):
		"stars-bond-red":
			var fi: int = gs.front_index(owner)
			if fi >= 0: gs.VerifiedRules.Movement.move_to(gs, owner, fi, 0)
			gs.VerifiedRules.NativeSummons.summon(gs, owner, src, "stars-bond-house", "缘之屋", 6 + growth, 6 + growth, {"unyielding":true,"countsAsShikigami":false})
		"stars-bond-purple":
			gs._heal_avatar(owner, 4 + growth)
			for u in p.units: gs._heal_unit(u, 4 + growth)
		"stars-bond-blue":
			if not target.is_empty() and int(target.hp) > 0:
				var atk := int(target.attack)
				gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, gs._unit_index_by_uid(enemy, target.uid), card)
				gs._damage_avatar(enemy, atk + growth, owner, src)
		"stars-bond-green":
			for i in 6 + growth:
				if gs.winner >= 0: break
				var pool: Array = gs.VerifiedRules.FoxFlame.units(gs, enemy)
				var pick := int(gs.next_random() % (pool.size() + 1))
				var dealt := 0
				if pick == pool.size(): dealt = gs._damage_avatar(enemy, 1, owner, src)
				else: dealt = int(gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, pool[pick].uid), 1, owner, src).get("damage", 0))
				gs._heal_avatar(owner, dealt)
		"stars-bond-final":
			if COVENANTS.all(func(id): return p.starsCovenants.has(id)):
				gs.player(enemy).avatarHp = 0
				gs._check_winner()
			return
	next_covenant(gs, owner)

static func exclusive(gs, owner: int, target: Dictionary, count: int) -> void:
	if target.is_empty(): return
	var pool: Array = gs.VerifiedRules.DragonAbyss.exclusive(target)
	for i in count:
		if not pool.is_empty(): Shop.add_hand(gs, owner, str(pool[int(gs.next_random() % pool.size())].id))

static func dharma(gs, owner: int, id: String, target: Dictionary, payment: bool) -> void:
	match id:
		"stars-dharma-growth":
			if target.is_empty(): return
			gs._grow_unit(target, 2, 2)
			if payment: gs.VerifiedRules.Stun.apply(gs, owner, gs._unit_index_by_uid(owner, target.uid), 1, owner)
		"stars-dharma-move":
			if target.is_empty(): return
			exclusive(gs, owner, target, 2)
			if payment: gs.VerifiedRules.Panguan.destroy(gs, owner, -1, owner, gs._unit_index_by_uid(owner, target.uid), {})
		"stars-dharma-bounty":
			Shop.gain_bounty(gs, owner, 6)
			if payment:
				for i in mini(2, gs.player(owner).hand.size()): gs.discard_hand_card(owner, int(gs.next_random() % gs.player(owner).hand.size()))
		"stars-dharma-attack":
			gs._damage_avatar(1 - owner, 4, owner)
			if payment:
				var pool: Array = gs.VerifiedRules.FoxFlame.units(gs, owner)
				if not pool.is_empty(): pool[int(gs.next_random() % pool.size())].enraged = true
				gs.VerifiedRules.StarBear.suppress(gs, 1 - owner, 3, 3)

static func choice(gs, owner: int, iid: String, data: Dictionary) -> bool:
	var p: Dictionary = gs.player(owner)
	match str(data.type):
		"stars-bond-awaken":
			var src := int(data.sourceIndex)
			if iid == "discount": p.starsBondDiscount = true
			else: gs._awaken(owner, src, Content.card_def("c64804"), {"attack":1,"hp":1})
		"stars-dharma":
			Shop.add_hand(gs, 1 - owner, iid)
			if iid in ["stars-dharma-growth", "stars-dharma-move"]:
				var pool: Array = gs.VerifiedRules.FoxFlame.units(gs, owner)
				gs.VerifiedRules.StarRealms.choose(gs, owner, "dharma-unit", pool.map(func(u): return str(u.uid)), -1, "万宝槌 · 选择式神", {"dharma":iid,"unitIds":true})
			else: dharma(gs, owner, iid, {}, true)
		"stars-dharma-unit": dharma(gs, owner, str(data.dharma), gs._unit_by_uid(p.units, iid), true)
		"stars-shop-hall":
			for r in p.realms:
				if r.uid == data.realmId: r.starsHallFaction = iid
		_: return false
	return true

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var enemy := 1 - owner
	var idx: int = gs._unit_index_by_uid(enemy, target_id)
	var wind := int(p.get("starsWindUsed", 0))
	match str(effect.action):
		"stars-bond-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c64801": p.units[src].swift = true
			else:
				Shop.gain_bounty(gs, owner, 2)
				Shop.bless(gs, owner, 1)
		"stars-bond-thread":
			var opened := Shop.unlocked(gs, owner)
			Shop.gain_bounty(gs, owner, 2)
			if opened: Shop.refresh(gs, owner)
			Shop.bless(gs, owner, 1)
		"abyss-stars-bond-lives":
			gs._deploy_realm(owner, card)
			p.realms.back().starsLivesReturned = card.get("shopRealmReturned", false)
			Shop.gain_bounty(gs, owner, 2)
		"stars-bond-awaken":
			gs.VerifiedRules.StarRealms.choose(gs, owner, "bond-awaken", ["discount","awaken"], src, "天降良缘", {"labels":{"discount":"福缘降价","awaken":"觉醒"},"details":{"discount":"福缘的赏金消耗额外-1。","awaken":"获得牌面觉醒能力。"}})
		"stars-bond-shrine":
			gs.VerifiedRules.HairPower.give(gs, owner, gs._unit_index_by_uid(owner, target_id), 3)
			gs._grant_unit_armor(target, 3)
			if int(p.get("starsBondBlessed", 0)) >= 3: target.starsBondResolute = true
		"abyss-stars-bond-covenant":
			gs._deploy_realm(owner, card)
			next_covenant(gs, owner)
		"stars-bond-wish":
			for item in Shop.offers(gs, owner).duplicate():
				if not Shop.buy(gs, owner, str(item.slot), true) or not item.blessed: continue
				var pool: Array = p.units.filter(func(u): return int(u.hp) <= 0 and gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u))
				if not pool.is_empty():
					var u: Dictionary = pool[int(gs.next_random() % pool.size())]
					if gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false): gs._grow_unit(u, 2, 2)
			Shop.refresh(gs, owner)
		"stars-bond-token": covenant(gs, owner, src, card, target)
		"stars-mouse-battle":
			var extras: Dictionary = {}
			if card.id == "c64901":
				Shop.add_hand(gs, owner, Shop.COST, 2)
				extras.directAvatar = Shop.used_count(gs, owner) > 0
			elif card.id == "c64904":
				gs.resolution_stack.append({"kind":"stars-mouse-secret-battle","playerIndex":owner,"sourceIndex":src,"card":card})
				Shop.random_hand(gs, owner)
				return true
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, target_id, extras)
		"stars-mouse-form": gs._apply_form(owner, src, card, effect.value)
		"stars-mouse-awaken":
			p.starsCostDamage = int(p.get("starsCostDamage", 0)) + 1
			gs._awaken(owner, src, card, effect.value)
			p.units[src].swift = true
		"stars-mouse-cost":
			Shop.gain_bounty(gs, owner, int(card.get("shopLayers", 1)))
			var damage := int(p.get("starsCostDamage", 0))
			if damage > 0: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, damage)
		"stars-mouse-mallet":
			Shop.gain_bounty(gs, owner, 4)
			gs.player(enemy).starsDharmaChoices = int(gs.player(enemy).get("starsDharmaChoices", 0)) + 1
		"abyss-stars-mouse-bribe":
			gs._deploy_realm(owner, card)
			Shop.add_hand(gs, owner, Shop.COST, 3)
		"stars-mouse-gamble":
			gs.resolution_stack.append({"kind":"stars-mouse-gamble-step","playerIndex":owner,"sourceIndex":src,"remaining":2})
		"stars-mouse-trick":
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 3)
			Shop.add_hand(gs, owner, Shop.COST)
		"stars-bird-battle":
			var options := {}
			if card.id == "c65001": options.firstStrike = wind >= 3
			elif card.id == "c65004":
				if wind >= 3:
					card = card.duplicate(true)
					card.value = int(card.value) + 1
					options.pierce = true
			elif card.id == "c65008": Shop.gain_bounty(gs, owner, wind)
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, card, target_id, options)
		"stars-bird-value":
			Shop.add_hand(gs, owner, Shop.GUIDE, 2 if wind >= 3 else 1)
			Shop.gain_bounty(gs, owner, 2)
		"stars-bird-bounty": Shop.gain_bounty(gs, owner, 2)
		"abyss-stars-bird-wind":
			gs._deploy_realm(owner, card)
			Shop.gain_bounty(gs, owner, 2)
		"stars-bird-awaken":
			gs.VerifiedRules.reduce_countdown(gs, owner, src, 1)
			gs._awaken(owner, src, card, effect.value)
			var timer: Dictionary = p.units[src].get("abilityCountdown", {})
			if not timer.is_empty():
				timer.reset = 1
				timer.remaining = mini(1, int(timer.remaining))
		"stars-bird-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c65007": Shop.gain_bounty(gs, owner, 5)
		"stars-bird-guide":
			var layers := int(card.get("shopLayers", 1))
			p.starsWindUsed = wind + layers
			var golden: bool = p.units[src].get("formRules", {}).get("starsBirdGolden", false)
			for i in layers + (1 if golden and layers == 1 else 0):
				var pool: Array = gs.VerifiedRules.FoxFlame.units(gs, enemy)
				if pool.is_empty() or gs.winner >= 0: break
				var foe: Dictionary = pool[int(gs.next_random() % pool.size())]
				gs._damage_unit(enemy, gs._unit_index_by_uid(enemy, foe.uid), 2, owner, src)
			if golden and layers == 2 and not p.units[src].get("swift", false):
				p.units[src].swift = true
				p.units[src].starsShopSwift = true
			if golden and layers == 3: gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 4)
		"stars-bird-trick":
			gs.VerifiedRules.HairPower.give(gs, owner, src, 1)
			p.units[src].swift = true
			give_ambush(gs, p.units[src], {"bounty":2}, false)
		_: return false
	return true

static func product(gs, owner: int, card: Dictionary, target_id) -> void:
	var p: Dictionary = gs.player(owner)
	var enemy := 1 - owner
	var target: Dictionary = gs._unit_by_uid(gs._all_units(), target_id)
	var idx: int = gs._unit_index_by_uid(enemy, target_id)
	match str(card.id):
		"stars-shop-swift":
			if not target.is_empty():
				target.swift = true
				target.starsShopSwift = true
				give_ambush(gs, target, {"power":2})
		"stars-shop-ink": gs._draw(owner, 1)
		"stars-shop-armor":
			var heal := 10 if int(p.avatarHp) <= 10 else 5
			p.maxAvatarHp += 5
			gs._heal_avatar(owner, heal)
		"stars-shop-moon":
			if idx >= 0: gs._damage_unit(enemy, idx, 3, owner)
		"stars-shop-kite":
			var src: int = gs._unit_index_by_uid(owner, target_id)
			if src >= 0:
				if int(target.hp) <= 0 and int(target.knockout) == 1: gs.VerifiedRules.Peach.revive(gs, owner, -1, target, false, false)
				elif int(target.hp) <= 0: target.knockout = maxi(0, int(target.knockout) - 1)
				else: gs.VerifiedRules.reduce_countdown(gs, owner, src, 1)
		"stars-shop-flute":
			if idx >= 0:
				var debts: Array = p.get("starsFluteDebts", [])
				debts.append(target.uid)
				p.starsFluteDebts = debts
				target.starsFlutePower = int(target.get("starsFlutePower", 0)) - 2
				gs._recalc(target)
		"stars-shop-dew":
			if not target.is_empty() and gs.VerifiedRules.Peach.revive(gs, owner, -1, target, true, false):
				target.starsShopSwift = true
				give_ambush(gs, target, {"power":1,"health":1})
		"stars-shop-hall":
			gs._deploy_realm(owner, card)
			var ids: Array = gs.VerifiedRules.Factions.VALUES.duplicate()
			var labels := {}
			for key in ids: labels[key] = key
			gs.VerifiedRules.StarRealms.choose(gs, owner, "shop-hall", ids, -1, "共鸣回廊", {"labels":labels,"realmId":p.realms.back().uid})
		"stars-shop-drum":
			if idx >= 0 and int(target.front) == 0:
				var original := str(target.get("form", {}).get("cardId", ""))
				if not original.is_empty():
					gs.VerifiedRules.Forms.remove(gs, enemy, idx, "渊鸣鼓")
				gs.VerifiedRules.Stun.apply(gs, enemy, idx, 1, owner)
		"stars-shop-staff":
			for realm in gs.player(enemy).realms.duplicate():
				if str(realm.uid) != str(target_id): continue
				realm.hp -= 6
				if int(realm.hp) <= 0: gs.VerifiedRules.Huang.destroy(gs, enemy, realm, "被破界")
		"stars-shop-meal":
			if not target.is_empty():
				gs._grow_unit(target, 1, 1)
				var keys: Array = target.get("keywords", [])
				if "pierce" not in keys: keys.append("pierce")
				target.keywords = keys
		"stars-shop-fan":
			for u in gs.VerifiedRules.FoxFlame.units(gs, owner):
				u.swift = true
				u.starsShopSwift = true
				give_ambush(gs, u, {"power":2,"pierce":true})
		"stars-shop-wine":
			gs._damage_avatar(enemy, 3, owner)
			Shop.state(gs, owner).sold.erase(card.id)
			Shop.queue(gs, owner, card.id)
			Shop.refresh(gs, owner)
		"stars-shop-compass":
			var pool: Array = gs.VerifiedRules.FoxFlame.units(gs, enemy)
			var max_power := -2147483648
			for u in pool: max_power = maxi(max_power, int(u.attack))
			pool = pool.filter(func(u): return int(u.attack) == max_power)
			if not pool.is_empty():
				var u: Dictionary = pool[int(gs.next_random() % pool.size())]
				gs.VerifiedRules.Panguan.destroy(gs, owner, -1, enemy, gs._unit_index_by_uid(enemy, u.uid), card)
			Shop.gain_bounty(gs, owner, 3)
		"stars-shop-bow":
			for n in [5,2]:
				var front: int = gs.front_index(enemy)
				if front < 0: gs._damage_avatar(enemy, n, owner)
				else: gs._damage_unit(enemy, front, n, owner)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex", -1))
	var src := int(frame.get("sourceIndex", -1))
	match str(frame.kind):
		"stars-dharma-choice":
			gs.VerifiedRules.StarRealms.choose(gs, owner, "dharma", DHARMA.duplicate(), -1, "万宝槌 · 愿望与代价", {"cardIds":true})
			return true
		"stars-mouse-secret-battle":
			gs.VerifiedRules.DragonAbyss.combat(gs, owner, src, frame.card, null)
			return true
		"stars-mouse-gamble-step":
			if int(frame.remaining) <= 0: return true
			gs.resolution_stack.append({"kind":"stars-mouse-gamble-step","playerIndex":owner,"sourceIndex":src,"remaining":int(frame.remaining)-1})
			gs.resolution_stack.append({"kind":"stars-mouse-gamble-shot","playerIndex":owner,"sourceIndex":src})
			Shop.random_hand(gs, owner)
			return true
		"stars-mouse-gamble-shot":
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 3)
			return true
	var card: Dictionary = frame.get("cardOverride", {})
	if not card.get("shopNeutral", false): return false
	match str(frame.kind):
		"card-announce":
			gs.VerifiedRules.announce_neutral_food(gs, frame)
		"card-effect":
			var previous: Dictionary = gs._card_effect_context
			gs._card_effect_context = frame
			if str(card.id).begins_with("stars-dharma-"):
				dharma(gs, owner, str(card.id), gs._unit_by_uid(gs.player(owner).units, frame.targetId), false)
			else: product(gs, owner, card, frame.targetId)
			gs._card_effect_context = previous
		"card-complete":
			Shop.completed(gs, frame, card)
			if frame.get("usedFromHand", false): gs.VerifiedRules.GoatHeist.after_action(gs, owner)
		_: return false
	return true
