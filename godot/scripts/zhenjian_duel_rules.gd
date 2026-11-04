class_name ZhenjianDuelRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const WHIRL := "zd-whirl"

static func role(u: Dictionary) -> String:
	return str(Content.runtime_unit_def(u).get("zdRole", ""))

static func active(u: Dictionary) -> bool:
	return int(u.get("hp", 0)) > 0 and int(u.get("level", 0)) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func power(u: Dictionary) -> int:
	return int(u.level) if active(u) and role(u) == "canghai" and u.has("lanternStored") else 0

static func refresh(gs) -> void:
	for p in gs.players:
		for u in p.units:
			if role(u) == "canghai": gs._recalc(u)

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	var src: int = gs._source_index(owner, card)
	if src < 0: return card
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "": return card
	var c := card.duplicate(true)
	var moved_free: bool = int(u.get("zdFreeTurn", -1)) == gs.turn_counter
	var moved_instant: bool = int(u.get("zdInstantTurn", -1)) == gs.turn_counter
	var fierce: bool = active(u) and u.get("formRules", {}).get("zdFierce", false)
	if (moved_instant or fierce) and not c.keywords.has("instant"): c.keywords.append("instant")
	c.zdFree = moved_free or (str(c.id) == "c26502" and int(u.get("zdAttackedTurn", -1)) == gs.turn_counter)
	if moved_free: c.currentCardStats = "身法 · 下一张牌不消耗鬼火，未蓄力也触发蓄力效果"
	elif moved_instant: c.currentCardStats = "身法 · 下一张牌瞬发"
	if str(c.id) == "c26502": c.enhanced = int(u.get("zdAttackedTurn", -1)) == gs.turn_counter
	return c

static func payment(_gs, _owner: int, card: Dictionary, quote: Dictionary) -> Dictionary:
	if not card.get("zdFree", false): return quote
	var q := quote.duplicate(true)
	q.cost = 0; q.usesInstant = false; q.zdFree = true
	return q

static func consume_card(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("zdRules", false) or src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) != "wuchen": return
	if int(u.get("zdFreeTurn", -1)) == gs.turn_counter: u.erase("zdFreeTurn")
	if int(u.get("zdInstantTurn", -1)) == gs.turn_counter: u.erase("zdInstantTurn")

static func prepare_card(gs, owner: int, src: int, card: Dictionary) -> Dictionary:
	if not card.get("zdRules", false): return card
	var c := card.duplicate(true)
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "wuchen" and int(u.get("zdFreeTurn", -1)) == gs.turn_counter and not c.get("chargedReleased", false): c.zdChargedCount = 1
	consume_card(gs, owner, src, c)
	return c

static func prepare_release(gs, owner: int, src: int, card: Dictionary, record: Dictionary) -> Dictionary:
	if not card.get("zdRules", false): return card
	var c := card.duplicate(true)
	var u: Dictionary = gs.player(owner).units[src]
	c.zdChargedCount = 2 if role(u) == "canghai" and u.awakened else 1
	if record.has("zdCounterTarget"): c.zdCounterTarget = record.zdCounterTarget
	if record.has("zdFollowupTarget"): c.zdFollowupTarget = record.zdFollowupTarget
	gs._recalc(u)
	return c

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("zdAwaken", false): return true
	var src: int = gs._source_index(owner, card)
	return src >= 0 and not gs.player(owner).units[src].awakened

static func can_manual_release(gs, owner: int, src: int) -> bool:
	if src < 0 or src >= gs.player(owner).units.size(): return false
	var u: Dictionary = gs.player(owner).units[src]
	return gs.winner < 0 and active(u) and role(u) == "canghai" and u.awakened and u.has("lanternStored") and gs.current_player == owner and gs.phase == "main" and gs.response_window.is_empty() and gs.pending_choice.is_empty() and not gs.VerifiedRules.Stun.blocks(gs, owner, u)

static func release(gs, owner: int, src: int) -> bool:
	if not can_manual_release(gs, owner, src): return false
	return gs.VerifiedRules.ChargedPair.release(gs, owner, src)

static func auto_release(u: Dictionary) -> bool:
	return not (role(u) == "canghai" and u.awakened)

static func rule_event(gs, kind: String, details: Dictionary) -> void:
	if kind in ["charged-stored", "charged-release"]:
		var owner := int(details.player); var idx: int = gs._unit_index_by_uid(owner, str(details.uid))
		if idx >= 0:
			var u: Dictionary = gs.player(owner).units[idx]
			if role(u) == "canghai": gs._recalc(u)
			if kind == "charged-stored" and active(u) and u.get("formRules", {}).get("zdSword", false): gs.resolution_stack.append({"kind": "zd-sword", "playerIndex": owner, "sourceIndex": idx})
	if kind != "unit-moved": return
	var owner := int(details.player); var idx: int = gs._unit_index_by_uid(owner, str(details.uid))
	if idx < 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u) or role(u) != "wuchen": return
	if u.awakened:
		if int(u.get("zdMoveUsedTurn", -1)) != gs.turn_counter:
			u.zdMoveUsedTurn = gs.turn_counter; u.zdFreeTurn = gs.turn_counter
	elif int(u.front) == 0: u.zdInstantTurn = gs.turn_counter
	if u.get("formRules", {}).get("zdSword", false): gs.resolution_stack.append({"kind": "zd-sword", "playerIndex": owner, "sourceIndex": idx})

static func _give(gs, owner: int, id: String) -> void:
	if gs.player(owner).hand.size() >= int(gs.rules.maxHandSize): return
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "%s-zd-gift-%d" % [gs.player(owner).id, gs.next_card_id]})
	gs.next_card_id += 1

static func _gift_combat(gs, owner: int, src: int, history: bool) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	var pool: Array = u.get("zdCombatHistory", []) if history else Content.cards_for_unit(str(u.id)).filter(func(c): return c.type == "combat" and not c.get("token", false)).map(func(c): return str(c.id))
	if not pool.is_empty(): _give(gs, owner, str(pool[int(gs.next_random() % pool.size())]))

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("zdRules", false): return
	var u: Dictionary = gs.player(owner).units[src]
	if card.get("formRules", {}).get("zdFierce", false): _gift_combat(gs, owner, src, true)
	if card.get("formRules", {}).get("zdDischarge", false): gs.VerifiedRules.move_unit(gs, owner, u)
	if card.get("formRules", {}).get("zdSword", false): u.swift = true

static func turn_start(gs, owner: int) -> void:
	for i in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[i]
		if role(u) == "wuchen": u.erase("zdStepCounter")
		if active(u) and u.get("formRules", {}).get("zdFierce", false): _gift_combat(gs, owner, i, true)

static func prevents_damage(gs, owner: int, idx: int, amount: int, combat: bool) -> bool:
	var u: Dictionary = gs.player(owner).units[idx]
	if not active(u) or amount <= 0: return false
	if not combat and u.get("formRules", {}).get("zdFierce", false): return true
	if u.get("formRules", {}).get("zdDischarge", false) and int(u.get("zdDischargeTurn", -1)) != gs.turn_counter:
		u.zdDischargeTurn = gs.turn_counter
		gs.VerifiedRules.move_unit(gs, owner, u)
		gs.VerifiedRules.event(gs, "zd-damage-prevented", {"player": owner, "uid": u.uid, "amount": amount})
		return true
	return false

static func reduce_damage(u: Dictionary, amount: int, combat: bool) -> int:
	return maxi(0, amount - 1) if combat and active(u) and u.get("formRules", {}).get("zdRock", false) else amount

static func prevent_destroy(u: Dictionary) -> bool:
	return active(u) and u.get("formRules", {}).get("zdFierce", false)

static func defend_started(gs, frame: Dictionary) -> bool:
	var owner := int(frame.options.get("combatVictim", 1-int(frame.playerIndex)))
	var src := int(frame.defenderIndex)
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or gs.VerifiedRules.Stun.blocks(gs, owner, u): return false
	var enemy := int(frame.playerIndex); var attacker: Dictionary = gs.player(enemy).units[int(frame.sourceIndex)]
	var attacker_stored: bool = attacker.has("lanternStored") and gs.VerifiedRules.OwlInsect.shikigami(attacker)
	if u.get("zdStepCounter", false) and attacker_stored:
		gs.resolution_stack.append({"kind": "zd-defense-ready", "combat": frame.duplicate(true)})
		gs.VerifiedRules.Panguan.destroy(gs, owner, src, enemy, int(frame.sourceIndex), Content.card_def("c26502"))
		return true
	var id := str(u.get("lanternStored", {}).get("card", {}).get("id", ""))
	if id != "c26403" and not (id == "c26404" and attacker_stored): return false
	u.lanternStored.zdCounterTarget = str(attacker.uid)
	gs.resolution_stack.append({"kind": "zd-defense-ready", "combat": frame.duplicate(true)})
	return gs.VerifiedRules.ChargedPair.release(gs, owner, src)

static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	if not card.get("zdRules", false): return
	var owner := int(frame.playerIndex); var src := int(frame.sourceIndex); var u: Dictionary = gs.player(owner).units[src]
	if str(card.type) == "combat":
		var history: Array = u.get("zdCombatHistory", [])
		if not history.has(str(card.id)): history.append(str(card.id))
		u.zdCombatHistory = history
	if str(card.id) == "c26407" and card.get("usedFromHand", not frame.get("automatic", false)):
		gs.resolution_stack.append({"kind": "zd-auto-store", "playerIndex": owner, "sourceIndex": src, "card": card.duplicate(true), "targetId": frame.get("targetId")})

static func _store_followup(gs, owner: int, src: int, target_id) -> void:
	if gs.VerifiedRules.ChargedPair.store_copy(gs, owner, src, Content.card_def("wuchen-followup"), null):
		gs.player(owner).units[src].lanternStored.zdFollowupTarget = str(target_id)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not str(effect.get("action", "")).begins_with("zd-"): return false
	var u: Dictionary = gs.player(owner).units[src]
	var count := int(card.get("zdChargedCount", 0))
	match str(effect.action):
		"zd-awaken":
			if role(u) == "wuchen": _gift_combat(gs, owner, src, false)
			gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
		"zd-step":
			u.zdStepCounter = true
			gs.resolution_stack.append({"kind": "zd-step-draw", "playerIndex": owner, "sourceIndex": src})
			gs.VerifiedRules.move_unit(gs, owner, u)
		"zd-flame":
			if count > 0: u.barrier = true
			gs.VerifiedRules.ThreeTail.projectile(gs, owner, src, int(u.attack)+int(u.get("spellPower", 0)), "燎原劲")
		"zd-combat":
			if str(card.id) == "c26404" and count > 0:
				gs.resolution_stack.append({"kind": "zd-draw", "playerIndex": owner, "sourceIndex": src, "amount": count})
			if card.has("zdCounterTarget"):
				var idx: int = gs._unit_index_by_uid(1-owner, str(card.zdCounterTarget))
				if idx >= 0: gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1-owner, idx, card)
				return true
			if str(card.id) == "c26503":
				gs.resolution_stack.append({"kind": "zd-followup-store", "playerIndex": owner, "sourceIndex": src, "targetId": target_id})
			if str(card.id) == "c26407" and count > 0:
				for repeat in count:
					var again := card.duplicate(true); again.zdChargedCount = 0; again.erase("chargedReleased"); again.zdRepeat = true; again.usedFromHand = false
					gs.resolution_stack.append({"kind": "zd-repeat", "playerIndex": owner, "sourceIndex": src, "card": again})
			var options: Dictionary = card.get("combatOption", {}).duplicate(true); options.combatCard = card.duplicate(true)
			var bonus := int(card.value)
			if count > 0:
				match str(card.id):
					"c26401": bonus += count; options.pierce = true
					"c26402": options.zdWhirl = count
					"c26501": options.directAvatar = true
					"c26504": options.immuneCombat = true
					"c26506": options.combo = true
			if str(card.id) == "wuchen-followup":
				var idx: int = gs._unit_index_by_uid(1-owner, str(card.get("zdFollowupTarget", "")))
				if idx >= 0 and int(gs.player(1-owner).units[idx].hp) > 0: target_id = gs.player(1-owner).units[idx].uid; options.pursuit = true
			if str(card.id) == "c26504": options.zdRetreat = true
			gs._grant_unit_armor(u, int(options.get("shield", 0)))
			gs._record("assault", {"unit": src, "bonus": bonus, "target": target_id}, owner)
			gs._resolve_combat(owner, src, bonus, false, false, false, false, target_id, false, options)
	return true

static func _rock_store(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or not u.get("formRules", {}).get("zdRock", false) or u.has("lanternStored"): return
	var pool: Array = Content.cards_for_unit(str(u.id)).filter(func(c): return int(c.level) == 1 and not c.get("token", false))
	if not pool.is_empty(): gs.VerifiedRules.ChargedPair.store_copy(gs, owner, src, pool[int(gs.next_random() % pool.size())], null)

static func combat_finished(gs, owner: int, src: int, options: Dictionary, defender: Dictionary) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if role(u) == "wuchen": u.zdAttackedTurn = gs.turn_counter
	if not defender.is_empty() and gs.VerifiedRules.OwlInsect.shikigami(defender):
		_rock_store(gs, owner, src)
		for side in gs.players.size():
			var idx: int = gs._unit_index_by_uid(side, str(defender.uid))
			if idx >= 0: _rock_store(gs, side, idx)
	if options.get("zdRetreat", false) and int(u.hp) > 0: gs.VerifiedRules.Movement.move_to(gs, owner, src, 0)

static func combat_dealt(gs, owner: int, src: int, victim: int, idx: int, result: Dictionary, options: Dictionary) -> void:
	if int(options.get("zdWhirl", 0)) <= 0 or int(result.get("dealt", result.get("damage", 0))) <= 0: return
	var half := int(result.get("dealt", result.damage)) / 2
	if half <= 0: return
	for repeat in int(options.zdWhirl):
		gs.resolution_stack.append({"kind": "zd-whirl", "playerIndex": owner, "sourceIndex": src, "victim": victim, "exclude": "avatar-%d" % victim if idx < 0 else str(gs.player(victim).units[idx].uid), "amount": half})

static func _whirl_targets(gs, victim: int, exclude: String) -> Array:
	var ids: Array = []
	if exclude != "avatar-%d" % victim: ids.append("avatar-%d" % victim)
	for u in gs.player(victim).units:
		if str(u.uid) != exclude and int(u.hp) > 0 and not u.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil"): ids.append(str(u.uid))
	return ids

static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type") != WHIRL or int(gs.pending_choice.playerIndex) != owner: return null
	var target: Dictionary = gs._unit_by_uid(gs._all_units(), iid)
	var name := "敌方牌手" if iid.begins_with("avatar-") else str(target.get("name", ""))
	var unit_id := str(gs.player(int(gs.pending_choice.victim)).units[0].id) if iid.begins_with("avatar-") else str(target.get("id", ""))
	var c := {"id":iid,"unitId":unit_id,"name":name,"type":"spell","level":0,"cost":0,"keywords":[],"text":"对%s造成%d点伤害。" % [name,int(gs.pending_choice.amount)]}
	c.currentCardStats = "旋风斩 · 追加%d伤害" % int(gs.pending_choice.amount)
	return c

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var q: Dictionary = gs.pending_choice
	if q.get("type") != WHIRL or int(q.playerIndex) != owner or iid not in q.instanceIds or iid not in _whirl_targets(gs, int(q.victim), str(q.exclude)): return false
	gs.pending_choice = {}; gs.phase = "main"
	gs._record("resolve_divination_choice", {"choice": WHIRL, "instanceId": iid}, owner)
	if iid.begins_with("avatar-"): gs._damage_avatar(int(q.victim), int(q.amount), owner, int(q.sourceIndex))
	else: gs._damage_unit(int(q.victim), gs._unit_index_by_uid(int(q.victim), iid), int(q.amount), owner, int(q.sourceIndex))
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true

static func resolve_frame(gs, f: Dictionary) -> bool:
	var kind := str(f.get("kind", ""))
	if not kind.begins_with("zd-"): return false
	if kind == "zd-defense-ready": gs._offer_attack_responses(f.combat); return true
	var owner := int(f.playerIndex); var src := int(f.sourceIndex); var u: Dictionary = gs.player(owner).units[src]
	match kind:
		"zd-step-draw": gs._draw(owner, 1)
		"zd-draw": gs._draw(owner, int(f.amount))
		"zd-followup-store":
			if active(u): _store_followup(gs, owner, src, f.get("targetId"))
		"zd-repeat":
			if active(u) and not gs.VerifiedRules.Stun.blocks(gs, owner, u): gs._push_card_frames(owner, str(f.card.id), null, f.card, src, 0, true)
		"zd-auto-store":
			if active(u): gs.VerifiedRules.ChargedPair.store_copy(gs, owner, src, f.card, f.get("targetId"))
		"zd-sword":
			if not active(u) or not u.get("formRules", {}).get("zdSword", false): return true
			var pool: Array = gs.player(1-owner).units.filter(func(t): return int(t.hp) > 0 and not t.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(t) and t.has("lanternStored"))
			var amount := 10
			var ids: Array = pool.map(func(t): return str(t.uid))
			if ids.is_empty(): ids = ["avatar-%d" % (1-owner)]; amount = 4
			if amount == 4:
				for t in gs.player(1-owner).units:
					if int(t.hp) > 0 and not t.get("removed", false) and gs.VerifiedRules.OwlInsect.shikigami(t): ids.append(str(t.uid))
			var id := str(ids[int(gs.next_random() % ids.size())]); var old: Dictionary = gs._card_effect_context; gs._card_effect_context = {}
			if id.begins_with("avatar-"): gs._damage_avatar(1-owner, amount, owner, src)
			else: gs._damage_unit(1-owner, gs._unit_index_by_uid(1-owner, id), amount, owner, src)
			gs._card_effect_context = old
		"zd-whirl":
			var ids := _whirl_targets(gs, int(f.victim), str(f.exclude))
			if not ids.is_empty():
				gs.pending_choice = {"type": WHIRL, "playerIndex": owner, "sourceIndex": src, "instanceIds": ids, "heading": "旋 风 斩", "hint": "选择另一个敌方角色，造成%d点伤害。" % int(f.amount), "victim": int(f.victim), "exclude": str(f.exclude), "amount": int(f.amount)}
				gs.phase = "choice"
	return true

static func ai_prepare(gs, owner: int) -> void:
	for index in gs.playable_card_count(owner):
		var inst: Dictionary = gs.card_instance(owner, index); var c: Dictionary = Content.card_def(str(inst.get("definitionId", ""))); var src: int = gs._source_index(owner, c)
		if src < 0 or not c.get("zdRules", false) or not c.get("canCharge", false) or gs.player(owner).units[src].has("lanternStored"): continue
		if not gs.player(owner).has("chargedModes"): gs.player(owner).chargedModes = {}
		gs.player(owner).chargedModes[str(inst.instanceId)] = "charge" if str(c.id) in ["c26403", "c26404", "c26501", "c26506"] else "use"

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != WHIRL: return null
	return resolve_choice(gs, owner, str(gs.pending_choice.instanceIds[0]))

static func score_card(gs, owner: int, card: Dictionary, _target):
	if not card.get("zdRules", false): return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	if card.get("zdAwaken", false): return 62 if not gs.player(owner).units[src].awakened else -100
	return 43 if card.get("chargedSelected", false) else 37

static func marks(gs, _owner: int, u: Dictionary) -> Array:
	var result: Array = []
	if role(u) == "canghai" and u.has("lanternStored"): result.append("蓄力 · +%d力量%s" % [int(u.level), " · 手动释放 · 蓄力效果两次" if u.awakened else ""])
	if int(u.get("zdInstantTurn", -1)) == gs.turn_counter: result.append("身法 · 下一张牌瞬发")
	if int(u.get("zdFreeTurn", -1)) == gs.turn_counter: result.append("两仪身法 · 下一张免鬼火并触发蓄力效果")
	if u.get("zdStepCounter", false): result.append("闪步·振刀 · 被蓄力式神攻击时使其气绝")
	if u.get("formRules", {}).get("zdFierce", false): result.append("免疫非战斗伤害与直接消灭")
	return result
