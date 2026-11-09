class_name GiftEnergyRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const LONG := "longzi"
const SMOKE := "yanyanluo-fumiao"
const SUNNY := "rihefang-qingyang"
const WATERFALL := "c63608"
const GIFT_PREFIX := "gift:"
const SUNNY_GIFTS := [
	{"key": "projectile", "cost": 1, "text": "投射：造成2点伤害。"},
	{"key": "power-attack", "cost": 2, "text": "+2战力并发起一次攻击。"},
	{"key": "revive", "cost": 2, "text": "气绝时可用，复活自己。"},
	{"key": "fire", "cost": 4, "text": "获得1点鬼火。"},
]

static func active(unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and int(unit.get("level", 0)) > 0 and not unit.get("removed", false) and not unit.get("baseRulesSuppressed", false)

static func index(gs, owner: int, role: String) -> int:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if u.id == role and not u.get("summoned", false): return i
	return -1

static func options(inst: Dictionary) -> Array:
	if inst.is_empty() or inst.get("giftSpent", false): return []
	var card := Content.card_def(str(inst.get("definitionId", "")))
	if card.get("type") == "coop": return []
	var used: Array = inst.get("giftUsedKeys", [])
	var available: Array = granted(inst)
	available.append_array(card.get("giftOptions", []))
	return available.filter(func(option): return effect_key(option) not in used)

static func granted(inst: Dictionary) -> Array:
	var result: Array = []
	for gift in ([inst.giftGranted] if inst.has("giftGranted") else []) + inst.get("giftAdditional", []):
		var option: Dictionary = gift.duplicate()
		option.instanceKey = "granted:" + str(gift.key)
		result.append(option)
	return result

static func effect_key(option: Dictionary) -> String:
	return str(option.get("instanceKey", option.key))

static func printed_used(inst: Dictionary) -> int:
	return inst.get("giftUsedKeys", []).filter(func(key): return not str(key).begins_with("granted:")).size()

static func modes(card: Dictionary) -> Array:
	var result: Array = [false]
	if card.has("originCard"): result.append(true)
	result.append_array(card.get("nativePlayModes", []))
	for i in card.get("giftAvailable", []).size(): result.append(GIFT_PREFIX + str(i))
	return result

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("giftEnergyRules", false) and not inst.has("giftGranted"): return card
	var out := card.duplicate(true)
	out.giftAvailable = options(inst)
	if inst.has("giftGranted") or inst.get("giftSpent", false) or inst.has("giftUsedKeys"):
		var first_gift := str(out.text).find("\n赐能")
		if first_gift >= 0: out.text = str(out.text).left(first_gift)
		if out.giftAvailable.is_empty(): out.text += "\n赐能效果已使用。"
		else:
			for gift in out.giftAvailable: out.text += "\n赐能%d：%s" % [int(gift.cost), str(gift.text)]
	if card.id == "c63702":
		var origin := Content.card_def("c16601").duplicate(true)
		origin.unitId = SUNNY
		out.originCard = origin
	if card.id == "c63405" and inst.get("giftDirect", false):
		out.combatOption.directAvatar = true
		out.text += "\n直击。"
	if card.id == "c63407":
		var growth := int(gs.player(owner).get("giftWaveGrowth", 0))
		out.value = 1 + growth
		out.effects[0].value = out.value
		out.combatOption.shield = 1 + growth
	if card.id == WATERFALL:
		out.giftRepeatCost = 2 if printed_used(inst) < 3 else 1
	return out

static func as_gift(gs, owner: int, inst: Dictionary, base: Dictionary, mode: String) -> Dictionary:
	if not mode.begins_with(GIFT_PREFIX): return {}
	var pick := mode.trim_prefix(GIFT_PREFIX)
	var choices := options(inst)
	if not pick.is_valid_int() or int(pick) < 0 or int(pick) >= choices.size(): return {}
	var chosen: Dictionary = choices[int(pick)]
	var src: int = gs._source_index(owner, base)
	if src < 0: return {}
	var key := str(chosen.key)
	var cost := int(chosen.cost)
	var u: Dictionary = gs.player(owner).units[src]
	if u.id == LONG and int(u.get("giftDiscountTurn", -1)) == gs.turn_counter:
		cost = maxi(0, cost - int(u.get("giftDiscount", 0)))
	var out := {
		"id": base.id, "name": base.name, "unitId": base.unitId, "art": base.get("art", ""),
		"type": "spell", "typeLabel": "法术牌", "rarity": base.get("rarity", ""), "verifiedRules": true,
		"level": 1, "cost": 1, "keywords": ["instant"], "timing": "main", "responseTo": [],
		"target": chosen.get("target", "auto"), "giftEnergyMode": true, "giftKey": key,
		"giftInstanceKey": effect_key(chosen), "giftCost": cost, "giftFreeTurn": int(inst.get("giftFreeTurn", -1)), "allowKnockedSource": key == "revive" or gs.VerifiedRules.ForestSpirit.spirit(u),
		"text": "瞬发。赐能%d：%s" % [cost, chosen.text], "effect": "gift-energy-effect",
		"effects": [{"action":"gift-energy-effect","target":chosen.get("target", "auto"),"value":key}],
	}
	for key_name in ["sourceZone", "insightFromZone", "insightSerial", "yanmieFromDeck", "yanmieFree",
			"lilyFromDeck", "lilyRoadDamage", "twoFacesFromDeck", "twoFacesDeckFree"]:
		if base.has(key_name): out[key_name] = base[key_name]
	if out.get("lilyFromDeck", false): out.lilyDeckFree = true
	if key in ["hurt", "aoe", "projectile", "random"]: out.responseAction = "damage"
	if key == "revive": out.responseAction = "revive"
	return out

static func sunny_awake(gs, owner: int) -> int:
	var idx := index(gs, owner, SUNNY)
	if idx >= 0 and active(gs.player(owner).units[idx]) and gs.player(owner).units[idx].awakened: return idx
	return -1

static func free_fire(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("giftEnergyMode", false): return {}
	var src: int = gs._source_index(owner, card)
	var u: Dictionary = gs.player(owner).units[src]
	var sun_free: bool = sunny_awake(gs, owner) >= 0 and int(gs.player(owner).get("giftSunnyFreeTurn", -1)) != gs.turn_counter
	var long_free: bool = u.id == LONG and int(u.get("giftDiscountTurn", -1)) == gs.turn_counter and u.get("giftLongFree", false)
	return {"baseFree": sun_free or long_free or int(card.giftFreeTurn) == gs.turn_counter, "sunny": sun_free}


static func payment(gs, owner: int, src: int, cost: int) -> Dictionary:
	var own := mini(cost, int(gs.player(owner).units[src].get("charge", 0)))
	var provider := index(gs, owner, SUNNY)
	var backup := 0
	if provider >= 0 and provider != src and active(gs.player(owner).units[provider]):
		backup = mini(cost - own, int(gs.player(owner).units[provider].get("charge", 0)))
	return {"ok": own + backup == cost, "own": own, "backup": backup, "provider": provider}

static func pay(gs, owner: int, src: int, cost: int) -> bool:
	var quote := payment(gs, owner, src, cost)
	if not quote.ok: return false
	spend(gs, owner, src, int(quote.own))
	if int(quote.backup) > 0: spend(gs, owner, int(quote.provider), int(quote.backup))
	return true

static func spend(gs, owner: int, src: int, amount: int) -> void:
	if amount <= 0: return
	var u: Dictionary = gs.player(owner).units[src]
	u.charge = int(u.get("charge", 0)) - amount
	gs._recalc(u)
	spent(gs, owner, src, amount)

static func spent(gs, owner: int, src: int, amount: int) -> void:
	if amount <= 0: return
	var p: Dictionary = gs.player(owner)
	var sunny := index(gs, owner, SUNNY)
	if sunny < 0: return
	p.giftTeamSpent = int(p.get("giftTeamSpent", 0)) + amount
	var u: Dictionary = p.units[sunny]
	if sunny != src or u.get("formRules", {}).get("giftEnergyForm") != "c63708": return
	if int(u.get("giftSunSpendTurn", -1)) != gs.turn_counter:
		u.giftSunSpendTurn = gs.turn_counter
		u.giftSunSpent = 0
	u.giftSunSpent = int(u.get("giftSunSpent", 0)) + amount
	if int(u.giftSunSpent) < 5 or int(u.get("giftSunBlastTurn", -1)) == gs.turn_counter: return
	u.giftSunBlastTurn = gs.turn_counter
	gs.resolution_stack.append({"kind": "gift-sunny-blast", "playerIndex": owner, "sourceIndex": sunny, "amount": 5 + int(int(p.giftTeamSpent) / 5)})

static func can_use(gs, owner: int, src: int, card: Dictionary) -> bool:
	if card.get("giftEnergyMode", false):
		if not payment(gs, owner, src, int(card.giftCost)).ok: return false
		if card.giftKey == "revive": return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, gs.player(owner).units[src])
	if card.get("giftEnergyRules", false) and card.id == WATERFALL:
		return int(gs.player(owner).units[src].charge) >= int(card.giftRepeatCost)
	return true

static func used(gs, owner: int, src: int, card: Dictionary, inst: Dictionary, quote: Dictionary) -> void:
	if not card.get("giftEnergyMode", false): return
	if quote.get("giftSunnyFree", false):
		gs.player(owner).giftSunnyFreeTurn = gs.turn_counter
		gs._heal_avatar(owner, 2)
	var u: Dictionary = gs.player(owner).units[src]
	if u.id == LONG:
		u.erase("giftDiscountTurn")
		u.erase("giftDiscount")
		u.erase("giftLongFree")
	pay(gs, owner, src, int(card.giftCost))
	consume_effect(inst, str(card.giftInstanceKey))
	gs.resolution_stack.append({"kind": "gift-return", "playerIndex": owner, "instance": inst})

static func consume_effect(inst: Dictionary, key: String) -> void:
	if not inst.has("giftUsedKeys"): inst.giftUsedKeys = []
	if key not in inst.giftUsedKeys: inst.giftUsedKeys.append(key)
	inst.giftSpent = options(inst).is_empty()
	if key == "direct": inst.giftDirect = true

static func remember(gs, owner: int, inst: Dictionary, used_mode := false) -> void:
	if options(inst).is_empty(): return
	var p: Dictionary = gs.player(owner)
	if index(gs, owner, SMOKE) < 0: return
	if not p.has("giftHistory"): p.giftHistory = []
	if p.giftHistory.any(func(previous): return previous.instanceId == inst.instanceId): return
	if inst.definitionId == "c63606": return
	var entry := inst.duplicate(true)
	if used_mode: entry.erase("giftSpent")
	p.giftHistory.append(entry)

static func targets(gs, owner: int, card: Dictionary):
	if card.get("giftEnergyRules", false):
		var command: bool = card.id in ["c63406", "c63603"]
		if command or card.id == "c63706":
			var units: Array = gs.player(owner).units
			return units.filter(func(u): return not u.get("summoned", false) and (not command or int(u.hp) > 0 and not gs.VerifiedRules.Stun.blocks(gs, owner, u) and gs.VerifiedRules.Samurai.available(u))).map(func(u): return u.uid)
	if not card.get("giftEnergyMode", false) or card.giftKey != "hurt": return null
	var result: Array = []
	for side in 2:
		var p: Dictionary = gs.player(side)
		if int(p.get("giftHurtTurn", -1)) == gs.turn_counter and int(p.avatarHp) > 0 and (side == owner or not gs.VerifiedRules.PipeFox.avatar_veil(gs, side)): result.append("avatar-%d" % side)
		for u in p.units:
			if int(u.get("giftHurtTurn", -1)) == gs.turn_counter and int(u.hp) > 0 and not u.get("removed", false):
				if side == owner or not (gs.VerifiedRules.Combat.has(u, "veil") or gs.VerifiedRules.Movement.has_veil(u)): result.append(u.uid)
	return result

static func avatar_damage(gs, victim: int, owner: int, src: int, amount: int, combat: bool) -> void:
	if amount <= 0: return
	gs.player(victim).giftHurtTurn = gs.turn_counter
	if not combat or owner < 0 or src < 0 or owner == victim: return
	var p: Dictionary = gs.player(owner)
	var long_idx := index(gs, owner, LONG)
	if long_idx >= 0:
		var u: Dictionary = p.units[long_idx]
		if active(u) and (src == long_idx or u.awakened) and int(u.get("giftLongTriggerTurn", -1)) != gs.turn_counter:
			u.giftLongTriggerTurn = gs.turn_counter
			u.giftDiscountTurn = gs.turn_counter
			u.giftDiscount = 3 if u.awakened else 2
			u.giftLongFree = u.awakened and src == long_idx
	for realm in p.realms:
		if int(realm.hp) > 0 and realm.nativeRealm == "c63406" and int(realm.get("giftDrawTurn", -1)) != gs.turn_counter:
			realm.giftDrawTurn = gs.turn_counter
			gs.resolution_stack.append({"kind": "gift-draw", "playerIndex": owner})

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var p: Dictionary = gs.player(owner)
	var gift: bool = card.get("giftEnergyMode", false)
	var burst: bool = card.get("yujArrow", false) or int(card.get("movementBurst", 0)) > 0
	for i in p.units.size():
		var u: Dictionary = p.units[i]
		if not active(u): continue
		var form: String = u.get("formRules", {}).get("giftEnergyForm", "")
		if (gift or burst) and form == "c63403":
			gs.VerifiedRules.HairPower.give(gs, owner, i, 2)
			var traits: Array = u.get("untilAttack", {}).get("keywords", []).duplicate()
			if not traits.has("pierce"): traits.append("pierce")
			if not u.has("untilAttack"): u.untilAttack = {}
			u.untilAttack.keywords = traits
		if (gift or burst) and form == "c63408" and owner == gs.current_player: grant_swift(gs, owner, i, true)
		if form == "c63703" and int(u.get("giftSunFormTurn", -1)) != gs.turn_counter:
			u.giftSunFormTurn = gs.turn_counter
			if gift or burst: gs._apply_encourage(owner, 1, 0)
			else: gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, i, 1)
		if u.id == SMOKE and card.get("usedFromHand", false) and (i == src or u.awakened):
			var amount := 2 if i == src and u.awakened else 1
			if gift:
				gs.resolution_stack.append({"kind": "gift-projection", "playerIndex": owner, "sourceIndex": i, "amount": amount})
			else: gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, i, amount)
	if not gift: return
	var smoke := index(gs, owner, SMOKE)
	if smoke < 0: return
	for realm in p.realms:
		if int(realm.hp) > 0 and realm.nativeRealm == "c63607":
			gs.resolution_stack.append({"kind": "gift-clone-attack", "playerIndex": owner, "sourceIndex": smoke})

static func grant_swift(gs, owner: int, idx: int, barrier: bool) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u): return
	u.swift = true
	gs.VerifiedRules.Combat.grant_inspired(gs, owner, idx)
	if barrier: u.barrier = true

static func new_effect(inst: Dictionary, gift: Dictionary) -> void:
	if Content.card_def(str(inst.get("definitionId", ""))).get("type") == "coop": return
	var key := "granted:" + str(gift.key)
	if not granted(inst).any(func(option): return effect_key(option) == key):
		if inst.has("giftGranted"):
			if not inst.has("giftAdditional"): inst.giftAdditional = []
			inst.giftAdditional.append(gift.duplicate(true))
		else: inst.giftGranted = gift.duplicate(true)
	if inst.has("giftUsedKeys"): inst.giftUsedKeys.erase(key)
	inst.giftSpent = false

static func drawn(gs, owner: int, inst: Dictionary) -> void:
	if owner != gs.current_player: return
	var src: int = gs._source_index(owner, Content.card_def(inst.definitionId))
	if src < 0 or int(gs.player(owner).units[src].hp) > 0: return
	for realm in gs.player(owner).realms:
		if int(realm.hp) > 0 and realm.nativeRealm == "c63706" and int(realm.get("giftReviveTurn", -1)) != gs.turn_counter:
			realm.giftReviveTurn = gs.turn_counter
			new_effect(inst, SUNNY_GIFTS[2])
			return

static func draw_chosen(gs, owner: int, iid: String) -> void:
	var deck: Array = gs.player(owner).deck
	for i in deck.size():
		if deck[i].instanceId != iid: continue
		deck.append(deck.pop_at(i))
		gs._draw(owner, 1)
		return

static func take_random(gs, pool: Array):
	return pool.pop_at(int(gs.next_random() % pool.size()))

static func grant_to_deck(gs, owner: int, each: bool) -> void:
	var pool: Array = gs.player(owner).deck.duplicate()
	var chosen: Array = []
	var units: Array = []
	while not pool.is_empty() and (each or chosen.size() < 4):
		var inst: Dictionary = take_random(gs, pool)
		var role: String = Content.card_def(inst.definitionId).get("unitId", "")
		if role.is_empty() or gs._source_index(owner, Content.card_def(inst.definitionId)) < 0 or each and units.has(role): continue
		units.append(role)
		new_effect(inst, SUNNY_GIFTS[1 if each else 0])
		chosen.append(inst)
	if not chosen.is_empty(): draw_chosen(gs, owner, str(take_random(gs, chosen).instanceId))

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	match str(card.id):
		"c63403": gs.player(owner).units[src].swift = true
		"c63602", "c63605": smoke_form(gs, owner, src, str(card.id))
		"c63708":
			var before: int = gs.player(owner).units[src].get("charge", 0)
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 10)
			gs._heal_avatar(owner, before)

static func smoke_form(gs, owner: int, src: int, id: String) -> void:
	var charge: int = gs.player(owner).units[src].get("charge", 0)
	if charge < 3: gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 3 - charge)
	elif id == "c63602": gs.VerifiedRules.Divination.start(gs, owner, 1)
	else: aoe(gs, owner, src)

static func turn_start(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var id: String = u.get("formRules", {}).get("giftEnergyForm", "")
	if active(u) and id == "c63403": u.swift = true
	if active(u) and id in ["c63602", "c63605"]:
		gs.resolution_stack.append({"kind": "gift-smoke-form", "playerIndex": owner, "sourceIndex": src, "formId": id})

static func aoe(gs, owner: int, src: int) -> void:
	var targets: Array = gs.player(1 - owner).units
	for i in targets.size():
		if int(targets[i].hp) > 0: gs._damage_unit(1 - owner, i, 1, owner, src)
	gs._damage_avatar(1 - owner, 1, owner, src)

static func attack(gs, owner: int, src: int, options := {}) -> void:
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0 or gs.VerifiedRules.Stun.blocks(gs, owner, u): return
	gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, options)

static func chosen_attack(gs, owner: int, target, power: int, immune: bool) -> void:
	var src: int = gs._unit_index_by_uid(owner, target)
	if src < 0: return
	gs.VerifiedRules.HairPower.give(gs, owner, src, power)
	attack(gs, owner, src, {"immuneCombat": immune and gs.VerifiedRules.SunSmoke.has_charge(gs.player(owner).units[src])})

static func hurt(gs, owner: int, src: int, target, amount: int) -> void:
	for side in 2:
		if str(target) == "avatar-%d" % side:
			gs._damage_avatar(side, amount, owner, src)
			return
		var idx: int = gs._unit_index_by_uid(side, target)
		if idx >= 0:
			gs._damage_unit(side, idx, amount, owner, src)
			return

static func recall(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var pool: Array = p.get("giftHistory", []).duplicate(true)
	for i in mini(2, pool.size()):
		if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)): break
		var entry: Dictionary = take_random(gs, pool)
		entry.instanceId = fresh_instance(gs, owner, str(entry.definitionId)).instanceId
		entry.giftFreeTurn = gs.turn_counter
		p.hand.append(entry)

static func cast_copy(gs, owner: int, src: int, id: String) -> void:
	var card := Content.card_def(id).duplicate(true)
	card.unitId = gs.player(owner).units[src].id
	gs._push_card_frames(owner, id, null, card, src, 0, true)

static func summon_snake(gs, owner: int, src: int) -> void:
	var p: Dictionary = gs.player(owner)
	var old: Array = p.units.map(func(u): return int(u.front))
	if gs.VerifiedRules.Bingyong.replacement_blocked(gs, owner, {}): return
	gs.VerifiedRules.Xuenv.clear_wall(gs, owner)
	for u in p.units: u.front = 0
	var uid: String = "%s:hiss-%d" % [p.id, gs.next_card_id]
	gs.next_card_id += 1
	var unit := {"uid":uid, "id":"gift-hiss", "name":"嘶嘶", "title":"泷的召唤物", "art":"assets/official/cards/gift-hiss.png", "color":"#70b0e0",
		"baseAttack":2,"baseMaxHp":2,"attack":2,"maxHp":2,"hp":2,"shield":0,"shieldExpires":0,"knockout":0,
		"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,
		"awakened":false,"form":{},"formRules":{},"formAbility":"免疫非战斗伤害。","charge":0,"passive_hooks":[],
		"summoned":true,"summon":true,"countsAsShikigami":true,"giftHiss":true,"swift":false,"summonerUid":p.units[src].uid}
	p.units.append(unit)
	for i in old.size(): gs.VerifiedRules.Movement.moved(gs, owner, i, int(old[i]))
	gs.VerifiedRules.event(gs, "summon-created", {"player":owner, "uid":uid, "sourceUid":p.units[src].uid, "summonKind":"gift-hiss"})
	gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-entered-front", uid, {"kind":"response-complete"})

static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("giftHiss", false) and not u.get("removed", false) and (int(u.front) == 0 or int(u.hp) <= 0):
				u.hp = 0
				u.knockout = 0
				u.front = 0
				u.removed = true
				gs.VerifiedRules.event(gs, "summon-removed", {"player":owner, "uid":u.uid})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("gift-energy-"): return false
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	match action.trim_prefix("gift-energy-"):
		"effect": apply_gift(gs, owner, src, str(effect.value), target_id)
		"63401", "63404", "63405", "63407":
			var cfg: Dictionary = card.combatOption.duplicate(true)
			cfg.combatCard = card.duplicate(true)
			gs._grant_unit_armor(u, int(cfg.shield))
			if card.id == "c63405": gs._awaken(owner, src, card, {"attack":0, "hp":0})
			if card.id == "c63407" and card.get("usedFromHand", false) and not card.get("giftWaveFollow", false):
				gs.resolution_stack.append({"kind":"gift-wave-follow", "playerIndex":owner, "sourceIndex":src})
			gs._resolve_combat(owner, src, int(card.value), false, false, false, false, null, false, cfg)
		"63402":
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 1)
			gs.resolution_stack.append({"kind":"gift-draw", "playerIndex":owner, "goldenRain":true})
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		"63403", "63408", "63602", "63605", "63703", "63708": gs._apply_form(owner, src, card, effect.value)
		"63406":
			gs._deploy_realm(owner, card)
			chosen_attack(gs, owner, target_id, 0, false)
		"63601": hurt(gs, owner, src, target_id, 6 if int(target.get("frozen", 0)) > 0 else 3)
		"63603": chosen_attack(gs, owner, target_id, 1, true)
		"63604": gs._awaken(owner, src, card, {"attack":1, "hp":1})
		"63606": recall(gs, owner)
		"63607":
			gs._deploy_realm(owner, card)
			if u.form.is_empty(): cast_copy(gs, owner, src, "c16402")
		"63608": waterfall(gs, owner, src, int(card.get("giftRepeatCost", 2)), 3, card.get("playedInstance", {}))
		"63701", "63705":
			var each: bool = card.id == "c63705"
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 3 if each else 1)
			grant_to_deck(gs, owner, each)
		"63702":
			hurt(gs, owner, src, target_id, 3)
			if not target.is_empty():
				target.charge = maxi(0, int(target.get("charge", 0)) - 2)
				gs._recalc(target)
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 2)
		"63704":
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 2)
			gs._awaken(owner, src, card, {"attack":1, "hp":1})
		"63706":
			gs._deploy_realm(owner, card)
			gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 3)
			var selected: String = target.get("id", "")
			var pool: Array = p.deck.filter(func(inst): return selected in Content.card_unit_ids(Content.card_def(inst.definitionId)))
			if not pool.is_empty(): draw_chosen(gs, owner, str(take_random(gs, pool).instanceId))
		"63707":
			gs.resolution_stack.append({"kind":"gift-quick-prepare", "playerIndex":owner})
			gs.VerifiedRules.Divination.start(gs, owner, 2)
	return true

static func apply_gift(gs, owner: int, src: int, key: String, target) -> void:
	if gs.VerifiedRules.ForestSpirit.gift(gs, owner, src, key, target): return
	var p: Dictionary = gs.player(owner)
	match key:
		"snake": summon_snake(gs, owner, src)
		"hurt": hurt(gs, owner, src, target, 2)
		"prince":
			var form := Content.card_def("c63403")
			gs._apply_form(owner, src, form, form.value)
		"attack": attack(gs, owner, src)
		"wave":
			gs.resolution_stack.append({"kind":"gift-wave-shuffle", "playerIndex":owner})
			attack(gs, owner, src)
		"swift": grant_swift(gs, owner, src, false)
		"stun":
			var idx: int = gs._unit_index_by_uid(1 - owner, target)
			if idx >= 0: gs.VerifiedRules.Stun.apply(gs, 1 - owner, idx, 1, owner)
		"clone": gs.VerifiedRules.SunSmoke.summon(gs, owner, src)
		"charge": gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 4)
		"aoe": aoe(gs, owner, src)
		"discard":
			gs.resolution_stack.append({"kind":"gift-request-discard","playerIndex":owner})
			gs._draw(owner, 1)
		"heal": gs._heal_avatar(owner, 5)
		"divine":
			gs.resolution_stack.append({"kind":"gift-draw","playerIndex":owner})
			gs.VerifiedRules.Divination.start(gs, owner, 1)
		"random":
			var foes := living(gs, 1 - owner)
			if not foes.is_empty(): gs._damage_unit(1 - owner, int(take_random(gs, foes)), 4, owner, src)
		"fragile":
			gs.VerifiedRules.ArmorBreak.give(gs, owner, src, 1 - owner, -1, 4)
		"projectile": gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, 2, "日和坊·晴阳赐能")
		"power-attack": chosen_attack(gs, owner, p.units[src].uid, 2, false)
		"revive":
			if int(p.units[src].hp) <= 0 and gs.VerifiedRules.Rebirth.can_revive(p.units[src]):
				gs._resolve_action(owner, src, {}, {"action":"revive", "target":"source", "value":0}, null, {})
		"fire": gs._set_fire(owner, int(p.energy) + 1)

static func fresh_instance(gs, owner: int, id: String) -> Dictionary:
	var inst := {"instanceId": "%s-gift-%d" % [gs.player(owner).id, gs.next_card_id], "definitionId": id}
	gs.next_card_id += 1
	return inst

static func living(gs, owner: int) -> Array:
	var result: Array = []
	var units: Array = gs.player(owner).units
	for i in units.size():
		if int(units[i].hp) > 0 and not units[i].get("removed", false): result.append(i)
	return result

static func return_instance(gs, owner: int, inst: Dictionary) -> void:
	var hand: Array = gs.player(owner).hand
	if hand.size() < int(gs.rules.get("maxHandSize", 12)):
		hand.append(inst)
		gs.VerifiedRules.Glutton.mark_hand(gs, owner)

static func waterfall(gs, owner: int, src: int, cost: int, remaining: int, inst: Dictionary) -> void:
	if remaining <= 0 or int(gs.player(owner).units[src].charge) < cost: return
	gs.pending_choice = {
		"type":"gift-waterfall","playerIndex":owner,"sourceIndex":src,"remaining":remaining,"cost":cost,"instance":inst,
		"instanceIds":["gift-waterfall-heal","gift-waterfall-divine","gift-waterfall-random","gift-waterfall-fragile"],
		"heading":"赐 能","title":"瀑上烟霞","hint":"消耗%d能量，选择一项效果。剩余%d次。" % [cost, remaining]
	}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner: return null
	if choice.get("type") == "gift-waterfall" and iid in choice.instanceIds:
		var card := Content.card_def(WATERFALL).duplicate(true)
		var key := iid.trim_prefix("gift-waterfall-")
		for gift in card.giftOptions:
			if gift.key == key:
				card.name = str(gift.text)
				card.text = "消耗%d能量。" % int(choice.cost)
				card.choiceExplanation = card.text
				return card
	if choice.get("type") == "gift-discard":
		for inst in gs.player(owner).hand:
			if inst.instanceId == iid: return gs.describe_card_instance(owner, inst)
	return null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or iid not in choice.get("instanceIds", []): return false
	match choice.type:
		"gift-waterfall":
			var src := int(choice.sourceIndex)
			var cost := int(choice.cost)
			if int(gs.player(owner).units[src].charge) < cost: return false
			spend(gs, owner, src, cost)
			var key := iid.trim_prefix("gift-waterfall-")
			var inst: Dictionary = choice.instance
			if not inst.has("giftUsedKeys"): inst.giftUsedKeys = []
			if key not in inst.giftUsedKeys: inst.giftUsedKeys.append(key)
			gs.pending_choice = {}
			gs.phase = "main"
			gs.resolution_stack.append({"kind":"gift-waterfall-next","playerIndex":owner,"sourceIndex":src,"remaining":int(choice.remaining)-1,"cost":1 if printed_used(inst)>=3 else 2,"instance":inst})
			apply_gift(gs, owner, src, key, null)
		"gift-discard":
			var hand: Array = gs.player(owner).hand
			var idx := hand.find_custom(func(inst): return inst.instanceId == iid)
			if idx < 0: return false
			gs.discard_hand_card(owner, idx)
			gs.pending_choice = {}
			gs.phase = "main"
		_: return false
	gs._record("resolve_divination_choice", {"instanceId":iid, "choice":choice.type}, owner)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner: return null
	match choice.type:
		"gift-waterfall":
			if int(gs.player(owner).avatarHp) <= 24: return "gift-waterfall-heal"
			if not living(gs, 1 - owner).is_empty(): return "gift-waterfall-random"
			return "gift-waterfall-fragile"
		"gift-discard":
			return str(choice.instanceIds.back())
	return null

static func quick_draw(gs, owner: int, remaining: int, drawn: Array) -> void:
	if remaining > 0:
		gs.resolution_stack.append({"kind": "gift-quick-draw", "playerIndex": owner, "count": remaining-1, "drawn": drawn})
		gs._draw(owner, 1, -1, {"giftDrawn": drawn})
		return
	for i in range(drawn.size()-1, -1, -1):
		var inst: Dictionary = drawn[i]
		var gifts := granted(inst)
		gifts.reverse()
		for gift in gifts:
			gs.resolution_stack.append({"kind": "gift-quick-use", "playerIndex": owner, "instance": inst, "giftKey": effect_key(gift)})

static func automatic_gift(gs, owner: int, inst: Dictionary, key: String) -> void:
	var hand: Array = gs.player(owner).hand
	var from_hand := inst in hand
	if not from_hand and inst not in gs.VerifiedRules.Insight.zone(gs, owner): return
	var slot := options(inst).find_custom(func(option): return effect_key(option) == key)
	if slot < 0: return
	var base: Dictionary = gs.describe_card_instance(owner, inst, from_hand)
	var card := as_gift(gs, owner, inst, base, "gift:%d" % slot)
	if card.is_empty(): return
	var src: int = gs._source_index(owner, card)
	var u: Dictionary = gs.player(owner).units[src]
	if card.giftKey == "revive":
		if not gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u): return
	elif int(u.hp) <= 0: return
	if int(u.level) < int(card.level) or gs.VerifiedRules.Stun.blocks(gs, owner, u, card) or u.get("baseRulesSuppressed", false): return
	remember(gs, owner, inst, true)
	if from_hand: hand.erase(inst)
	else:
		gs.VerifiedRules.Insight.remove(gs, owner, inst)
		card.sourceZone = "insight"
	consume_effect(inst, str(card.giftInstanceKey))
	gs.resolution_stack.append({"kind": "gift-return", "playerIndex": owner, "instance": inst})
	card.usedFromHand = from_hand
	card.playedInstance = inst
	gs.player(owner).cardsPlayedThisTurn += 1
	gs._push_card_frames(owner, str(inst.definitionId), null, card, src, 0, true)

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("gift-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	var p: Dictionary = gs.player(owner)
	match kind:
		"gift-return": return_instance(gs, owner, frame.instance)
		"gift-draw":
			var spent: bool = not p.deck.is_empty() and (p.deck.back().get("giftSpent", false) or not p.deck.back().get("giftUsedKeys", []).is_empty())
			if spent and frame.get("goldenRain", false): gs.resolution_stack.append({"kind":"gift-fire","playerIndex":owner})
			gs._draw(owner, 1)
		"gift-fire": gs._set_fire(owner, int(p.energy) + 1)
		"gift-projection": gs.VerifiedRules.base_damage_projectile(gs, owner, src, int(frame.amount))
		"gift-wave-shuffle":
			p.deck.append(fresh_instance(gs, owner, "c63407"))
			gs._shuffle(p.deck)
			p.giftWaveGrowth = int(p.get("giftWaveGrowth", 0)) + 1
		"gift-wave-follow":
			if int(p.units[src].hp) <= 0: return true
			for i in p.hand.size():
				if p.hand[i].definitionId != "c63407": continue
				var inst: Dictionary = p.hand.pop_at(i)
				remember(gs, owner, inst)
				var card: Dictionary = gs.describe_card_instance(owner, inst)
				card.giftWaveFollow = true
				card.usedFromHand = true
				gs._push_card_frames(owner, "c63407", null, card, src, 0, true)
				break
		"gift-clone-attack":
			gs.resolution_stack.append({"kind":"gift-clone-strike","playerIndex":owner,"sourceIndex":p.units.size()})
			gs.VerifiedRules.SunSmoke.summon(gs, owner, src)
		"gift-clone-strike":
			if src < p.units.size() and p.units[src].get("smokeClone", false): attack(gs, owner, src)
		"gift-smoke-form":
			if active(p.units[src]) and p.units[src].get("formRules", {}).get("giftEnergyForm") == frame.formId: smoke_form(gs, owner, src, str(frame.formId))
		"gift-request-discard":
			var ids: Array = p.hand.map(func(inst): return str(inst.instanceId))
			if not ids.is_empty():
				gs.pending_choice = {"type":"gift-discard","playerIndex":owner,"instanceIds":ids,"heading":"弃 牌","title":"命途灯烟","hint":"选择一张手牌弃置。"}
				gs.phase = "choice"
		"gift-waterfall-next": waterfall(gs, owner, src, int(frame.cost), int(frame.remaining), frame.instance)
		"gift-quick-prepare":
			for i in range(p.deck.size() - 1, maxi(-1, p.deck.size() - 5), -1):
				var inst: Dictionary = p.deck[i]
				var base := Content.card_def(inst.definitionId)
				if gs._source_index(owner, base) >= 0:
					new_effect(inst, SUNNY_GIFTS[int(gs.next_random() % SUNNY_GIFTS.size())])
			quick_draw(gs, owner, 2, [])
		"gift-quick-draw": quick_draw(gs, owner, int(frame.count), frame.drawn)
		"gift-quick-use": automatic_gift(gs, owner, frame.instance, str(frame.giftKey))
		"gift-sunny-blast":
			if int(frame.amount) <= 0: return true
			var foes := living(gs, 1 - owner)
			foes.append(-1)
			var next := frame.duplicate()
			next.amount = int(frame.amount) - 1
			gs.resolution_stack.append(next)
			var selected := int(take_random(gs, foes))
			if selected < 0: gs._damage_avatar(1 - owner, 1, owner, src)
			else: gs._damage_unit(1 - owner, selected, 1, owner, src)
	return true
