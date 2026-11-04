class_name BlueGreenRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("blueGreenRole", ""))

static func active(u: Dictionary) -> bool:
	return int(u.get("hp", 0)) > 0 and int(u.get("level", 0)) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func living(gs, owner: int) -> Array:
	return gs.player(owner).units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))

static func all_faction(gs, owner: int, faction: String) -> bool:
	var units: Array = gs.player(owner).units.filter(func(u): return not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u))
	return not units.is_empty() and units.all(func(u): return Factions.get_faction(u) == faction)

static func other_count(gs, owner: int, src: int, faction: String) -> int:
	var uid := str(gs.player(owner).units[src].uid)
	return living(gs, owner).filter(func(u): return str(u.uid) != uid and Factions.get_faction(u) == faction).size()

static func realm_count(gs, owner: int, key: String) -> int:
	return gs.player(owner).realms.filter(func(r): return int(r.hp) > 0 and str(r.get("nativeRealm", "")) == key).size()

static func aura_bonus(gs, target: Dictionary, _stat: String) -> int:
	if target.get("removed", false) or not gs.VerifiedRules.OwlInsect.shikigami(target): return 0
	for p in gs.players:
		if not p.units.has(target): continue
		var amount := 0
		for u in p.units:
			if u.uid == target.uid or not active(u) or not u.awakened: continue
			var wanted := "青岚" if role(u) == "blue" else "苍叶" if role(u) == "green" else ""
			if wanted != "" and Factions.get_faction(target) == wanted: amount += 1
		return amount
	return 0

static func refresh(gs) -> void:
	gs.VerifiedRules.RedPurple.refresh(gs)

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var p: Dictionary = gs.player(owner)
	var caster: Dictionary = p.units[src]
	# A generated card still belongs to its actual shikigami: Kurikara can be
	# the second blue card after Intent, just as a card from the starting deck.
	var faction := Factions.get_faction(caster)
	if faction == "苍叶":
		for u in p.units:
			if role(u) != "green" or not active(u) or u.uid == caster.uid: continue
			u.temporaryAttack = int(u.get("temporaryAttack", 0)) + 1
			u.bgGreenTemporary = int(u.get("bgGreenTemporary", 0)) + 1
			gs._recalc(u)
			gs.VerifiedRules.event(gs, "bg-green-card-growth", {"player": owner, "uid": u.uid, "caster": caster.uid})
	if faction != "青岚": return
	if int(p.get("bgBlueCardsTurn", -1)) != gs.turn_counter: p.bgBlueCardsTurn = gs.turn_counter; p.bgBlueCards = 0
	p.bgBlueCards = int(p.bgBlueCards) + 1
	if int(p.bgBlueCards) != 2: return
	frame.bgBlueSecond = true
	frame.bgBlueRealmUids = p.realms.filter(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "bg-sakura").map(func(r): return str(r.uid))
	for queued in gs.resolution_stack:
		if queued.get("kind") == "card-complete" and int(queued.get("resolutionId", -1)) == int(frame.resolutionId):
			queued.bgBlueSecond = true
			queued.bgBlueRealmUids = frame.bgBlueRealmUids.duplicate()
	for i in range(p.units.size() - 1, -1, -1):
		var u: Dictionary = p.units[i]
		if not active(u): continue
		if u.get("formRules", {}).get("bgCharging", false): gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, i, 1)
		if role(u) == "blue" and (not u.awakened or int(u.get("bgBlueAwakenTurn", -1)) == gs.turn_counter):
			gs.resolution_stack.append({"kind": "bg-blue-projectile", "playerIndex": owner, "sourceIndex": i})

static func completed(gs, frame: Dictionary, _card: Dictionary) -> void:
	if not frame.get("bgBlueSecond", false): return
	var owner := int(frame.playerIndex)
	for uid in frame.get("bgBlueRealmUids", []):
		if gs.player(owner).realms.any(func(r): return str(r.uid) == str(uid) and int(r.hp) > 0):
			gs.resolution_stack.append({"kind": "bg-draw", "playerIndex": owner, "count": 1})

static func rule_event(gs, kind: String, details: Dictionary) -> void:
	if kind == "faction-changed": refresh(gs)
	if kind != "fortune-result" or not details.get("success", false): return
	var owner := int(details.player)
	for inst in gs.player(owner).hand:
		if str(inst.definitionId) != "c20602": continue
		if int(inst.get("bgMingcheTurn", -1)) != gs.turn_counter: inst.bgMingcheTurn = gs.turn_counter; inst.bgMingchePower = 0; inst.bgMingcheTraits = []
		inst.bgMingchePower = int(inst.bgMingchePower) + 1
		var pool: Array = Content.card_def("c20602").get("bgMingchePool", []).filter(func(k): return k not in inst.bgMingcheTraits)
		if not pool.is_empty(): inst.bgMingcheTraits.append(str(pool[int(gs.next_random() % pool.size())]))
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if active(u) and u.get("formRules", {}).get("bgTwin", false): gs.VerifiedRules.reduce_countdown(gs, owner, i, 1)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("blueGreenRules", false): return card
	var c := card.duplicate(true)
	var src: int = gs._source_index(owner, c)
	if src < 0: return c
	match str(c.id):
		"c20601", "c20704":
			var count := other_count(gs, owner, src, "苍叶" if c.id == "c20601" else "青岚")
			c.value = {"attack": (2 if c.id == "c20601" else 3) + count, "hp": 5 if c.id == "c20601" else 6, "setBase": true}
			c.effects[0].value = c.value.duplicate(true)
			c.enhanced = count > 0
			c.currentCardStats = "其他存活同派%d位 · 当前%d/%d" % [count, int(c.value.attack), int(c.value.hp)]
		"c20602":
			var power := int(inst.get("bgMingchePower", 0)) if int(inst.get("bgMingcheTurn", -1)) == gs.turn_counter else 0
			c.value = 1 + power
			c.effects[0].value = c.value
			c.combatOption = {"shield": 1}
			if power > 0:
				for k in inst.get("bgMingcheTraits", []):
					if k not in c.keywords: c.keywords.append(k)
					match str(k):
						"direct": c.combatOption.directAvatar = true
						"pursuit": c.combatOption.pursuit = true; c.target = "enemy-unit"
						"lifesteal": c.combatOption.lifeSteal = true
						"lethal": c.combatOption.lethal = true
						"unyielding": c.combatOption.unyielding = true
			c.currentCardStats = "本回合运势增强%d次 · +%d力量/+1护甲" % [power, int(c.value)]
			c.enhanced = power > 0
		"c20603":
			c.enhanced = all_faction(gs, owner, "苍叶")
			c.value = 4 if c.enhanced else 3
			c.effects[0].value = c.value
			if c.enhanced and "pierce" not in c.keywords: c.keywords.append("pierce")
			c.currentCardStats = "纯苍叶 · 4伤害并贯通" if c.enhanced else "3伤害"
		"c20703":
			c.enhanced = all_faction(gs, owner, "青岚")
			c.currentCardStats = "纯青岚 · 先占卜2再抽2" if c.enhanced else "抽两张牌"
	return c

static func targets(gs, owner: int, card: Dictionary):
	if str(card.get("id", "")) not in ["c20603", "c20701"]: return null
	var result: Array = []
	for side in [owner, 1 - owner]:
		for u in living(gs, side):
			if side == owner or not gs.VerifiedRules.Combat.has(u, "veil"): result.append(str(u.uid))
	return result

static func can_use(_gs, _owner: int, _card: Dictionary) -> bool:
	# Four-faction awakenings may be used again; their ongoing aura never stacks.
	return true

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if str(card.get("id", "")) == "c20601": gs.player(owner).units[src].swift = true

static func _instance(gs, owner: int, id: String) -> void:
	var item := {"definitionId": id, "instanceId": "bg-generated-%d" % gs.next_card_id}
	gs.next_card_id += 1
	if gs.player(owner).hand.size() < int(gs.rules.maxHandSize): gs.player(owner).hand.append(item)
	gs.VerifiedRules.event(gs, "bg-generated", {"player": owner, "card": Content.card_def(id), "instanceId": item.instanceId})

static func _awaken(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "blue": u.bgBlueAwakenTurn = gs.turn_counter
	if u.awakened:
		gs.VerifiedRules.Glutton.record_permanent(u, 1, 1)
		gs._grow_unit(u, 1, 1)
	else: gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
	refresh(gs)

static func _revelation(gs, owner: int, src: int, card: Dictionary, target_id) -> void:
	for victim in 2:
		var idx: int = gs._unit_index_by_uid(victim, str(target_id))
		if idx < 0: continue
		var target: Dictionary = gs.player(victim).units[idx]
		if int(target.hp) <= 0: return
		var amount := int(card.value) + int(gs.player(owner).units[src].get("spellPower", 0))
		var overflow := 0
		if card.get("enhanced", false) and not target.get("bloodTransfer", false) and not gs.VerifiedRules.OniAsura.will_transfer(gs, target):
			var preview := maxi(0, amount + gs.VerifiedRules.HandBlessing.damage_delta(gs, owner, src, false))
			preview += gs.VerifiedRules.Maple.damage_bonus(gs, owner, src, false)
			preview = gs.VerifiedRules.Bingyong.limit_damage(target, preview + int(target.armorBreak) + (1 if int(target.brittle) > 0 else 0))
			preview = gs.VerifiedRules.Jorogumo.received_damage(target, maxi(0, preview - int(target.shield)))
			preview = gs.VerifiedRules.Mianqiling.modify_damage(gs, victim, idx, preview, owner, src)
			preview = gs.VerifiedRules.OwlInsect.reduced(target, gs.VerifiedRules.MonkCleaner.reduced(target, preview))
			overflow = maxi(0, preview - int(target.hp))
		var hit: Dictionary = gs._damage_unit(victim, idx, amount, owner, src)
		if overflow > 0 and not hit.get("redirected", false) and gs.winner < 0: gs._damage_avatar(victim, overflow, owner, src)
		return

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	match str(effect.get("action", "")):
		"bg-awaken": _awaken(gs, owner, src, card)
		"bg-twin-attack": gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"directAvatar": true})
		"bg-combat":
			var options: Dictionary = card.get("combatOption", {}).duplicate(true)
			options.combatCard = card.duplicate(true)
			gs._grant_unit_armor(gs.player(owner).units[src], int(options.get("shield", 0)))
			gs._record("assault", {"unit": src, "bonus": int(card.value), "target": target_id}, owner)
			gs._resolve_combat(owner, src, int(card.value), gs._kw(card, "pierce"), gs._kw(card, "remote"), gs._kw(card, "combo"), gs._kw(card, "first-strike"), target_id, gs._kw(card, "crit"), options)
		"bg-revelation": _revelation(gs, owner, src, card, target_id)
		"bg-dark-feather":
			for u in living(gs, owner): u.bgDirect = true
		"bg-team-attack":
			var team: Array = living(gs, owner).filter(func(u): return Factions.get_faction(u) == "苍叶")
			for u in team: u.bgGreenImmuneTurn = gs.turn_counter
			gs._shuffle(team)
			var order := team.map(func(u): return str(u.uid))
			gs.VerifiedRules.event(gs, "bg-team-attack-order", {"player": owner, "order": order})
			for i in range(order.size() - 1, -1, -1): gs.resolution_stack.append({"kind": "bg-team-attack", "playerIndex": owner, "targetUid": order[i]})
		"bg-intent":
			for side in 2:
				var idx: int = gs._unit_index_by_uid(side, str(target_id))
				if idx >= 0: gs.VerifiedRules.Stun.apply(gs, side, idx, 1, owner)
			_instance(gs, owner, "julijialuo-wan")
		"bg-kurikara":
			var pool: Array = living(gs, 1 - owner).filter(func(u): return int(u.frozen) > 0)
			for i in range(pool.size() - 1, -1, -1): gs.resolution_stack.append({"kind": "bg-kurikara-hit", "playerIndex": owner, "sourceIndex": src, "targetUid": str(pool[i].uid), "amount": 2 + int(gs.player(owner).units[src].get("spellPower", 0)), "context": gs._card_effect_context.duplicate(true)})
		"bg-outline":
			gs.resolution_stack.append({"kind": "bg-draw", "playerIndex": owner, "count": 2})
			if card.get("enhanced", false): gs.VerifiedRules.Divination.start(gs, owner, 2)
		"bg-freehand":
			var enemies := living(gs, 1 - owner)
			if not enemies.is_empty(): gs.VerifiedRules.Stun.apply(gs, 1 - owner, gs._unit_index_by_uid(1 - owner, str(enemies[int(gs.next_random() % enemies.size())].uid)), 1, owner)
			var doomed: Array = []
			for side in 2:
				for u in living(gs, side):
					if int(u.frozen) > 0: doomed.append({"owner": side, "uid": str(u.uid)})
			for i in range(doomed.size() - 1, -1, -1): gs.resolution_stack.append({"kind": "bg-freehand-kill", "playerIndex": owner, "sourceIndex": src, "victimPlayer": doomed[i].owner, "targetUid": doomed[i].uid, "card": card.duplicate(true)})
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("bg-"): return false
	var owner := int(frame.playerIndex)
	match kind:
		"bg-blue-projectile": gs.VerifiedRules.base_damage_projectile(gs, owner, int(frame.sourceIndex), 2, "樱雪姬第二张青岚牌")
		"bg-draw": gs._draw(owner, int(frame.count))
		"bg-eye-stun":
			var src := int(frame.sourceIndex)
			var u: Dictionary = gs.player(owner).units[src]
			if not active(u) or not u.get("formRules", {}).get("bgCharging", false) or not gs.VerifiedRules.SunSmoke.pay_charge(gs, owner, src, 4): return true
			gs.VerifiedRules.Stun.apply(gs, 1 - owner, gs.front_index(1 - owner), 1, owner)
			gs.VerifiedRules.event(gs, "bg-eye-stun", {"player": owner, "uid": u.uid})
		"bg-team-attack":
			var idx: int = gs._unit_index_by_uid(owner, str(frame.targetUid))
			if idx >= 0 and int(gs.player(owner).units[idx].hp) > 0:
				gs.VerifiedRules.event(gs, "bg-team-attacked", {"player": owner, "uid": str(frame.targetUid)})
				gs._resolve_combat(owner, idx, 0, false, false, false, false)
		"bg-kurikara-hit":
			var idx: int = gs._unit_index_by_uid(1 - owner, str(frame.targetUid))
			var old: Dictionary = gs._card_effect_context; gs._card_effect_context = frame.context
			if idx >= 0: gs._damage_unit(1 - owner, idx, int(frame.amount), owner, int(frame.sourceIndex))
			gs._card_effect_context = old
		"bg-freehand-kill":
			var victim := int(frame.victimPlayer)
			var idx: int = gs._unit_index_by_uid(victim, str(frame.targetUid))
			if idx >= 0 and int(gs.player(victim).units[idx].hp) > 0: gs.VerifiedRules.Panguan.destroy(gs, owner, int(frame.sourceIndex), victim, idx, frame.card)
	return true

static func combat_immune(gs, owner: int, src: int) -> bool:
	var u: Dictionary = gs.player(owner).units[src]
	return int(u.get("bgGreenImmuneTurn", -1)) == gs.turn_counter or (gs.current_player == owner and Factions.get_faction(u) == "青岚" and realm_count(gs, owner, "bg-snow") > 0)

static func snow_stun(gs, owner: int, src: int) -> bool:
	return gs.current_player == owner and Factions.get_faction(gs.player(owner).units[src]) == "青岚" and realm_count(gs, owner, "bg-snow") > 0

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, hit: Dictionary, options: Dictionary) -> void:
	if int(hit.get("dealt", hit.get("damage", 0))) <= 0: return
	if options.get("bgSnowStun", snow_stun(gs, owner, src)): gs.VerifiedRules.Stun.apply(gs, victim, idx, 1, owner)

static func avatar_bonus(gs, owner: int, src: int) -> int:
	if owner < 0 or owner >= gs.players.size() or src < 0 or src >= gs.player(owner).units.size(): return 0
	return realm_count(gs, owner, "bg-glass") if Factions.get_faction(gs.player(owner).units[src]) == "苍叶" else 0

static func has_trait(u: Dictionary, keyword: String) -> bool:
	return keyword == "direct" and int(u.get("hp", 0)) > 0 and u.get("bgDirect", false)

static func end_turn(gs, owner: int) -> void:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if active(u) and u.get("formRules", {}).get("bgCharging", false) and gs.VerifiedRules.SunSmoke.can_pay_charge(gs, owner, i, 4): gs.resolution_stack.append({"kind": "bg-eye-stun", "playerIndex": owner, "sourceIndex": i})

static func expire(gs) -> void:
	for p in gs.players:
		for u in p.units:
			u.temporaryAttack = int(u.get("temporaryAttack", 0)) - int(u.get("bgGreenTemporary", 0))
			u.erase("bgGreenTemporary"); u.erase("bgGreenImmuneTurn")
			gs._recalc(u)

static func knocked_out(u: Dictionary) -> void:
	u.erase("bgGreenTemporary"); u.erase("bgGreenImmuneTurn"); u.erase("bgDirect")

static func marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary = gs.player(owner).units[idx]
	var result: Array = []
	if role(u) == "blue": result.append("本回合青岚牌%d张" % (int(gs.player(owner).get("bgBlueCards", 0)) if int(gs.player(owner).get("bgBlueCardsTurn", -1)) == gs.turn_counter else 0))
	if role(u) == "green" and int(u.get("bgGreenTemporary", 0)) > 0: result.append("本回合同派用牌力量+%d" % int(u.bgGreenTemporary))
	if aura_bonus(gs, u, "attack") > 0: result.append("青／绿觉醒光环+%d/+%d" % [aura_bonus(gs, u, "attack"), aura_bonus(gs, u, "hp")])
	if u.get("bgDirect", false): result.append("暗羽 · 直击")
	if combat_immune(gs, owner, idx): result.append("本回合免疫战斗伤害")
	if u.get("formRules", {}).get("bgCharging", false): result.append("窥秘之瞳 · 回合结束付4能量投射眩晕")
	return result

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("blueGreenRules", false): return null
	if str(card.id) in ["c20701", "c20603"]:
		if gs._unit_index_by_uid(owner, str(target_id)) >= 0: return -100
		return 55
	if str(card.id) == "c20707": return 35 + living(gs, 1 - owner).filter(func(u): return int(u.frozen) > 0).size() * 20 - living(gs, owner).filter(func(u): return int(u.frozen) > 0).size() * 20
	if str(card.id) == "c20608": return 35 + living(gs, owner).filter(func(u): return Factions.get_faction(u) == "苍叶").size() * 15
	if str(card.id) == "julijialuo-wan": return 15 + living(gs, 1 - owner).filter(func(u): return int(u.frozen) > 0).size() * 20
	if str(card.id) in ["c20706", "c20606"]: return 65 if not gs.player(owner).units[gs._source_index(owner, card)].awakened else 5
	return 45
