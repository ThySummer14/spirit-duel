class_name SunSmokeRules
extends RefCounted
const ContentLoader := preload("res://scripts/content_loader.gd")
## Charge is owned by a unit; ghost fire is owned by a player.
static func role(unit: Dictionary) -> String:
	return "clone" if unit.get("smokeClone", false) else str(ContentLoader.runtime_unit_def(unit).get("sunSmokeRole", ""))

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) >= 1 and not unit.get("removed", false)

static func has_charge(unit: Dictionary) -> bool:
	var def: Dictionary = ContentLoader.runtime_unit_def(unit)
	return bool(unit.get("formRules",{}).get("rpCopiedCharge",false)) or bool(def.get("nativeCharge", false)) or bool(unit.get("formRules",{}).get("nativeCharge",false)) or role(unit) in ["sun", "smoke", "clone"] or unit.get("keywords", []).has("charge") or def.get("keywords", []).has("charge") or int(unit.get("charge", 0)) > 0

static func free_charge(gs, owner: int) -> bool:
	if int(gs.player(owner).get("sunFreeChargeTurn", -1)) == gs.turn_counter: return false
	return gs.player(owner).units.any(func(u): return active(u) and role(u) == "sun" and u.awakened)

static func quote_charge(gs, owner: int, idx: int, amount: int) -> Dictionary:
	var unit: Dictionary = gs.player(owner).units[idx]
	var free := amount > 0 and free_charge(gs, owner)
	var charge: int = 0 if free else mini(amount, int(unit.get("charge", 0)))
	var damage: int = 0 if free else maxi(0, amount - charge)
	var incoming: int = damage + int(unit.get("armorBreak", 0)) + (1 if int(unit.get("brittle", 0)) > 0 else 0)
	incoming = gs.VerifiedRules.Bingyong.limit_damage(unit, incoming)
	var health: int = 0 if unit.get("barrier", false) else maxi(0, incoming - int(unit.get("shield", 0)))
	var cap := int(unit.get("formRules", {}).get("damageCap", 0))
	if cap > 0: health = mini(health, cap)
	var ok: bool = amount >= 0 and (damage == 0 or (role(unit) == "sun" and int(unit.hp) > health))
	return {"ok": ok, "amount": amount, "charge": charge, "health": health, "damage": damage, "free": free}

static func can_pay_charge(gs, owner: int, idx: int, amount: int) -> bool:
	return bool(quote_charge(gs, owner, idx, amount).ok)

static func pay_charge(gs, owner: int, idx: int, amount: int) -> bool:
	var quote := quote_charge(gs, owner, idx, amount)
	if not quote.ok: return false
	var unit: Dictionary = gs.player(owner).units[idx]
	if quote.free: gs.player(owner).sunFreeChargeTurn = gs.turn_counter
	unit.charge = int(unit.get("charge", 0)) - int(quote.charge)
	if int(quote.damage) > 0: gs._damage_unit(owner, idx, int(quote.damage), owner, idx)
	gs._recalc(unit)
	gs.VerifiedRules.event(gs, "charge-paid", {"player": owner, "uid": unit.uid, "quote": quote})
	return true

static func gain_charge(gs, owner: int, idx: int, amount: int) -> void:
	if amount <= 0: return
	var unit: Dictionary = gs.player(owner).units[idx]
	if not active(unit) or not has_charge(unit): return
	var gain := amount
	if role(unit) == "smoke":
		if unit.awakened: gain *= 2
		elif int(unit.get("charge", 0)) == 0: gain += 1
	var before := int(unit.get("charge", 0))
	unit.charge = mini(10, before + gain)
	gs._recalc(unit)
	gs.VerifiedRules.event(gs, "charge-gained", {"player": owner, "uid": unit.uid, "amount": int(unit.charge) - before})

static func begin_turn_charge(gs, owner: int) -> void:
	for idx in gs.player(owner).units.size():
		if active(gs.player(owner).units[idx]) and has_charge(gs.player(owner).units[idx]): gain_charge(gs, owner, idx, 1)

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("sunSmoke", false): return card
	var out := card.duplicate(true)
	var src: int = gs._source_index(owner, card)
	if src < 0: return out
	var unit: Dictionary = gs.player(owner).units[src]
	if card.get("smokeBurst", false):
		var amount := int(unit.get("charge", 0))
		out.text += "\n当前能量%d；可不爆能，或爆能X额外%d伤害。" % [amount, amount]
		out.burstAmount = amount
	if card.get("sunAwaken", false):
		out.text += "\n本回合免除能量消耗：" + ("已使用。" if int(gs.player(owner).get("sunFreeChargeTurn", -1)) == gs.turn_counter else "未使用。")
	return out

static func damage_bonus(card: Dictionary) -> int:
	return int(card.get("foxHandDamageBonus", 0))

static func refresh_clone(unit: Dictionary) -> void:
	if not unit.get("smokeClone", false): return
	unit.smokeChargePower = int(unit.get("charge", 0)) if unit.get("formRules", {}).get("smokeChargePower", false) else 0

static func remove_clone(gs, owner: int, clone: Dictionary, reason: String = "离开战斗区") -> bool:
	if not clone.get("smokeClone", false): return false
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(clone.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(clone.uid)),reason,false)
	if not clone.get("removed", false):
		clone.hp = 0
		clone.front = 0
		clone.knockout = 0
		clone.removed = true
		gs.VerifiedRules.event(gs, "summon-removed", {"player": owner, "uid": clone.uid, "reason": reason})
	return true

static func remove_departed(gs) -> void:
	for owner in 2:
		for clone in gs.player(owner).units:
			if clone.get("smokeClone", false) and int(clone.hp) > 0 and int(clone.front) == 0: remove_clone(gs, owner, clone)

static func summon(gs, owner: int, src: int, mode: String = "") -> void:
	var movement_old: Array = gs.player(owner).units.map(func(u): return int(u.front))
	gs.VerifiedRules.TomatoFire.clear_summons(gs, owner)
	var p: Dictionary = gs.player(owner)
	var source: Dictionary = p.units[src]
	for other in p.units:
		if other.get("smokeClone", false): remove_clone(gs, owner, other, "新分身替换")
		else: other.front = 0
	gs.VerifiedRules.Xuenv.clear_wall(gs, owner)
	var clone: Dictionary = source.duplicate(true)
	clone.uid = "%s:smoke-clone-%d" % [p.id, gs.next_card_id]
	gs.next_card_id += 1
	clone.name = "烟烟罗的分身"
	clone.title = "烟雾分身"
	clone.baseAttack = int(source.attack)
	clone.baseMaxHp = int(source.maxHp)
	clone.attackBonus = 0
	clone.maxHpBonus = 0
	clone.charge = int(int(source.get("charge", 0)) / 2)
	clone.level = int(source.level)
	clone.awakened = false
	clone.unyielding = false
	clone.swift = false
	clone.barrier = false
	clone.keywords = ["charge"]
	clone.combatKeywords = []
	clone.erase("combatUnyielding")
	clone.form = {}
	clone.formRules = {"smokeChargePower": mode == "power", "smokeCopies": mode == "copy"}
	clone.formHooks = []
	clone.passive_hooks = []
	clone.formAbility = "继承本体召唤时力量/生命与一半能量；离开战斗区时移除。" + ("每有1能量便获得1力量。" if mode == "power" else "复制本体使用的法术牌。" if mode == "copy" else "")
	clone.smokeClone = true
	clone.summoned = true
	clone.summon = true
	clone.countsAsShikigami = true
	clone.summonerUid = str(source.uid)
	clone.front = 1
	clone.knockout = 0
	for key in ["permanentAttack", "temporaryAttack", "permanentHp", "cranePower", "untilAttack", "judgeInkAttack", "judgeInkHp", "poisonAuraReduction", "peachTemporaryAttack", "fireflyTemporaryHealth", "shutenDamageGrowth", "sunTemporaryGrowth", "sunPermanentAttack", "sunPermanentHealth", "blackWhiteGrowthAttack", "blackWhiteGrowthHp", "futakuchiFearGrowth", "mianRedGrowth","msSwapDeltas", "rpGrowthAttack", "rpGrowthHp", "rpRenxiaAttack", "bgGreenTemporary","chargedGrowth","chargedBambooGrowth", "twoFacesWind", "twoFacesWindAttack"]: clone.erase(key)
	p.units.append(clone)
	gs.VerifiedRules.Enma.remove_departed(gs)
	gs.VerifiedRules.Weaver.remove_departed(gs)
	gs.VerifiedRules.Vine.remove_departed(gs)
	gs.VerifiedRules.WindRaccoon.remove_departed(gs)
	gs.VerifiedRules.House.remove_departed(gs)
	gs.VerifiedRules.Doll.remove_departed(gs)
	gs.VerifiedRules.Enma.refresh(gs)
	for i in movement_old.size(): gs.VerifiedRules.Movement.moved(gs, owner, i, int(movement_old[i]))
	gs._recalc(clone)
	gs.VerifiedRules.event(gs, "summon-created", {"player": owner, "uid": clone.uid, "sourceUid": source.uid})
	gs.VerifiedRules.automatic_response(gs, 1 - owner, "enemy-entered-front", clone.uid, {"kind": "response-complete"})

static func avatar_response(gs, frame: Dictionary, power: int, options: Dictionary) -> bool:
	var owner := int(frame.playerIndex)
	var victim := int(options.get("combatVictim", 1-owner))
	var src := int(frame.sourceIndex)
	var continuation := frame.duplicate(true)
	continuation.kind = "combat-hit"
	continuation.defenderIndex = -1
	continuation.avatarResponsePending = true
	continuation.power = power
	continuation.attackSnapshot = int(gs.player(owner).units[src].attack)
	continuation.powerMultiplier = 1
	continuation.options = options.duplicate(true)
	continuation.combatId = gs.next_resolution_id
	gs.next_resolution_id += 1
	return gs.VerifiedRules.automatic_response(gs, victim, "avatar-attacked", "avatar-%d" % victim, continuation)

static func smoke_copy(gs, frame: Dictionary, card: Dictionary) -> void:
	if card.get("type") != "spell" or card.get("smokeCopied", false): return
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if role(gs.player(owner).units[src]) != "smoke": return
	for idx in gs.player(owner).units.size():
		var clone: Dictionary = gs.player(owner).units[idx]
		if not active(clone) or int(clone.frozen) > 0 or not clone.get("formRules", {}).get("smokeCopies", false) or clone.get("summonerUid") != gs.player(owner).units[src].uid: continue
		var copied := card.duplicate(true)
		copied.smokeCopied = true
		# Capture the clone present at use time. A freshly summoned replacement
		# cannot retroactively copy the spell that created it.
		var insertion: int = gs.resolution_stack.size()
		for at in gs.resolution_stack.size():
			if int(gs.resolution_stack[at].get("resolutionId", -1)) == int(frame.resolutionId):
				insertion = at
				break
		gs.resolution_stack.insert(insertion, {"kind": "smoke-copy", "playerIndex": owner, "sourceIndex": idx, "sourceUid": clone.uid, "targetId": frame.get("targetId"), "card": copied, "originalResolutionId": int(frame.resolutionId)})

static func start_burst(gs, owner: int, src: int, card: Dictionary, target_id) -> void:
	var amount := int(gs.player(owner).units[src].get("charge", 0))
	var ids: Array = ["smoke-plain"]
	if amount > 0: ids.append("smoke-burst")
	gs.pending_choice = {"type": "smoke-burst", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "targetId": target_id, "resolutionId": int(gs._card_effect_context.get("resolutionId", -1)), "instanceIds": ids, "heading": "爆 能", "title": "选择是否爆能", "hint": "可以保留能量直接使用，或消耗全部%d能量提高伤害。" % amount}
	gs.phase = "choice"

static func burst_cards(gs, owner: int, iid: String) -> Dictionary:
	var choice: Dictionary = gs.pending_choice
	if choice.type == "smoke-pick": return ContentLoader.card_def(iid)
	var card: Dictionary = choice.card
	var amount := int(gs.player(owner).units[int(choice.sourceIndex)].get("charge", 0))
	var cost:int=int(gs.VerifiedRules.Yujiazhu.quote_burst(gs,owner,int(choice.sourceIndex),amount).amount)
	var out := card.duplicate(true)
	out.id = iid
	out.name = "不爆能" if iid == "smoke-plain" else "爆能%d" % amount
	out.text = "保留当前能量，使用原本效果。" if iid == "smoke-plain" else "爆能%d：支付%d能量，本次伤害额外+%d。%s" % [amount, cost, amount, "觉醒日和坊本回合将免除支付。" if free_charge(gs, owner) else ""]
	return out

static func choice_card(gs, owner: int, iid: String) -> Variant:
	if gs.pending_choice.get("type") not in ["smoke-burst", "smoke-pick"]: return null
	return burst_cards(gs, owner, iid)

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["smoke-burst", "smoke-pick"] or int(choice.playerIndex) != owner or not choice.instanceIds.has(iid): return false
	gs._record("resolve_divination_choice", {"choice": choice.type, "instanceId": iid, "card": iid if choice.type == "smoke-pick" else choice.card.id}, owner)
	gs.pending_choice = {}
	gs.phase = "main"
	if choice.type == "smoke-pick":
		var p: Dictionary = gs.player(owner)
		if p.hand.size() < int(gs.rules.maxHandSize):
			p.hand.append({"instanceId": "%s-smoke-%d" % [p.id, gs.next_card_id], "definitionId": iid})
			gs.next_card_id += 1
	else:
		var card: Dictionary = choice.card
		card.smokeBurstSelected = iid == "smoke-burst"
		for frame in gs.resolution_stack:
			if int(frame.get("resolutionId", -1)) == int(choice.resolutionId) and frame.has("cardOverride"): frame.cardOverride.smokeBurstSelected = card.smokeBurstSelected
			if frame.get("kind") == "smoke-copy" and int(frame.originalResolutionId) == int(choice.resolutionId): frame.card.smokeBurstSelected = card.smokeBurstSelected
		gs.resolution_stack.append({"kind": "smoke-hit-choice", "playerIndex": owner, "sourceIndex": int(choice.sourceIndex), "targetId": choice.targetId, "card": card, "resolutionId": int(choice.resolutionId)})
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	# All avatar guards share one continuation. A summoned defender changes the
	# impact target without repeating attack-start effects or encouragement.
	if frame.get("kind") == "combat-hit" and frame.get("avatarResponsePending", false):
		frame.erase("avatarResponsePending")
		var owner := int(frame.playerIndex)
		var victim := int(frame.options.get("combatVictim", 1-owner))
		var idx: int = gs.front_index(victim)
		if idx >= 0 and not frame.options.get("directAvatar", false):
			frame.defenderIndex = idx
			gs.VerifiedRules.Movement.deer_combat(gs, victim, idx)
			gs.VerifiedRules.Poison.transfer_before_combat(gs, owner, int(frame.sourceIndex), victim, idx, frame.options)
			frame.options = gs.VerifiedRules.ArmorBreak.prepare_combat(gs, victim, idx, frame.options)
			gs.VerifiedRules.Fortune.before_attacked(gs, victim, idx)
			if gs.VerifiedRules.automatic_response(gs, victim, "unit-attacked", gs.player(victim).units[idx].uid, frame): return true
		gs._resolve_frame(frame)
		return true
	if frame.get("kind") == "smoke-copy":
		var unit: Dictionary = gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)]
		if active(unit) and int(unit.frozen) == 0 and unit.uid == frame.sourceUid:
			gs._push_card_frames(int(frame.playerIndex), str(frame.card.id), frame.get("targetId"), frame.card, int(frame.sourceIndex), gs.MAX_RESPONSE_DEPTH, true)
			gs.VerifiedRules.event(gs, "smoke-spell-copy", {"player": int(frame.playerIndex), "uid": unit.uid, "card": frame.card})
		return true
	if frame.get("kind") == "smoke-entry-summon":
		summon(gs, int(frame.playerIndex), int(frame.sourceIndex), str(frame.mode))
		return true
	if frame.get("kind") != "smoke-hit-choice": return false
	var context: Dictionary = gs._card_effect_context
	gs._card_effect_context = frame.duplicate(true)
	gs._card_effect_context.cardOverride = frame.card
	gs._card_effect_context.affectedUnits = []
	resolve_smoke_hit(gs, int(frame.playerIndex), int(frame.sourceIndex), frame.card, frame.get("targetId"))
	gs._card_effect_context = context
	return true

static func resolve_smoke_hit(gs, owner: int, src: int, card: Dictionary, target_id) -> void:
	var amount: int = int(card.get("value", 0)) + damage_bonus(card)
	if card.get("smokeBurstSelected", false):
		var energy := int(gs.player(owner).units[src].get("charge", 0))
		if gs.VerifiedRules.Yujiazhu.pay_burst(gs, owner, src, energy):
			amount += energy
			gs.VerifiedRules.Whale.burst(gs,owner,src,energy)
	var enemy := 1 - owner
	var idx: int = gs._unit_index_by_uid(enemy, target_id) if card.get("target") != "auto" else gs.front_index(enemy)
	var hit := {"knocked": false}
	if idx >= 0: hit = gs._damage_unit(enemy, idx, amount, owner, src)
	elif card.get("smokeProjectile", false): gs._damage_avatar(enemy, amount, owner, src)
	if gs.winner < 0 and int(card.get("smokeHeal", 0)) > 0: gs._heal_avatar(owner, int(card.smokeHeal))
	if hit.get("knocked", false) and int(card.get("smokeKillCharge", 0)) > 0: gain_charge(gs, owner, src, int(card.smokeKillCharge))

static func sun_form(gs, owner: int, src: int) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	if not active(source): return
	var mode := str(source.get("formRules", {}).get("sunForm", ""))
	var cost := int(source.get("formRules", {}).get("sunChargeCost", 0))
	if mode == "": return
	var pool: Array = []
	if mode == "transfer":
		for idx in gs.player(owner).units.size():
			var unit: Dictionary = gs.player(owner).units[idx]
			if idx != src and active(unit) and has_charge(unit): pool.append(idx)
		if pool.is_empty(): return
		var least := 11
		for idx in pool: least = mini(least, int(gs.player(owner).units[idx].charge))
		pool = pool.filter(func(i): return int(gs.player(owner).units[i].charge) == least)
	if not pay_charge(gs, owner, src, cost): return
	match mode:
		"draw": gs._draw(owner, 1)
		"transfer": gain_charge(gs, owner, int(pool[int(floor(gs.randf01() * pool.size()))]), 2)
		"rain":
			for idx in gs.player(owner).units.size():
				if idx != src and int(gs.player(owner).units[idx].hp) > 0: gs._heal_unit(gs.player(owner).units[idx], 3)
			gs._heal_avatar(owner, 3)

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var mode := str(card.get("formRules", {}).get("smokeSummon", ""))
	if card.get("smokePick", false):
		# Printed entry order: choose the generated card, then summon the copy.
		gs.resolution_stack.append({"kind": "smoke-entry-summon", "playerIndex": owner, "sourceIndex": src, "mode": mode})
		var pool: Array = ContentLoader.cards_for_unit(str(gs.player(owner).units[src].id)).filter(func(c): return c.get("smokeBurst", false)).map(func(c): return str(c.id))
		gs.pending_choice = {"type": "smoke-pick", "playerIndex": owner, "sourceIndex": src, "instanceIds": pool, "heading": "无 孔 不 入", "title": "选择一张爆能牌置入手牌", "hint": "获得一张烟烟罗的爆能牌"}
		gs.phase = "choice"
	elif mode != "": summon(gs, owner, src, mode)
	sun_form(gs, owner, src)

static func form_turn_start(gs, owner: int, src: int) -> void:
	var source: Dictionary = gs.player(owner).units[src]
	if not active(source): return
	var cfg: Dictionary = source.get("formRules", {})
	if str(cfg.get("smokeSummon", "")) == "copy": summon(gs, owner, src, "copy")
	sun_form(gs, owner, src)

static func enemy_turn_start(gs, current: int) -> void:
	var owner := 1 - current
	for src in gs.player(owner).units.size():
		if gs.player(owner).units[src].get("formRules", {}).get("sunForm") == "rain": sun_form(gs, owner, src)

static func remember_permanent(unit: Dictionary, attack: int, hp: int) -> void:
	unit.sunPermanentAttack = int(unit.get("sunPermanentAttack", 0)) + attack
	unit.sunPermanentHealth = int(unit.get("sunPermanentHealth", 0)) + hp

static func grew(gs, unit: Dictionary, attack: int, hp: int) -> void:
	var frame: Dictionary = gs._card_effect_context
	var card: Dictionary = frame.get("cardOverride", ContentLoader.card_def(str(frame.get("definitionId", ""))))
	if card.is_empty() or not (str(card.get("effect", "")).contains("awaken") or card.get("tags", []).has("觉醒") or card.get("awakening", false)): return
	var owner := int(frame.get("playerIndex", -1))
	var src := int(frame.get("sourceIndex", -1))
	if owner >= 0 and src >= 0 and gs.player(owner).units[src].uid == unit.uid: remember_permanent(unit, attack, hp)

static func rule_event(gs, kind: String, details: Dictionary) -> void:
	var attack := 0
	var hp := 0
	var target_id = details.get("uid")
	if kind == "peach-growth" and details.get("permanent", false):
		attack = int(details.attack)
		hp = int(details.hp)
		target_id = details.target
	elif kind == "jumper-health-growth": hp = int(details.amount)
	else: return
	var target: Dictionary = gs._unit_by_uid(gs._all_units(), target_id)
	if not target.is_empty(): remember_permanent(target, attack, hp)

static func damaged(gs, victim: int, idx: int, amount: int) -> void:
	if amount <= 0: return
	for source in gs.player(victim).units:
		if active(source) and source.get("formRules", {}).get("sunForm") == "rain" and (idx < 0 or source.uid != gs.player(victim).units[idx].uid): gs._heal_unit(source, 3)

static func reset_character(gs, owner: int, target: Dictionary, target_id) -> void:
	if str(target_id).begins_with("avatar-"):
		var victim := int(str(target_id).trim_prefix("avatar-"))
		gs.player(victim).erase("encourage")
		gs.player(victim).erase("encouragePending")
		gs.kw_usage(victim, "encourage").attack = 0
		gs.kw_usage(victim, "encourage").shield = 0
		return
	if target.is_empty() or int(target.hp) <= 0: return
	# Awakening and explicitly permanent ledgers survive; printed form stays installed.
	gs.VerifiedRules.Cooking.reset_ledger(target)
	gs.VerifiedRules.ApeSleeve.reset_ledger(target)
	target.attackBonus = int(target.get("sunPermanentAttack", 0))
	target.maxHpBonus = int(target.get("sunPermanentHealth", 0))
	for key in ["judgeInkAttack", "judgeInkHp", "temporaryAttack", "cranePower", "untilAttack", "peachTemporaryAttack", "fireflyTemporaryHealth", "shutenTemporaryAttack", "shutenDamageGrowth", "shutenRageGrowth", "bloodGainedPower", "sunTemporaryGrowth", "flashAttackReduction", "flashAppliedTurn", "blackWhiteGrowthAttack", "blackWhiteGrowthHp", "futakuchiFearGrowth", "mianRedGrowth","msSwapDeltas", "rpGrowthAttack", "rpGrowthHp", "rpRenxiaAttack", "bgGreenTemporary","chargedGrowth","chargedBambooGrowth", "demonGrowth"]: target.erase(key)
	# 风起云涌的追猎与其本回合力量是不同效果；重置数值不移除追猎。
	if target.has("twoFacesWind"): target.twoFacesWindAttack = 0
	target.shield = 0
	target.shieldExpires = 0
	target.armorBreak = 0
	gs._recalc(target)
	target.hp = int(target.maxHp)
	gs.VerifiedRules.event(gs, "sun-stats-reset", {"player": owner, "target": target.uid})

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	match str(effect.get("action", "")):
		"smoke-hit":
			if card.get("smokeCopied", false) or card.has("smokeBurstSelected"): resolve_smoke_hit(gs, owner, src, card, target_id)
			else: start_burst(gs, owner, src, card, target_id)
		"smoke-summon": summon(gs, owner, src, str(unit.get("formRules", {}).get("smokeSummon", "")))
		"smoke-charge": gain_charge(gs, owner, src, int(effect.value))
		"smoke-awaken":
			gain_charge(gs, owner, src, 2)
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
		"sun-heal":
			for idx in p.units.size():
				if active(p.units[idx]) and has_charge(p.units[idx]):
					gs._heal_unit(p.units[idx], int(p.units[idx].maxHp))
					gain_charge(gs, owner, idx, 1)
		"sun-growth":
			for idx in p.units.size():
				if active(p.units[idx]) and has_charge(p.units[idx]):
					gs._grow_unit(p.units[idx], 1, 1)
					p.units[idx].sunTemporaryGrowth = int(p.units[idx].get("sunTemporaryGrowth", 0)) + 1
					gain_charge(gs, owner, idx, 2)
		"sun-heat":
			if target.is_empty(): return true
			for victim in 2:
				var idx: int = gs._unit_index_by_uid(victim, target.uid)
				if idx >= 0:
					gs._damage_unit(victim, idx, 1 + damage_bonus(card), owner, src)
					if int(target.hp) > 0: gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)
		"sun-reset": reset_character(gs, owner, target, target_id)
		"sun-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, 0, 3)
		_: return false
	return true

static func knocked_out(unit: Dictionary) -> void:
	var growth := int(unit.get("sunTemporaryGrowth", 0))
	unit.attackBonus = int(unit.attackBonus) - growth
	unit.maxHpBonus = int(unit.maxHpBonus) - growth
	unit.erase("sunTemporaryGrowth")

static func ai_choice(gs, owner: int) -> Variant:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["smoke-burst", "smoke-pick"]: return null
	if int(choice.playerIndex) != owner: return false
	if choice.type == "smoke-pick": return gs.resolve_divination_choice(owner, "c16408")
	var card: Dictionary = choice.card
	var enemy := 1 - owner
	var target: Dictionary = gs._unit_by_uid(gs.player(enemy).units, choice.get("targetId")) if card.target != "auto" else gs.front_unit(enemy)
	var base := int(card.value) + damage_bonus(card)
	var needs := int(target.get("hp", gs.player(enemy).avatarHp)) + int(target.get("shield", gs.player(enemy).avatarArmor))
	var wants_burst := free_charge(gs, owner) or needs > base
	return gs.resolve_divination_choice(owner, "smoke-burst" if wants_burst and choice.instanceIds.has("smoke-burst") else "smoke-plain")

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("sunSmoke", false): return null
	if card.get("effect") == "sun-heat":
		if gs._unit_index_by_uid(owner, target_id) >= 0: return -100
		return 58
	if card.get("smokeBurst", false): return 55
	if card.get("effect") == "sun-reset":
		var enemy: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
		return 50 if not enemy.is_empty() and int(enemy.attack) > int(enemy.baseAttack) + int(enemy.get("form", {}).get("attackBonus", 0)) else -100
	if card.get("type") == "form": return 48
	if card.get("effect") in ["sun-awaken", "smoke-awaken"]: return 56
	if card.get("effect") == "smoke-summon": return 34 if gs.front_index(owner) < 0 else -100
	if card.get("effect") == "sun-heal": return 45 if gs.player(owner).units.any(func(u): return has_charge(u) and int(u.hp) > 0 and int(u.hp) < int(u.maxHp)) else -100
	if card.get("effect") == "smoke-charge": return 40
	if card.get("effect") == "sun-growth": return 46
	return null
