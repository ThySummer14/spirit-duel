extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const UNIT := "xuan"
const STAR_IDS := ["xuan-star-pivot", "xuan-star-light", "xuan-star-steal", "xuan-star-lock", "xuan-star-retreat", "xuan-star-might", "xuan-star-doom"]
const WISH_IDS := ["xuan-wish-heal", "xuan-wish-revive", "xuan-wish-stars"]
const WISH_CARD := "w13-xuan-93128"
const REALM_CARD := "w13-xuan-93129"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": UNIT})

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false) and not unit.get("removed", false)

static func frame(gs, owner: int, kind: String, fields: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": "xuan-" + kind, "playerIndex": owner}.merged(fields))

static func insert_stars(gs, owner: int, ids: Array, shuffle: bool = false) -> void:
	var deck: Array = gs.player(owner).deck
	for id in ids:
		var inst: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, str(id))
		deck.insert(int(gs.next_random() % (deck.size() + 1)), inst)
	if shuffle and not ids.is_empty(): gs._shuffle(deck)

static func initialize(gs) -> void:
	for owner in 2:
		if source(gs, owner) >= 0: insert_stars(gs, owner, STAR_IDS)

static func drawn(gs, owner: int, inst: Dictionary) -> void:
	var card := Content.card_def(str(inst.definitionId))
	if card.get("unitId") != UNIT or card.has("xuanStar"): return
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if active(unit):
		frame(gs, owner, "draw-star", {"maxLevel": 3 if unit.awakened else int(unit.level)})

static func specialized(gs, owner: int, id: String) -> bool:
	return id in gs.player(owner).get("xuanSpecialized", [])

static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.has("xuanStar") or not specialized(gs, owner, str(card.id)): return card
	var view := card.duplicate(true)
	view.xuanSpecialized = true
	view.text = view.xuanSpecialText
	view.officialText = view.text
	match str(view.xuanStar):
		"light": view.target = "auto"
		"steal": view.keywords.erase("instant")
		"retreat": view.keywords.append("instant")
		"might": view.name = "开阳·武曲"
		"doom": view.level = 2
	return view

static func card_level(gs, owner: int, id: String) -> int:
	var card := Content.card_def(id)
	if card.get("xuanStar") == "doom" and specialized(gs, owner, id): return 2
	return int(card.get("level", 0))

static func deck_matches(gs, owner: int, maximum: int) -> Array:
	var deck: Array = gs.player(owner).deck
	return range(deck.size()).filter(func(i):
		var id := str(deck[i].definitionId)
		return id in STAR_IDS and card_level(gs, owner, id) <= maximum)

static func living_shikigami(gs, unit: Dictionary) -> bool:
	return int(unit.get("hp", 0)) > 0 and gs.VerifiedRules.OwlInsect.shikigami(unit)

static func targets(gs, owner: int, card: Dictionary):
	if not card.has("xuanStar") or card.get("target", "auto") == "auto": return null
	var ids: Array = []
	var sides := [owner, 1-owner] if card.target == "any-unit" else [1-owner]
	for side in sides:
		for unit in gs.player(side).units:
			if not living_shikigami(gs, unit): continue
			if side != owner and (gs.VerifiedRules.Combat.has(unit, "veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			ids.append(unit.uid)
	return ids

static func offered_stars(gs, owner: int) -> Array:
	return STAR_IDS.filter(func(id):
		var opts = targets(gs, owner, describe(gs, owner, Content.card_def(id)))
		return opts == null or not opts.is_empty())

static func fall_pool(gs, owner: int, level: int) -> Array:
	var chosen: Array = []
	var names: Array = []
	for inst in gs.player(owner).hand:
		var id := str(inst.definitionId)
		if id not in STAR_IDS or id in names or card_level(gs, owner, id) > level: continue
		names.append(id)
		chosen.append(inst)
	# Resolve the highest level first, with Open Yang first in its level.
	chosen.sort_custom(func(a, b): return fall_rank(gs, owner, str(a.definitionId)) < fall_rank(gs, owner, str(b.definitionId)))
	return chosen

static func fall_rank(gs, owner: int, id: String) -> int:
	return -card_level(gs, owner, id) * 10 + (0 if id == "xuan-star-might" else STAR_IDS.find(id) + 1)

static func offer(gs, owner: int, type: String, ids: Array, heading: String, hint: String, data: Dictionary = {}) -> void:
	if ids.is_empty(): return
	gs.pending_choice = {"type": "xuan-" + type, "playerIndex": owner, "instanceIds": ids,
		"heading": heading, "hint": hint}.merged(data)
	gs.phase = "choice"

static func choice_card(gs, owner: int, id: String):
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or id not in choice.get("instanceIds", []): return null
	match str(choice.type):
		"xuan-wish": return Content.card_def(id)
		"xuan-echo": return describe(gs, owner, Content.card_def(id))
		"xuan-awaken":
			var result := Content.card_def(id).duplicate(true)
			result.name = "强化%s极星" % result.name
			result.text = result.xuanSpecialText
			return result
		"xuan-target":
			var unit: Dictionary = gs._unit_by_uid(gs._all_units(), id)
			if unit.is_empty(): return null
			var result := Content.unit_def(str(unit.id)).duplicate(true)
			result.merge({"id": id, "unitId": unit.id, "name": unit.name, "type": "unit", "typeLabel": "式神",
				"text": "%s · %d力量 / %d生命" % ["战斗区" if int(unit.front) == 1 else "准备区", int(unit.attack), int(unit.hp)]}, true)
			return result
	return null

static func resolve_choice(gs, owner: int, id: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or id not in choice.get("instanceIds", []): return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": id, "choice": choice.type}, owner)
	var src := source(gs, owner)
	match str(choice.type):
		"xuan-wish":
			var form := Content.card_def(id).duplicate(true)
			form.formRules = {"countdown": 7, "xuanWish": true, "countdownEffects": form.effects}
			form.xuanWishInstance = choice.get("played", {})
			gs._apply_form(owner, src, form)
		"xuan-awaken":
			var p: Dictionary = gs.player(owner)
			if not p.has("xuanSpecialized"): p.xuanSpecialized = []
			p.xuanSpecialized.append(id)
			insert_stars(gs, owner, [id, id])
			gs.VerifiedRules.event(gs, "xuan-specialized", {"player": owner, "card": describe(gs, owner, Content.card_def(id))})
		"xuan-echo":
			var star := describe(gs, owner, Content.card_def(id))
			var options = targets(gs, owner, star)
			if options == null: start_echo(gs, owner, id, null)
			else: offer(gs, owner, "target", options, "星续璇光 · " + str(star.name), "选择这次极星法术的目标。", {"star": id})
		"xuan-target":
			start_echo(gs, owner, str(choice.star), id)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func start_echo(gs, owner: int, id: String, target) -> void:
	var p: Dictionary = gs.player(owner)
	if not p.has("xuanEchoes"): p.xuanEchoes = []
	p.xuanEchoes.append({"id": id, "left": 2})
	cast_star(gs, owner, id, target)

static func cast_star(gs, owner: int, id: String, target = null, inst: Dictionary = {}) -> bool:
	var src := source(gs, owner)
	if src < 0: return false
	var card := describe(gs, owner, Content.card_def(id)).duplicate(true)
	var opts = targets(gs, owner, card)
	if opts != null:
		if opts.is_empty(): return false
		if target == null: target = opts[int(gs.next_random() % opts.size())]
		if target not in opts: return false
	if not inst.is_empty():
		var hand: Array = gs.player(owner).hand
		var index := hand.find_custom(func(i): return i.instanceId == inst.instanceId)
		if index < 0: return false
		card.playedInstance = gs.take_card_instance(owner, index)
		card.usedFromHand = true
	card.paidFire = 0
	card.xuanAutomatic = true
	gs._push_card_frames(owner, id, target, card, src, 0, true)
	return true

static func active_realm(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(r): return r.cardId == REALM_CARD and int(r.hp) > 0)

static func announced(gs, owner: int, card: Dictionary) -> void:
	if not Content.is_spell(card) or source(gs, owner) < 0: return
	var p: Dictionary = gs.player(owner)
	if int(p.get("xuanSpellTurn", -1)) != gs.turn_counter:
		p.xuanSpellTurn = gs.turn_counter
		p.xuanSpellCount = 0
	p.xuanSpellCount += 1
	if active_realm(gs, owner) and int(p.xuanSpellCount) in [3, 5, 7]:
		frame(gs, owner, "realm-benefit", {"count": int(p.xuanSpellCount)})

static func completed(gs, owner: int, card: Dictionary, target_id) -> void:
	if not card.has("xuanStar"): return
	var p: Dictionary = gs.player(owner)
	if int(p.get("xuanDoubleTurn", -1)) == gs.turn_counter:
		var copies := int(p.get("xuanDoubleCount", 0))
		var context: Dictionary = gs._card_effect_context
		frame(gs, owner, "repeat", {"card": card, "target": target_id, "copies": copies, "context": context})
	star_consequence(gs, owner)

static func star_consequence(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = p.units[src]
	if active(unit) and int(p.get("xuanChildTurn", -1)) == gs.turn_counter:
		for i in int(p.get("xuanChildCount", 0)): frame(gs, owner, "remote")
	if unit.get("formRules", {}).get("xuanWish", false):
		gs.VerifiedRules.reduce_countdown(gs, owner, src, 1, owner)

static func deploy_space_time(gs, owner: int) -> void:
	for realm in gs.player(owner).realms.duplicate():
		if realm.get("spaceTime", false) or realm.get("nativeRealm") == "space-time":
			gs.VerifiedRules.Huang.destroy(gs, owner, realm, "被新的时空替换")

static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var echoes: Array = p.get("xuanEchoes", []).duplicate()
	for i in range(echoes.size() - 1, -1, -1):
		var echo: Dictionary = echoes[i]
		echo.left -= 1
		frame(gs, owner, "echo-cast", {"id": echo.id})
	if not echoes.is_empty(): p.xuanEchoes = echoes.filter(func(e): return int(e.left) > 0)

static func expire(gs) -> void:
	for p in gs.players:
		for unit in p.units:
			if clear_temporary(unit): gs._recalc(unit)

static func clear_temporary(unit: Dictionary) -> bool:
	var changed := unit.erase("xuanPower")
	changed = unit.erase("xuanHealth") or changed
	changed = unit.erase("xuanPierce") or changed
	return changed

static func resolve_frame(gs, item: Dictionary) -> bool:
	var kind := str(item.get("kind", ""))
	if not kind.begins_with("xuan-"): return false
	var owner := int(item.playerIndex)
	var src := source(gs, owner)
	var p: Dictionary = gs.player(owner)
	match kind:
		"xuan-draw-star":
			gs._draw(owner, 1, -1, {"xuanMaxLevel": int(item.maxLevel)})
		"xuan-draw-copy":
			var names: Array = item.cards.map(func(c): return c.definitionId)
			insert_stars(gs, owner, names, true)
		"xuan-echo-cast":
			if src >= 0 and active(p.units[src]): cast_star(gs, owner, str(item.id))
		"xuan-fall-cast":
			if src >= 0 and active(p.units[src]): cast_star(gs, owner, str(item.instance.definitionId), null, item.instance)
		"xuan-remote":
			if src >= 0 and active(p.units[src]) and not gs.VerifiedRules.Stun.blocks(gs, owner, p.units[src]):
				gs._resolve_combat(owner, src, 0, false, true, false, false)
		"xuan-pivot-followup":
			Fate.reveal_top(gs, owner, owner)
			gs._draw(owner, 1)
		"xuan-realm-benefit":
			realm_benefit(gs, owner, src, int(item.count))
		"xuan-repeat":
			if int(item.copies) > 0 and src >= 0:
				if int(item.copies) > 1: frame(gs, owner, "repeat", {"card": item.card, "target": item.target, "copies": int(item.copies)-1, "context": item.context})
				frame(gs, owner, "star-consequence")
				var target: Dictionary = gs._unit_by_uid(gs._all_units(), item.target) if item.target != null else {}
				var previous: Dictionary = gs._card_effect_context
				gs._card_effect_context = item.context
				resolve_action(gs, owner, src, item.card, item.card.effects[0], target)
				gs._card_effect_context = previous
		"xuan-star-consequence": star_consequence(gs, owner)
		"xuan-retreat":
			var side := int(item.targetOwner)
			var idx: int = gs._unit_index_by_uid(side, item.uid)
			if idx >= 0: gs.VerifiedRules.Movement.move_to(gs, side, idx, 0)
	return true

static func realm_benefit(gs, owner: int, src: int, count: int) -> void:
	gs.VerifiedRules.event(gs, "xuan-realm", {"player": owner, "count": count})
	match count:
		3: gs._draw(owner, 1)
		5: gs._set_fire(owner, int(gs.player(owner).energy) + 1)
		7:
			for i in gs.player(1-owner).units.size():
				if int(gs.player(1-owner).units[i].hp) > 0: gs._damage_unit(1-owner, i, 3, owner, src)
			gs._damage_avatar(1-owner, 3, owner, src)

static func wish_result(gs, owner: int, src: int, card: Dictionary) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if unit.get("form", {}).get("cardId") != card.id: return
	match str(card.xuanWish):
		"heal": gs._heal_avatar(owner, 12)
		"revive":
			for i in gs.player(owner).units.size():
				gs.VerifiedRules.YanmieTrio.revive(gs, owner, i)
		"stars": insert_stars(gs, owner, STAR_IDS)
	gs.VerifiedRules.Forms.remove(gs, owner, src, "愿望实现")
	var original: Dictionary = card.get("xuanWishInstance", {})
	if original.is_empty(): original = gs.VerifiedRules.Insight.instance(gs, owner, WISH_CARD)
	gs.VerifiedRules.Baize.put_hand(gs, owner, original)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("xuan-"): return false
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	match action:
		"xuan-child":
			if int(p.get("xuanChildTurn", -1)) != gs.turn_counter: p.xuanChildCount = 0
			p.xuanChildTurn = gs.turn_counter
			p.xuanChildCount += 1
		"xuan-double":
			if int(p.get("xuanDoubleTurn", -1)) != gs.turn_counter: p.xuanDoubleCount = 0
			p.xuanDoubleTurn = gs.turn_counter
			p.xuanDoubleCount += 1
		"xuan-draw":
			var drawn_stars: Array = []
			frame(gs, owner, "draw-copy", {"cards": drawn_stars})
			gs._draw(owner, 2, -1, {"xuanMaxLevel": 3, "xuanDrawn": drawn_stars})
		"xuan-fall":
			var pool := fall_pool(gs, owner, int(unit.level))
			for i in range(pool.size()-1, -1, -1): frame(gs, owner, "fall-cast", {"instance": pool[i]})
		"xuan-wish":
			offer(gs, owner, "wish", WISH_IDS, "七星之愿", "选择倒计时结束时实现的愿望。", {"played": card.get("playedInstance", {})})
		"xuan-realm": gs._deploy_realm(owner, card)
		"xuan-echo":
			offer(gs, owner, "echo", offered_stars(gs, owner), "星续璇光", "选择立即打出、并在下两个己方回合再次打出的极星。")
		"xuan-awaken":
			if not unit.awakened: gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
			else: gs._grow_unit(unit, 1, 1)
			var ids := STAR_IDS.filter(func(id): return not specialized(gs, owner, id))
			offer(gs, owner, "awaken", ids, "觉醒·璇", "选择此前未专精的极星，专精后两张同名牌置入牌库。")
		"xuan-wish-heal", "xuan-wish-revive", "xuan-wish-stars":
			wish_result(gs, owner, src, card)
		_: resolve_star(gs, owner, src, card, target)
	return true

static func resolve_star(gs, owner: int, src: int, card: Dictionary, target: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	var enemy: Dictionary = gs.player(1-owner)
	var unit: Dictionary = p.units[src]
	var special := bool(card.get("xuanSpecialized", false))
	var target_enemy: int = gs._unit_index_by_uid(1-owner, target.uid) if not target.is_empty() else -1
	match str(card.get("xuanStar", "")):
		"pivot":
			var followup := {"kind": "xuan-pivot-followup", "playerIndex": owner}
			Fate.offer(gs, owner, owner, followup if special else {})
		"light":
			if special:
				var indices: Array = [gs.front_index(1-owner)]
				for i in [1, 2]:
					if i < enemy.units.size() and i not in indices: indices.append(i)
				for i in indices:
					if i >= 0 and living_shikigami(gs, enemy.units[i]): gs._damage_unit(1-owner, i, 4, owner, src)
			elif target_enemy >= 0: gs._damage_unit(1-owner, target_enemy, 4, owner, src)
		"steal":
			if target_enemy < 0 or int(target.hp) <= 0: return
			var amount := mini(maxi(0, int(target.attack)), 2 if special else 1)
			target.xuanPower = int(target.get("xuanPower", 0)) - amount
			unit.xuanPower = int(unit.get("xuanPower", 0)) + amount
			gs._recalc(target)
			gs._recalc(unit)
		"lock":
			if target_enemy < 0 or int(target.hp) <= 0: return
			gs.VerifiedRules.Stun.apply(gs, 1-owner, target_enemy, 1, owner, src)
			if special:
				var options := range(enemy.hand.size()).filter(func(i): return target.id in Content.card_unit_ids(Content.card_def(str(enemy.hand[i].definitionId))))
				if not options.is_empty(): gs.discard_hand_card(1-owner, options[int(gs.next_random() % options.size())])
		"retreat":
			if target.is_empty(): return
			var side := 1-owner if target_enemy >= 0 else owner
			var idx: int = gs._unit_index_by_uid(side, target.uid)
			if idx < 0 or int(target.hp) <= 0: return
			frame(gs, owner, "retreat", {"targetOwner": side, "uid": target.uid})
			gs._damage_unit(side, idx, 3, owner, src)
		"might":
			var amount := 3 if special else 2
			unit.xuanPower = int(unit.get("xuanPower", 0)) + amount
			unit.xuanHealth = int(unit.get("xuanHealth", 0)) + amount
			if special: unit.xuanPierce = true
			gs._recalc(unit)
		"doom":
			var options := doom_targets(gs, 1-owner)
			if not options.is_empty():
				gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1-owner, options[int(gs.next_random() % options.size())], card)

static func doom_targets(gs, victim: int) -> Array:
	var units: Array = gs.player(victim).units
	return range(units.size()).filter(func(i): return living_shikigami(gs, units[i]))

static func score(gs, owner: int, card: Dictionary, target_id):
	if not card.get("xuanRules", false): return null
	var p: Dictionary = gs.player(owner)
	var idx := source(gs, owner)
	if idx < 0: return -100
	var count := fall_pool(gs, owner, int(p.units[idx].level)).size()
	var child: bool = int(p.get("xuanChildTurn", -1)) == gs.turn_counter
	match str(card.effect):
		"xuan-draw": return 35 + deck_matches(gs, owner, 3).size() * 2
		"xuan-child": return 32 + count * 10
		"xuan-fall": return -15 if count == 0 else 40 + count * 6 + (18 if child else 0)
		"xuan-double": return 20 + count * 9 + (12 if child else 0)
		"xuan-wish": return 49 if p.units[idx].form.is_empty() else 18
		"xuan-awaken": return 67 if not p.units[idx].awakened else 49
		"xuan-realm": return 42 if not active_realm(gs, owner) else 7
		"xuan-echo": return 60
		"xuan-might": return 60 if child else 27
		"xuan-light", "xuan-retreat", "xuan-steal", "xuan-lock":
			return target_score(gs, owner, card, target_id) + (14 if child else 0)
		"xuan-doom": return 67 + (14 if child else 0) if not doom_targets(gs, 1-owner).is_empty() else -15
	return 38 + (14 if child else 0)

static func target_score(gs, owner: int, card: Dictionary, id) -> int:
	if id == null: return 54
	var enemy_idx: int = gs._unit_index_by_uid(1-owner, id)
	if enemy_idx < 0: return -50
	var unit: Dictionary = gs.player(1-owner).units[enemy_idx]
	var value := 34 + int(unit.level) * 3 + int(unit.attack)
	if card.get("xuanStar") in ["retreat", "light"]:
		var damage := 3 if card.xuanStar == "retreat" else 4
		if int(unit.hp) + int(unit.shield) <= damage: value += 20
		elif card.xuanStar == "retreat" and int(unit.front) == 1: value += 10
	if card.get("xuanStar") == "lock" and int(unit.frozen) > 0: value -= 18
	return value

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if int(choice.get("playerIndex", -1)) != owner or not str(choice.get("type", "")).begins_with("xuan-"): return null
	var ids: Array = choice.instanceIds
	match str(choice.type):
		"xuan-wish":
			if int(gs.player(owner).avatarHp) <= 22: return WISH_IDS[0]
			if gs.player(owner).units.any(func(u): return gs.VerifiedRules.YanmieTrio.can_revive(gs, owner, u)): return WISH_IDS[1]
			return WISH_IDS[2]
		"xuan-awaken", "xuan-echo":
			for id in ["xuan-star-doom", "xuan-star-might", "xuan-star-light", "xuan-star-lock"]:
				if choice.type == "xuan-echo" and id == "xuan-star-doom" and doom_targets(gs, 1-owner).is_empty(): continue
				if id in ids: return id
		"xuan-target":
			var card := describe(gs, owner, Content.card_def(str(choice.star)))
			var ranked := ids.duplicate()
			ranked.sort_custom(func(a, b): return target_score(gs, owner, card, a) > target_score(gs, owner, card, b))
			return ranked.front()
	return ids.front()
