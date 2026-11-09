class_name TreasureRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Factions := preload("res://scripts/faction_rules.gd")
const SMALL := "daorenshen-treasure"
const LARGE := "daorenshen-great-treasure"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": "daorenshen"})

static func gain(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0 or gs.winner >= 0: return
	var p: Dictionary = gs.player(owner)
	var id := LARGE if p.units[src].awakened else SMALL
	var iid := "%s-treasure-%d" % [p.id, gs.next_card_id]
	gs.next_card_id += 1
	if p.hand.size() >= int(gs.rules.maxHandSize):
		gs._log("手牌已满，「%s」被烧毁。" % Content.card_def(id).name, gs.TONE_DANGER)
		return
	p.hand.append({"instanceId": iid, "definitionId": id})
	gs.VerifiedRules.Glutton.mark_hand(gs, owner)
	gs._log("%s 获得「%s」。" % [p.name, Content.card_def(id).name], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "treasure-gained", {"player": owner, "uid": p.units[src].uid, "instanceId": iid, "card": Content.card_def(id)})

static func avatar_damaged(gs, victim: int, owner: int, src: int, amount: int, combat: bool) -> void:
	if not combat or amount <= 0 or owner < 0 or owner == victim or src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if int(unit.level) < 1 or not Content.runtime_unit_def(unit).get("treasureRules", false) or int(unit.get("treasureDamageTurn", -1)) == gs.turn_counter: return
	unit.treasureDamageTurn = gs.turn_counter
	gain(gs, owner)

static func discarded(gs, owner: int, inst: Dictionary) -> void:
	if inst.get("definitionId") == "c62606": gain(gs, owner)

static func discount(gs, owner: int, card: Dictionary) -> int:
	if card.get("neutralFood", false) or card.get("neutralEssence", false) or card.get("neutral", false) or str(card.get("unitId", "")).is_empty(): return 0
	var p: Dictionary = gs.player(owner)
	if int(p.get("treasureDiscountTurn", -1)) != gs.turn_counter: return 0
	if int(card.get("printedLevel", card.get("level", 0))) == 1 and int(p.get("treasureFreeLevelOne", 0)) > 0: return 1
	return 2 if int(p.get("treasureFreeAny", 0)) > 0 else 0

static func pay(gs, owner: int, payment: Dictionary) -> void:
	var tier := int(payment.get("treasureDiscount", 0))
	if tier == 0: return
	var key := "treasureFreeLevelOne" if tier == 1 else "treasureFreeAny"
	var p: Dictionary = gs.player(owner)
	p[key] = maxi(0, int(p.get(key, 0)) - 1)

static func grant_discount(gs, owner: int, large: bool) -> void:
	var p: Dictionary = gs.player(owner)
	if int(p.get("treasureDiscountTurn", -1)) != gs.turn_counter:
		p.treasureDiscountTurn = gs.turn_counter
		p.treasureFreeLevelOne = 0
		p.treasureFreeAny = 0
	var key := "treasureFreeAny" if large else "treasureFreeLevelOne"
	p[key] = int(p[key]) + 1

static func living_targets(gs, owner: int, random: bool = false) -> Array:
	return gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and (random or not gs.VerifiedRules.Combat.has(u, "veil")))

static func damage_targets(gs, owner: int) -> Array:
	var enemy := 1-owner
	var units: Array = gs.player(enemy).units
	var ids := units.filter(func(u): return int(u.hp) > 0 and not u.get("removed", false) and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))
	if not gs.VerifiedRules.PipeFox.avatar_veil(gs, enemy): ids.append("avatar-%d" % enemy)
	return ids

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("treasureRules", false): return card
	var view := card.duplicate(true)
	var used: bool = int(gs.player(owner).get("treasureUseTurn", -1)) == gs.turn_counter
	match str(card.id):
		"c62601":
			view.combatOption.lethal = used
			if used: view.keywords.append("lethal")
		"c62605":
			view.combatOption.immuneCombat = used
			if used: view.currentCardStats = "增强：免疫战斗伤害"
		"c62608":
			var src := source(gs, owner)
			if src >= 0 and int(gs.player(owner).units[src].level) < int(card.level):
				view.printedLevel = card.level
				view.level = 1
				view.keywords.append("instant")
				view.treasureTrick = true
				view.currentCardStats = "戏法：作为财宝使用"
	return view

static func targets(gs, owner: int, card: Dictionary):
	if card.get("treasureRules", false) and card.get("target") == "enemy-unit":
		return living_targets(gs, owner).map(func(u): return u.uid)
	return null

static func announced(gs, owner: int, src: int, card: Dictionary) -> void:
	if not card.get("treasureRules", false): return
	var id := str(card.id)
	if id != SMALL and id != LARGE and not card.get("treasureTrick", false): return
	var p: Dictionary = gs.player(owner)
	p.treasureUseTurn = gs.turn_counter
	if id == LARGE: return
	p.treasureUses = int(p.get("treasureUses", 0)) + 1
	if int(p.units[src].hp) > 0 and p.units[src].get("formRules", {}).get("treasureDay", false):
		gs.VerifiedRules.HairPower.give(gs, owner, src, mini(3, int(p.treasureUses)))

static func _queue(gs, kind: String, owner: int, src: int, large: bool, context: Dictionary) -> void:
	gs.resolution_stack.append({"kind": "treasure-" + kind, "playerIndex": owner, "sourceIndex": src, "large": large, "context": context})

static func _choice(gs, kind: String, frame: Dictionary, ids: Array, hint: String, zone: String = "") -> void:
	if ids.is_empty(): return
	gs.pending_choice = frame.duplicate(true)
	gs.pending_choice.merge({"type": "treasure-" + kind, "instanceIds": ids, "zone": zone, "heading": "巨额财宝" if frame.large else "财宝", "title": hint, "hint": hint}, true)
	gs.phase = "choice"

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("treasure-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	var large := bool(frame.get("large", false))
	match kind:
		"treasure-gain": gain(gs, owner)
		"treasure-draw":
			if not large: _queue(gs, "discard", owner, src, false, {})
			gs._draw(owner, 2 if large else 1)
		"treasure-discard":
			_choice(gs, "discard", frame, gs.player(owner).hand.map(func(c): return str(c.instanceId)), "选择一张手牌弃掉", "hand")
		"treasure-discount": grant_discount(gs, owner, large)
		"treasure-damage":
			_choice(gs, "target", frame, damage_targets(gs, owner), "选择一个敌方角色，造成%d点伤害" % (4 if large else 1))
		"treasure-attack":
			var unit: Dictionary = gs.player(owner).units[src]
			if int(unit.hp) <= 0: return true
			var pool := living_targets(gs, owner, true)
			var restriction = gs.VerifiedRules.Guishihei.attack_targets(gs, owner, src)
			if restriction != null: pool = pool.filter(func(u): return restriction.has(u.uid))
			if pool.is_empty(): return true
			var target: Dictionary = pool[int(gs.next_random() % pool.size())]
			if int(frame.remaining) > 1:
				var next := frame.duplicate(true)
				next.remaining = int(frame.remaining) - 1
				gs.resolution_stack.append(next)
			gs._resolve_combat(owner, src, 0, false, false, false, false, target.uid, Factions.get_faction(target) == "紫岩", {"pursuit": true, "immuneCombat": true})
		_: return false
	return true

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or not choice.get("instanceIds", []).has(iid): return false
	var src := int(choice.sourceIndex)
	var kind := str(choice.type)
	var large := bool(choice.large)
	var index := -1
	if kind == "treasure-discard":
		index = gs.player(owner).hand.find_custom(func(inst): return str(inst.instanceId) == iid)
		if index < 0: return false
	elif kind == "treasure-target":
		if iid not in damage_targets(gs, owner): return false
		index = gs._unit_index_by_uid(1-owner, iid)
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": kind, "card": LARGE if large else SMALL}, owner)
	gs.pending_choice = {}
	gs.phase = "main"
	match kind:
		"treasure-mode": _queue(gs, iid, owner, src, large, choice.context)
		"treasure-discard": gs.discard_hand_card(owner, index)
		"treasure-target":
			var old: Dictionary = gs._card_effect_context
			gs._card_effect_context = choice.context
			var amount := 4 if large else 1
			if index < 0: gs._damage_avatar(1-owner, amount, owner, src)
			else: gs._damage_unit(1-owner, index, amount, owner, src)
			gs._card_effect_context = old
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func choice_card(gs, owner: int, iid: String):
	var choice: Dictionary = gs.pending_choice
	if not str(choice.get("type", "")).begins_with("treasure-") or int(choice.playerIndex) != owner or not choice.instanceIds.has(iid): return null
	var large := bool(choice.large)
	if choice.type == "treasure-mode":
		var names := {"draw": "抽牌", "discount": "免鬼火", "damage": "造成伤害"}
		var text := {"draw": "抽两张牌。" if large else "抽一张牌，然后弃一张手牌。", "discount": "本回合下一张非中立牌不消耗鬼火。" if large else "本回合下一张1勾非中立牌不消耗鬼火。", "damage": "对一个敌方角色造成%d点伤害。" % (4 if large else 1)}
		return {"id": iid, "unitId": "daorenshen", "name": names[iid], "type": "spell", "typeLabel": "财宝选项", "text": text[iid]}
	if choice.type == "treasure-target":
		var idx: int = gs._unit_index_by_uid(1-owner, iid)
		var unit: Dictionary = {} if idx < 0 else gs.player(1-owner).units[idx]
		var hp := int(gs.player(1-owner).avatarHp) if unit.is_empty() else int(unit.hp)
		return {"id": iid, "unitId": unit.get("id", "daorenshen"), "name": unit.get("name", "敌方牌手"), "type": "spell", "typeLabel": "财宝目标", "text": "当前%d生命。受到%d点伤害。" % [hp, 4 if large else 1]}
	return null

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if not str(choice.get("type", "")).begins_with("treasure-") or int(choice.playerIndex) != owner: return null
	var ids: Array = choice.instanceIds
	var best := str(ids[0])
	match str(choice.type):
		"treasure-mode":
			if int(gs.player(1-owner).avatarHp) <= (4 if choice.large else 1): best = "damage"
			elif gs.player(owner).deck.size() <= (2 if choice.large else 1): best = "discount"
		"treasure-discard":
			for inst in gs.player(owner).hand:
				if inst.definitionId == "c62606":
					best = str(inst.instanceId)
					break
		"treasure-target":
			if ids.has("avatar-%d" % (1-owner)): best = "avatar-%d" % (1-owner)
	return resolve_choice(gs, owner, best)

static func realm_trigger(gs, owner: int) -> void:
	_queue(gs, "gain", owner, -1, false, {})
	gs._draw(owner, 1, 1)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
	if not card.get("treasureRules", false): return false
	var unit: Dictionary = gs.player(owner).units[src]
	var context: Dictionary = gs._card_effect_context.duplicate(true)
	match str(effect.get("action", "")):
		"treasure-claw":
			var idx: int = gs._unit_index_by_uid(1-owner, target_id)
			if idx >= 0: gs._damage_unit(1-owner, idx, 3, owner, src)
			if not gs.VerifiedRules.RedPurple.faction_units(gs, owner, "青岚", true).is_empty(): gain(gs, owner)
		"treasure-form":
			gs._apply_form(owner, src, card)
			if card.id == "c62603": gain(gs, owner)
			else: unit.swift = true
		"treasure-realm":
			gs._deploy_realm(owner, card)
			realm_trigger(gs, owner)
		"treasure-awaken":
			gs._awaken(owner, src, card, {"attack": 0, "hp": 0})
			gs._grant_unit_armor(unit, 2)
			gs._resolve_combat(owner, src, 0, false, false, false, false, null, false, {"directAvatar": true, "combatCard": card})
		"treasure-tail":
			if not card.get("treasureTrick", false):
				gs.resolution_stack.append({"kind": "treasure-attack", "playerIndex": owner, "sourceIndex": src, "remaining": 3})
				return true
			_use(gs, owner, src, false, context)
		"treasure-use": _use(gs, owner, src, card.id == LARGE, context)
		_: return false
	return true

static func _use(gs, owner: int, src: int, large: bool, context: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not large and int(unit.hp) > 0 and unit.get("formRules", {}).get("treasureNight", false):
		for kind in ["damage", "discount", "draw"]: _queue(gs, kind, owner, src, false, context)
	else:
		_choice(gs, "mode", {"playerIndex": owner, "sourceIndex": src, "large": large, "context": context}, ["draw", "discount", "damage"], "选择一项财宝效果")

static func score_card(gs, owner: int, card: Dictionary, target_id):
	if not card.get("treasureRules", false): return null
	match str(card.id):
		SMALL, LARGE: return 70 if gs.instant_available(owner) else 42
		"c62602":
			var target: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, target_id)
			return 70 if int(target.get("hp", 99)) <= 3 else 45
		"c62607": return 90
		"c62608": return 68 if not card.get("treasureTrick", false) else 56
		_: return 57
