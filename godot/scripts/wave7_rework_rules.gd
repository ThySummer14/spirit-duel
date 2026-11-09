extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const BLADES := ["c28902", "c28903", "c28904", "c28905"]
const BLADE_NAMES := ["妖刀·噬", "妖刀·御", "妖刀·疾", "妖刀·隐"]
const BLADE_BODIES := [Vector2i(2, 4), Vector2i(3, 3), Vector2i(3, 7), Vector2i(3, 4)]
const HAND := "wave7-eroding-hand"
const HAND_CARD := "guishizhishou"
const LAMP_FIRE := "wave7-lamp-fire-token"
const STORY := ["见闻·一", "见闻·二", "见闻·三"]
const STORY_TEXT := ["对所有敌方角色造成1点伤害。", "投射：造成4点伤害。", "为你的牌手恢复5点生命。"]

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("wave7Rework", ""))

static func source(gs, owner: int, key: String) -> int:
	return gs.player(owner).units.find_custom(func(u): return role(u) == key)

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func units(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not u.get("removed", false))

static func realms(gs, owner: int, key: String) -> Array:
	return gs.player(owner).realms.filter(func(r): return r.get("nativeRealm") == key and int(r.hp) > 0)

static func queue(gs, key: String, owner: int, data: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": "w7-" + key, "playerIndex": owner}.merged(data))

static func give(gs, owner: int, id: String) -> void:
	gs.VerifiedRules.Baize.put_hand(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, id))

static func random_item(gs, pool: Array):
	return pool[int(gs.next_random() % pool.size())]

static func take_deck(gs, owner: int, inst: Dictionary) -> void:
	if inst.is_empty() or inst not in gs.player(owner).deck: return
	gs.player(owner).deck.erase(inst)
	gs.VerifiedRules.Baize.put_hand(gs, owner, inst)

static func grow(gs, unit: Dictionary, atk: int, hp: int, permanent: bool = false) -> void:
	if permanent:
		gs.VerifiedRules.Glutton.record_permanent(unit, atk, hp)
		gs.VerifiedRules.SunSmoke.remember_permanent(unit, atk, hp)
	gs._grow_unit(unit, atk, hp)

static func origin(gs, owner: int, unit: Dictionary, id: String) -> Dictionary:
	var card := Content.card_def(id).duplicate(true)
	if card.is_empty(): return card
	card.unitId = unit.id
	card.w7Origin = true
	card.w7ReworkOrigin = true
	if id == "c10108":
		card.value = int(card.get("baseCombatAttack", 0)) + 2 * int(unit.get("waveBladeKills", 0))
		card.effects[0].value = card.value
	if card.get("demonPull", false): card.target = "enemy-reserve-unit" if gs.front_index(1-owner) < 0 else "auto"
	if id == "c12109": card.allowKnockedSource = false
	if int(unit.get("waveIbarakiGhost", -1)) >= 0: card.allowKnockedSource = true
	return card

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	var key := str(card.get("wave7Rework", ""))
	var src := source(gs, owner, key) if not key.is_empty() else -1
	if src < 0:
		if not inst.get("waveInstant", false) and int(inst.get("waveInstantTurn", -1)) != gs.turn_counter: return card
		var boosted := card.duplicate(true)
		if not gs._kw(boosted, "instant"): boosted.keywords.append("instant")
		return boosted
	var u: Dictionary = gs.player(owner).units[src]
	var out := card.duplicate(true)
	var origin_id := str(out.get("originId", ""))
	if u.get("formRules", {}).get("w7LampOrigin", false) and active(u): origin_id = "mingdeng"
	if not origin_id.is_empty(): out.originCard = origin(gs, owner, u, origin_id)
	if out.id in BLADES: out.w7Reawaken = true
	var instance_instant: bool = inst.get("waveInstant", false) or int(inst.get("waveInstantTurn", -1)) == gs.turn_counter
	var dog_instant: bool = u.get("formRules", {}).get("w7DogInstant", false)
	if (instance_instant or (out.type == "combat" and dog_instant)) and not gs._kw(out, "instant"):
		out.keywords.append("instant")
	if out.has("originCard") and (instance_instant or (out.originCard.type == "combat" and dog_instant)) and not gs._kw(out.originCard, "instant"):
		out.originCard.keywords.append("instant")
	if key == "shuten" and int(u.get("waveOneTurn", -1)) == gs.turn_counter:
		if out.id == "c60201":
			out.value = 3
			out.effects[0].value = 3
		if out.id == "c60205": out.combatOption.immuneCombat = true
	if out.id == "c60208" and int(u.level) < int(out.level):
		out.level = 1
		out.target = "enemy-unit"
		out.w7Trick = true
		out.currentCardStats = "戏法 · 仅对自身和一个敌方式神结算"
	if out.id == "c60708" and int(u.level) < int(out.level):
		out.level = 1
		out.w7Trick = true
		out.currentCardStats = "戏法 · 复活茨木童子·旅立"
	if out.id == "c60701" and hand(gs, owner).is_empty(): out.target = "auto"
	if out.id == "c60706" and not hand(gs, owner).is_empty(): out.keywords.append("instant")
	if out.id == "c29905":
		out.value = int(u.get("waveOverheal", 0)) if int(u.get("waveOverhealTurn", -1)) == gs.turn_counter else 0
		out.effects[0].value = out.value
	return out

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	var src: int = gs._source_index(owner, card)
	if src < 0: return true
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.get("waveIbarakiGhost", -1)) >= 0: return card.get("w7Origin", false)
	if card.get("id") == "c28906": return int(u.get("waveBladeBody", -1)) < 0
	if card.get("id") == "c60708" and not card.get("w7Trick", false): return not u.get("waveGhostEnabled", false)
	return true

static func targets(gs, owner: int, card: Dictionary):
	if not card.has("wave7Rework"): return null
	match str(card.get("id", "")):
		"c29101":
			return (units(gs, owner) + units(gs, 1-owner).filter(func(u): return not gs.VerifiedRules.Combat.has(u, "veil"))).map(func(u): return str(u.uid))
		"c60208":
			if card.get("w7Trick", false): return units(gs, 1-owner).map(func(u): return str(u.uid))
		"c29908":
			return units(gs, owner).map(func(u): return str(u.uid))
	match str(card.get("target", "")):
		"other-ally-unit":
			return units(gs, owner).filter(func(u): return u.id != card.unitId).map(func(u): return str(u.uid))
		"enemy-reserve-unit":
			if card.get("id") != "c60701": return null
			return units(gs, 1-owner).filter(func(u): return int(u.front) == 0 and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	return null

static func upgraded(gs, owner: int, src: int) -> void:
	var idx := source(gs, owner, "dog")
	if idx < 0: return
	var dog: Dictionary = gs.player(owner).units[idx]
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(dog) or not active(unit) or int(dog.get("waveUpgradeTurn", -1)) == gs.turn_counter: return
	dog.waveUpgradeTurn = gs.turn_counter
	temporary_power(gs, unit, 1)

static func temporary_power(gs, u: Dictionary, value: int) -> void:
	u.waveTemporaryPower = int(u.get("waveTemporaryPower", 0)) + value
	gs._recalc(u)

static func extra_power(u: Dictionary) -> int:
	return int(u.get("waveTemporaryPower", 0)) + (3 if u.get("formRules", {}).get("w7MonkFullPower", false) and int(u.hp) == int(u.maxHp) else 0)

static func expire(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if not u.has("waveTemporaryPower") and not u.has("waveZeroTurn"): continue
			u.erase("waveTemporaryPower")
			u.erase("waveZeroTurn")
			gs._recalc(u)

static func spirit_health(gs, owner: int, u: Dictionary, before: int) -> void:
	if int(u.hp) != 1 or before == 1 or not active(u) or role(u) != "shuten": return
	if int(u.get("waveOneTurn", -1)) == gs.turn_counter: return
	u.waveOneTurn = gs.turn_counter
	grow(gs, u, 1, 0, true)
	if u.awakened: gs._heal_unit(u, int(u.maxHp) - int(u.hp))

static func minimum_hp(gs, owner: int) -> int:
	var expiry := int(gs.player(owner).get("waveHealthFloorUntil", -1))
	return 1 if expiry > gs.turn_counter else 0

static func damage_received(gs, owner: int, idx: int, dealt: int, prior: int) -> void:
	if dealt <= 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	var src := source(gs, owner, "monk")
	if src < 0: return
	var monk: Dictionary = gs.player(owner).units[src]
	if int(monk.level) < 1 or monk.get("baseRulesSuppressed", false) or (int(monk.hp) <= 0 and idx != src): return
	if monk.awakened and gs.VerifiedRules.OwlInsect.shikigami(u):
		if int(monk.get("waveMonkDamageTurn", -1)) == gs.turn_counter: return
		monk.waveMonkDamageTurn = gs.turn_counter
		gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, dealt)
	elif idx == src and prior > 0: gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 1)

static func overheal(gs, owner: int, idx: int, amount: int) -> void:
	if amount <= 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	if role(u) != "monk" or not active(u): return
	if int(u.get("waveOverhealTurn", -1)) != gs.turn_counter: u.waveOverheal = 0
	u.waveOverhealTurn = gs.turn_counter
	u.waveOverheal = int(u.waveOverheal) + amount

static func before_knockout(gs, victim: int, u: Dictionary, prior: int) -> Dictionary:
	if victim < 0: return {}
	if not u.has("waveTemporaryPower") and role(u).is_empty() and (prior != 1 or realms(gs, victim, "w7-peak").is_empty()): return {}
	return {"prior": prior, "bloom": bool(u.get("formRules", {}).get("w7BladeBloom", false)), "blade": int(u.get("waveBladeBody", -1))}

static func after_knockout(gs, owner: int, idx: int, info: Dictionary) -> void:
	if idx < 0 or info.is_empty(): return
	var u: Dictionary = gs.player(owner).units[idx]
	u.erase("waveTemporaryPower")
	if role(u) == "lamp": u.erase("waveLampKinds")
	if role(u) == "blade":
		if int(info.blade) >= 0: blade_base(gs, u)
		if info.bloom and int(u.get("waveBladeAwake", -1)) >= 0:
			queue(gs, "blade-request", owner, {"sourceIndex": idx, "mode": int(u.waveBladeAwake), "revive": true, "bloom": true})
	if role(u) == "ibaraki" and u.get("waveGhostEnabled", false):
		set_ibaraki_ghost(gs, owner, idx)
	if int(info.prior) != 1 or u.get("summoned", false): return
	for realm in realms(gs, owner, "w7-peak"):
		queue(gs, "peak-revive", owner, {"sourceIndex": idx, "realmUid": realm.uid})

static func revived(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.get("waveIbarakiGhost", -1)) < 0: return
	u.erase("waveIbarakiGhost")
	u.name = Content.unit_def(u.id).name
	u.erase("waveIbarakiAttack")

static func blade_base(gs, u: Dictionary) -> void:
	u.erase("waveBladeBody")
	u.baseAttack = 3
	u.baseMaxHp = 4
	u.name = Content.unit_def(u.id).name
	u.erase("waveBladePierce")
	u.attackBonus -= int(u.get("waveBladeApplied", 0))
	u.erase("waveBladeApplied")
	var bonus := int(u.get("waveBladeBloomGrowth", 0)) + int(u.get("waveBladeBiteGrowth", 0))
	u.waveBladeApplied = bonus
	u.attackBonus += bonus
	gs._recalc(u)

static func blade_choice(gs, owner: int, src: int, bloom: bool, revive: bool) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var ids := []
	for i in BLADES.size():
		if i != int(u.get("waveBladeBody", -1)): ids.append("w7-blade-%d" % i)
	if not ids.is_empty():
		choice(gs, owner, "blade", ids, "无尽刃狱 · 选择妖刀", {"sourceIndex": src, "bloom": bloom, "revive": revive})

static func blade_change(gs, owner: int, src: int, mode: int, bloom: bool = false, revive: bool = false, cast: bool = false) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if mode < 0 or mode == int(u.get("waveBladeBody", -1)): return
	if int(u.hp) <= 0 and not revive: return
	if not u.get("form", {}).is_empty(): gs.VerifiedRules.Forms.remove(gs, owner, src, "切换为妖刀")
	if revive and not gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false): return
	if bloom:
		u.waveBladeBloomGrowth = int(u.get("waveBladeBloomGrowth", 0)) + 1
	if mode == 0: u.waveBladeBiteGrowth = int(u.get("waveBladeBiteGrowth", 0)) + 1
	u.attackBonus -= int(u.get("waveBladeApplied", 0))
	var bonus := int(u.get("waveBladeBloomGrowth", 0)) + (int(u.get("waveBladeBiteGrowth", 0)) if mode == 0 else 0)
	u.waveBladeApplied = bonus
	u.attackBonus += bonus
	u.waveBladeBody = mode
	u.baseAttack = BLADE_BODIES[mode].x
	u.baseMaxHp = BLADE_BODIES[mode].y
	u.name = BLADE_NAMES[mode]
	u.waveBladePierce = mode == 2
	gs._recalc(u)
	u.hp = int(u.maxHp)
	if mode == 1: u.barrier = true
	if cast:
		queue(gs, "cast-origin", owner, {"sourceIndex": src, "origin": Content.card_def(BLADES[mode]).originId})
	if mode == 3 and not units(gs, 1-owner).is_empty():
		var target: Dictionary = random_item(gs, units(gs, 1-owner))
		queue(gs, "ability-hit", owner, {"sourceIndex": src, "targetId": target.uid, "amount": int(u.attack)})
	gs.VerifiedRules.event(gs, "w7-blade-switch", {"player": owner, "uid": u.uid, "blade": mode})

static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int) -> void:
	if owner < 0 or src < 0 or victim == owner or amount <= 0 or owner != gs.current_player: return
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) != "blade" or not active(u): return
	if not u.awakened and int(u.get("waveBladeDrawTurn", -1)) != gs.turn_counter:
		u.waveBladeDrawTurn = gs.turn_counter
		queue(gs, "blade-draw", owner)
	var mode := int(u.get("waveBladeAwake", -1))
	if mode >= 0 and mode != int(u.get("waveBladeBody", -1)):
		queue(gs, "blade-request", owner, {"sourceIndex": src, "mode": mode, "bloom": bool(u.get("formRules", {}).get("w7BladeBloom", false))})

static func battle_bonus(gs, owner: int, src: int) -> int:
	var dog := source(gs, owner, "dog")
	var bonus := 0
	if dog < 0 or dog == src: return 0
	for realm in realms(gs, owner, "w7-dojo"):
		if int(realm.get("waveDojoTurn", -1)) == gs.turn_counter: continue
		realm.waveDojoTurn = gs.turn_counter
		bonus += int(gs.player(owner).units[dog].level)
	return bonus

static func redirect(gs, victim: int, idx: int) -> int:
	var dog := source(gs, victim, "dog")
	if dog < 0 or idx < 0 or dog == idx or gs.current_player == victim: return idx
	var u: Dictionary = gs.player(victim).units[dog]
	if not active(u) or not u.get("formRules", {}).get("w7Guard", false) or int(u.get("waveGuardTurn", -1)) == gs.turn_counter: return idx
	if not gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]): return idx
	if gs.VerifiedRules.Bingyong.replacement_blocked(gs, victim, u): return idx
	u.waveGuardTurn = gs.turn_counter
	gs._grant_unit_armor(u, 2)
	if int(gs.player(victim).units[idx].front) == 1: gs.VerifiedRules.move_unit(gs, victim, u)
	gs.VerifiedRules.event(gs, "w7-guard", {"player": victim, "uid": u.uid, "protected": gs.player(victim).units[idx].uid})
	return dog

static func before_hit(gs, owner: int, src: int, victim: int, idx: int, options: Dictionary) -> void:
	if idx < 0: return
	var target: Dictionary = gs.player(victim).units[idx]
	if options.get("w7DogZero", false):
		target.waveZeroTurn = gs.turn_counter
		gs._recalc(target)
		gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
	if options.get("w7MonkLethal", false) and int(target.hp) == int(target.maxHp):
		options.lethal = true

static func finish(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if options.get("combatCard", {}).get("id") == "c29106" and kills > 0: lamp_fire(gs, owner)
	if role(u) != "ibaraki" or not active(u): return
	if not u.awakened and int(u.get("waveHandTurn", -1)) == gs.turn_counter: return
	u.waveHandTurn = gs.turn_counter
	queue(gs, "summon-hand", owner, {"sourceIndex": src, "double": u.awakened})

static func killed(gs, owner: int, src: int, victim: int, target: Dictionary) -> void:
	if owner < 0 or src < 0 or victim == owner or not gs.VerifiedRules.OwlInsect.shikigami(target): return
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "blade": u.waveBladeKills = int(u.get("waveBladeKills", 0)) + 1

static func card_kind(card: Dictionary) -> String:
	var kind := str(card.get("type", ""))
	if kind == "combat": return kind
	return "spell" if Content.is_spell(card) else "other"

static func lamp_announce(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var idx := source(gs, owner, "lamp")
	if idx < 0 or int(frame.sourceIndex) < 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u): return
	if (card.get("w7Origin", false) or card.has("yanmieOriginOf")) and u.get("formRules", {}).get("w7LampOrigin", false) and int(u.get("waveOriginTurn", -1)) != gs.turn_counter:
		u.waveOriginTurn = gs.turn_counter
		queue(gs, "draw", owner)
	if not frame.get("usedFromHand", false) or card.get("w7FirePaid", false): return
	if not u.has("waveLampKinds"): u.waveLampKinds = []
	var kind := card_kind(card)
	if kind not in u.waveLampKinds: u.waveLampKinds.append(kind)
	if u.waveLampKinds.size() >= 3:
		u.waveLampKinds.clear()
		queue(gs, "lamp-fire", owner)

static func lamp_fire(gs, owner: int) -> void:
	if not realms(gs, owner, "w7-lamp-fire").is_empty(): return
	var src := source(gs, owner, "lamp")
	if src < 0: return
	gs._deploy_realm(owner, Content.card_def(LAMP_FIRE))
	if gs.player(owner).units[src].awakened and active(gs.player(owner).units[src]):
		gs.VerifiedRules.base_damage_projectile(gs, owner, src, 3, "辉灯之火进场")

static func quote_lamp(gs, owner: int, card: Dictionary, payment: Dictionary) -> Dictionary:
	if int(gs.player(owner).energy) != 0 or int(payment.cost) != 1: return payment
	if not card.get("w7PayFromHand", false) or realms(gs, owner, "w7-lamp-fire").is_empty(): return payment
	payment.cost = 0
	payment.w7FirePaid = true
	return payment

static func pay_lamp(gs, owner: int, card: Dictionary, payment: Dictionary) -> void:
	if not payment.get("w7FirePaid", false): return
	var pool := realms(gs, owner, "w7-lamp-fire")
	if pool.is_empty(): return
	card.w7FirePaid = true
	gs.VerifiedRules.Huang.destroy(gs, owner, pool[0], "代替鬼火消耗")

static func choice(gs, owner: int, key: String, ids: Array, label: String, extra: Dictionary = {}) -> void:
	gs.pending_choice = {"type": "w7-" + key, "playerIndex": owner, "instanceIds": ids, "heading": label}.merged(extra)
	gs.phase = "choice"

static func choice_card(gs, owner: int, id: String):
	var c: Dictionary = gs.pending_choice
	if int(c.get("playerIndex", -1)) != owner or id not in c.get("instanceIds", []): return null
	if c.type == "w7-story":
		var i := int(id.trim_prefix("w7-story-"))
		return {"id": id, "name": STORY[i], "type": "spell", "text": STORY_TEXT[i]}
	if c.type == "w7-blade":
		var i := int(id.trim_prefix("w7-blade-"))
		return {"id": id, "name": BLADE_NAMES[i], "type": "form", "text": "切换为此妖刀并自动使用对应起源。"}
	return null

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if int(c.get("playerIndex", -1)) != owner or id not in c.get("instanceIds", []): return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": id, "choice": c.type}, owner)
	match str(c.type):
		"w7-story":
			var realm: Array = gs.player(owner).realms.filter(func(r): return r.uid == c.realmUid)
			if not realm.is_empty(): story_effect(gs, owner, realm[0], int(id.trim_prefix("w7-story-")))
		"w7-blade":
			blade_change(gs, owner, int(c.sourceIndex), int(id.trim_prefix("w7-blade-")), bool(c.bloom), bool(c.revive), true)
		"w7-deck", "w7-deck-focus":
			var p: Dictionary = gs.player(owner)
			var idx: int = p.deck.find_custom(func(inst): return inst.instanceId == id)
			if idx >= 0: take_deck(gs, owner, p.deck[idx])
			if c.type == "w7-deck-focus": focus_pick(gs, owner, c.pool, c.groups)
			else: gs._shuffle(p.deck)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func focus_pick(gs, owner: int, pool: Array, remaining: Array) -> void:
	var groups := remaining.duplicate()
	while not groups.is_empty():
		var group: String = groups.pop_front()
		var matches := pool.filter(func(inst): return card_kind(Content.card_def(inst.definitionId)) == group)
		if matches.size() > 1:
			choice(gs, owner, "deck-focus", matches.map(func(inst): return str(inst.instanceId)), "燃灯夜话 · 专注选择", {"pool": pool, "groups": groups})
			return
		if matches.size() == 1: take_deck(gs, owner, matches[0])
	gs._shuffle(gs.player(owner).deck)

static func story_effect(gs, owner: int, realm: Dictionary, i: int) -> void:
	realm.waveStoryUsed.append(i)
	var src := source(gs, owner, "lamp")
	match i:
		0:
			for u in gs.player(1-owner).units:
				if int(u.hp) > 0 and not u.get("removed", false): gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, u.uid), 1, owner, src)
			gs._damage_avatar(1-owner, 1, owner, src)
		1:
			var idx: int = gs.front_index(1-owner)
			if idx >= 0: gs._damage_unit(1-owner, idx, 4, owner, src)
			else: gs._damage_avatar(1-owner, 4, owner, src)
		2: gs._heal_avatar(owner, 5)
	if realm.waveStoryUsed.size() >= 3:
		gs.VerifiedRules.Huang.destroy(gs, owner, realm, "见闻完结")

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	match str(realm.get("nativeRealm", "")):
		"w7-lamp-story":
			if not realm.has("waveStoryUsed"): realm.waveStoryUsed = []
			var ids: Array = []
			for i in STORY.size():
				if i not in realm.waveStoryUsed: ids.append("w7-story-%d" % i)
			if not ids.is_empty(): choice(gs, owner, "story", ids, "叙话成书 · 选择见闻", {"realmUid": realm.uid})
		"w7-lamp-forever":
			lamp_fire(gs, owner)
			var dead: Array = gs.player(owner).units.filter(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u))
			if not dead.is_empty(): gs.VerifiedRules.Peach.revive(gs, owner, -1, random_item(gs, dead), false, false)
			queue(gs, "draw", owner)
		"w7-buddha-heart":
			var src := source(gs, owner, "monk")
			if not gs.player(owner).get("avatarToxicPoisoned", false) and int(gs.player(owner).avatarHp) + 2 > int(gs.player(owner).maxAvatarHp): gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 1)
			gs._heal_avatar(owner, 2)
			if src >= 0:
				var u: Dictionary = gs.player(owner).units[src]
				if int(u.hp) > 0:
					if not u.get("toxicPoisoned", false) and int(u.hp) + 2 > int(u.maxHp): gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 1)
					gs._heal_unit(u, 2)
		"w7-buddha-team":
			for u in units(gs, owner):
				var overflow: bool = not u.get("toxicPoisoned", false) and int(u.hp) + 2 > int(u.maxHp)
				gs._heal_unit(u, 2)
				if overflow:
					temporary_power(gs, u, 1)
					gs._grant_unit_armor(u, 1)
		_: return false
	return true

static func deploy(gs, owner: int, card: Dictionary) -> Dictionary:
	gs._deploy_realm(owner, card)
	return gs.player(owner).realms.back()

static func turn_start(gs, owner: int) -> void:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if int(u.get("waveBladeBody", -1)) in [1, 3] and active(u): blade_base(gs, u)
		if int(u.get("waveIbarakiGhost", -1)) >= 0 and int(u.knockout) > 0:
			ghost_cast(gs, owner, i)

static func end_turn(gs, owner: int) -> void:
	for realm in realms(gs, owner, "w7-lamp-story"):
		gs.player(owner).realms.erase(realm)
		gs.player(1-owner).realms.append(realm)
		gs.VerifiedRules.event(gs, "realm-control-transferred", {"player": 1-owner, "realm": realm.uid})
	var dog := source(gs, owner, "dog")
	if dog >= 0:
		var u: Dictionary = gs.player(owner).units[dog]
		if u.awakened:
			if int(u.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, owner, dog, u, false, false)
			grow(gs, u, 1, 1, true)
	var monk := source(gs, owner, "monk")
	if monk < 0 or not active(gs.player(owner).units[monk]) or not gs.player(owner).units[monk].awakened: return
	var hand_list: Array = gs.player(owner).hand
	var full: Array = hand_list.filter(func(inst): return inst.definitionId == "shengmingjinghua" and int(inst.get("efStacks", 1)) == 10)
	if full.size() < 3: return
	for i in range(3):
		gs.discard_hand_card(owner, hand_list.find(full[i]))
	gs._damage_avatar(1-owner, 30, owner, monk)

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "shuten": u.shutenFormUnyielding = card.get("formRules", {}).get("shutenUnyielding", false)
	if card.get("formRules", {}).get("w7BuddhaForm", false): gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 4)

static func form_left(gs, owner: int, _src: int, prior: Dictionary) -> void:
	if prior.get("w7BuddhaForm", false): gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 4)

static func hand(gs, owner: int) -> Dictionary:
	var u: Dictionary = gs.front_unit(owner)
	return u if u.get("id") == HAND else {}

static func refresh_ghost_power(gs, unit: Dictionary) -> void:
	if unit.get("id") != HAND: return
	for owner in 2:
		if gs._unit_index_by_uid(owner, unit.uid) < 0: continue
		var idx := source(gs, owner, "ibaraki")
		if idx < 0: return
		var ghost: Dictionary = gs.player(owner).units[idx]
		if ghost.has("waveIbarakiGhost"):
			ghost.waveIbarakiAttack = int(hand(gs, owner).get("attack", 0))
		return

static func summon_hand(gs, owner: int, src: int, doubled: bool = false) -> void:
	var previous := hand(gs, owner)
	var u: Dictionary = gs.player(owner).units[src]
	if doubled and previous.is_empty() and int(u.hp) > 0: grow(gs, u, maxi(0, int(u.attack)), 0)
	if not previous.is_empty():
		queue(gs, "spawn-hand", owner, {"sourceIndex": src})
		gs.VerifiedRules.NativeSummons.remove(gs, owner, previous)
		return
	spawn_hand(gs, owner, src)

static func spawn_hand(gs, owner: int, src: int) -> void:
	var card := Content.card_def(HAND_CARD)
	var stats: Dictionary = card.value
	var p: Dictionary = gs.player(owner)
	p.waveHandPower = int(p.get("waveHandPower", 0)) + int(stats.entryAttack)
	var attack := int(stats.attack) + int(p.waveHandPower)
	var hp := attack if not realms(gs, owner, "w7-hand-mountain").is_empty() else int(stats.hp)
	var fields := {"baseAttack": int(stats.attack), "permanentAttack": int(p.waveHandPower), "summonRulesText": card.text}
	gs.VerifiedRules.NativeSummons.summon(gs, owner, src, HAND, card.name, attack, hp, fields)

static func event(gs, kind: String, details: Dictionary) -> void:
	if kind not in ["summon-created", "summon-removed"]: return
	var owner := int(details.get("player", -1))
	if owner < 0 or owner >= gs.players.size(): return
	var unit: Dictionary = gs._unit_by_uid(gs.player(owner).units, details.uid)
	if details.get("summonKind") == HAND: refresh_ghost_power(gs, unit)
	if kind == "summon-removed":
		if details.get("summonKind") != HAND: return
		var idx := source(gs, owner, "ibaraki")
		if idx >= 0 and active(gs.player(owner).units[idx]): queue(gs, "ibaraki-return-front", owner, {"sourceIndex": idx})
		return
	var src := source(gs, owner, "ibaraki")
	if src < 0 or not gs.player(owner).units[src].get("formRules", {}).get("w7SummonSwift", false): return
	if not unit.is_empty(): unit.swift = true

static func ghost_cast(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.knockout) <= 0 or gs.winner >= 0: return
	u.waveIbarakiAttack = int(hand(gs, owner).get("attack", 0))
	queue(gs, "ghost-countdown", owner, {"sourceIndex": src})
	var cards: Array = gs.player(owner).hand.filter(func(inst):
		var c := Content.card_def(inst.definitionId)
		return c.get("unitId") == u.id and not str(c.get("originId", "")).is_empty()
	)
	if not cards.is_empty():
		var inst: Dictionary = random_item(gs, cards)
		var c := origin(gs, owner, u, Content.card_def(inst.definitionId).originId)
		var legal: Array = [null] if c.target == "auto" else gs.valid_targets(owner, c)
		if not legal.is_empty():
			gs.player(owner).hand.erase(inst)
			c.playedInstance = inst
			gs._push_card_frames(owner, str(inst.definitionId), random_item(gs, legal), c, src, 0, true)

static func set_ibaraki_ghost(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	u.waveIbarakiGhost = gs.turn_counter
	u.waveIbarakiAttack = int(hand(gs, owner).get("attack", 0))
	u.name = "茨木童子·鬼蚀"
	if owner == gs.current_player: queue(gs, "ghost-cast", owner, {"sourceIndex": src})

static func attack(gs, owner: int, idx: int, target = null, options: Dictionary = {}) -> void:
	if idx < 0: return
	gs.VerifiedRules.DragonAbyss.attack(gs, owner, idx, target, options)

static func combat_card(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target, extra: Dictionary = {}) -> void:
	var cfg := card.duplicate(true)
	cfg.combatOption.merge(extra, true)
	gs._resolve_action(owner, src, cfg, {"action": "assault", "value": effect.value}, target, {})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("w7-"): return false
	var u: Dictionary = gs.player(owner).units[src]
	var foe := 1-owner
	var p: Dictionary = gs.player(owner)
	match action:
		"w7-29201": combat_card(gs, owner, src, card, effect, target_id)
		"w7-29202":
			gs._install_form(owner, src, card, effect.value)
			if not target.is_empty() and int(target.hp) > 0: grow(gs, target, 1, 1)
		"w7-29203":
			deploy(gs, owner, card)
			gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
		"w7-29204": combat_card(gs, owner, src, card, effect, target_id, {"w7DogZero": true})
		"w7-29205": gs._install_form(owner, src, card, effect.value)
		"w7-29206":
			grow(gs, u, 1, 1, true)
			for ally in units(gs, owner):
				if ally != u: grow(gs, ally, 1, 1)
			combat_card(gs, owner, src, card, effect, target_id)
		"w7-29207":
			if not target.is_empty() and int(target.hp) > 0:
				grow(gs, target, 2, 2, true)
				attack(gs, owner, gs._unit_index_by_uid(owner, target.uid))
		"w7-29208":
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			gs._install_form(owner, src, card, effect.value)
			give(gs, owner, "c29201")
		"w7-28901":
			gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
			gs._damage_avatar(foe, 1, owner, src)
			if int(u.hp) > 0: combat_card(gs, owner, src, card, effect, target_id)
		"w7-28902", "w7-28903", "w7-28904", "w7-28905":
			u.waveBladeAwake = BLADES.find(card.id)
			if not u.awakened: gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			combat_card(gs, owner, src, card, effect, target_id)
		"w7-28906":
			gs._install_form(owner, src, card, effect.value)
			u.swift = true
		"w7-28907":
			var pool: Array = p.deck.filter(func(inst): return Content.card_def(inst.definitionId).get("awakeningCard", false))
			for i in mini(2, pool.size()):
				var inst: Dictionary = random_item(gs, pool)
				pool.erase(inst)
				inst.waveInstantTurn = gs.turn_counter
				take_deck(gs, owner, inst)
		"w7-28908":
			deploy(gs, owner, card)
			blade_choice(gs, owner, src, u.get("formRules", {}).get("w7BladeBloom", false), false)
		"w7-29101":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, target_id)
				if idx >= 0: gs._damage_unit(side, idx, 4 if card.get("focusPaid", false) else 2, owner, src)
		"w7-29102":
			var pool: Array = p.deck.slice(maxi(0, p.deck.size()-3))
			if card.get("focusPaid", false): focus_pick(gs, owner, pool, ["combat", "spell", "other"])
			elif not pool.is_empty():
				choice(gs, owner, "deck", pool.map(func(inst): return str(inst.instanceId)), "燃灯夜话 · 选择一张牌")
		"w7-29103", "w7-29107":
			trigger_realm(gs, owner, deploy(gs, owner, card))
		"w7-29104":
			queue(gs, "lamp-instant", owner)
			gs._draw(owner, 1)
		"w7-29105": gs._install_form(owner, src, card, effect.value)
		"w7-29106": combat_card(gs, owner, src, card, effect, target_id)
		"w7-29108": gs._awaken(owner, src, card, effect.value)
		"w7-lamp-token": lamp_fire(gs, owner)
		"w7-60201", "w7-60205": combat_card(gs, owner, src, card, effect, target_id)
		"w7-60202":
			deploy(gs, owner, card)
			gs._damage_unit(owner, src, maxi(0, int(u.hp) - 1), owner, src)
		"w7-60203":
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			u.unyielding = true
			combat_card(gs, owner, src, card, effect, target_id)
		"w7-60204":
			var dead := int(u.hp) <= 0
			if dead and not gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false): return true
			gs._install_form(owner, src, card, effect.value)
			if dead:
				var prior := int(u.hp)
				u.hp = 1
				gs.VerifiedRules.Izanami.changed(gs, owner, u, prior)
		"w7-60206": p.waveHealthFloorUntil = gs.turn_counter + 2
		"w7-60207": gs._install_form(owner, src, card, effect.value)
		"w7-60208":
			var targets_to_hit: Array = [target] if card.get("w7Trick", false) else units(gs, foe)
			for rival in targets_to_hit:
				if not rival.is_empty() and int(rival.hp) > 1: gs._damage_unit(foe, gs._unit_index_by_uid(foe, rival.uid), int(rival.hp)-1, owner, src)
			if int(u.hp) > 1: gs._damage_unit(owner, src, int(u.hp)-1, owner, src)
			combat_card(gs, owner, src, card, effect, null)
		"w7-60701":
			var claw := hand(gs, owner)
			if not claw.is_empty() and not target.is_empty():
				attack(gs, owner, gs._unit_index_by_uid(owner, claw.uid), target_id, {"reserveTarget": true, "lethal": true})
		"w7-60702":
			deploy(gs, owner, card)
			summon_hand(gs, owner, src)
		"w7-60703":
			var claw := hand(gs, owner)
			if not claw.is_empty():
				queue(gs, "cast-origin", owner, {"sourceIndex": src, "origin": card.originId})
				attack(gs, owner, gs._unit_index_by_uid(owner, claw.uid), null, {"immuneCombat": true})
		"w7-60704":
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			combat_card(gs, owner, src, card, effect, target_id)
		"w7-60705":
			gs._install_form(owner, src, card, effect.value)
			summon_hand(gs, owner, src)
		"w7-60706": combat_card(gs, owner, src, card, effect, target_id)
		"w7-60707":
			var claw := hand(gs, owner)
			if not claw.is_empty(): queue(gs, "random-packets", owner, {"sourceIndex": src, "remaining": 2 * int(claw.attack)})
		"w7-60708":
			if card.get("w7Trick", false): gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
			else:
				u.waveGhostEnabled = true
				set_ibaraki_ghost(gs, owner, src)
		"w7-29901": combat_card(gs, owner, src, card, effect, target_id, {"w7MonkLethal": true})
		"w7-29902", "w7-29906": trigger_realm(gs, owner, deploy(gs, owner, card))
		"w7-29903":
			gs.VerifiedRules.EssenceFeast.gain_essence(gs, owner, 2)
			gs._draw(owner, 1)
		"w7-29904": gs._apply_form(owner, src, card, effect.value)
		"w7-29905": combat_card(gs, owner, src, card, effect, target_id)
		"w7-29907": gs._apply_form(owner, src, card, effect.value)
		"w7-29908":
			gs._awaken(owner, src, card, effect.value)
			if not target.is_empty(): attack(gs, owner, gs._unit_index_by_uid(owner, target.uid))
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("w7-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	var p: Dictionary = gs.player(owner)
	match kind:
		"w7-blade-draw": gs._draw(owner, 1, -1, {"waveDrawUnit": "yaodaoji-zhuren"})
		"w7-blade-request":
			var u: Dictionary = p.units[src]
			if not realms(gs, owner, "w7-blade-hell").is_empty(): blade_choice(gs, owner, src, bool(frame.get("bloom", false)), bool(frame.get("revive", false)))
			else: blade_change(gs, owner, src, int(frame.mode), bool(frame.get("bloom", false)), bool(frame.get("revive", false)))
		"w7-cast-origin":
			var u: Dictionary = p.units[src]
			if active(u):
				var card := origin(gs, owner, u, str(frame.origin))
				var targets_to_use: Array = [null] if card.target == "auto" else gs.valid_targets(owner, card)
				if not targets_to_use.is_empty(): gs._push_card_frames(owner, str(card.id), random_item(gs, targets_to_use), card, src, 0, true)
		"w7-ability-hit":
			var idx: int = gs._unit_index_by_uid(1-owner, frame.targetId)
			if idx >= 0: gs.VerifiedRules.base_damage_unit(gs, owner, src, 1-owner, idx, int(frame.amount))
		"w7-lamp-fire": lamp_fire(gs, owner)
		"w7-draw": gs._draw(owner, 1)
		"w7-lamp-instant":
			for group in ["combat", "spell", "other"]:
				var matches: Array = p.hand.filter(func(inst): return card_kind(Content.card_def(inst.definitionId)) == group)
				if not matches.is_empty(): random_item(gs, matches).waveInstant = true
		"w7-peak-revive":
			if not gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, p.units[src]): return true
			var found: Array = p.realms.filter(func(realm): return realm.uid == frame.realmUid and int(realm.hp) > 0)
			if found.is_empty(): return true
			var realm: Dictionary = found[0]
			realm.hp = maxi(0, int(realm.hp) - 3)
			gs.VerifiedRules.event(gs, "realm-durability", {"player": owner, "realm": realm.uid, "amount": 3, "remaining": realm.hp})
			if int(realm.hp) <= 0: gs.VerifiedRules.Huang.destroy(gs, owner, realm, "千丈岳耐久耗尽")
			gs.VerifiedRules.Peach.revive(gs, owner, src, p.units[src], false, false)
		"w7-summon-hand": summon_hand(gs, owner, src, frame.get("double", false))
		"w7-spawn-hand": spawn_hand(gs, owner, src)
		"w7-ibaraki-return-front":
			if active(p.units[src]): gs.VerifiedRules.Movement.move_to(gs, owner, src, 1)
		"w7-ghost-cast": ghost_cast(gs, owner, src)
		"w7-ghost-countdown": gs.VerifiedRules.reduce_countdown(gs, owner, src, 1)
		"w7-random-packets":
			var pool := units(gs, 1-owner)
			if int(frame.remaining) > 0 and not pool.is_empty():
				var target: Dictionary = random_item(gs, pool)
				queue(gs, "random-packets", owner, {"sourceIndex": src, "remaining": int(frame.remaining)-1})
				gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, target.uid), 1, owner, src)
		_: return false
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("w7-"): return null
	var ids: Array = c.instanceIds
	var pick: String = str(ids[0])
	if c.type == "w7-story":
		if "w7-story-2" in ids and int(gs.player(owner).avatarHp) <= 22: pick = "w7-story-2"
		elif "w7-story-1" in ids and not gs.front_unit(1-owner).is_empty(): pick = "w7-story-1"
	elif c.type == "w7-blade" and "w7-blade-2" in ids: pick = "w7-blade-2"
	return resolve_choice(gs, owner, pick)

static func score(gs, owner: int, card: Dictionary, target):
	if not card.has("wave7Rework") and not card.get("w7ReworkOrigin", false): return null
	if card.id in ["c60703", "c60707"] and hand(gs, owner).is_empty(): return -20
	if card.id == "c60701" and target == null: return -20
	if card.id == "c29101" and gs._unit_index_by_uid(owner, target) >= 0: return -20
	return 60 + 3 * int(card.get("level", 0))
