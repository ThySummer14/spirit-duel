extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Cards := preload("res://scripts/restored_card_choices.gd")
const FEATHER := "huangjinyu"
const FIRE_REALM := "coop-middle-rekindle"
const SUN_DOLL := "晴天娃娃"
const PHOENIX := "fenghuanghuo"
const LIGHT := "qingxingdeng"
const YIJIN := "yijin-zhentian"
const ZHEN := "zhen"
const BONE := "huangkulou"
const BUNNY := "shantu"
const FORTUNE := "zuofutongzi"
const WIND := "yimulian"
const MUSIC := "yaoginshi"


static func source(gs, owner: int, id: String) -> int:
	return gs._source_index(owner, {"unitId": id})


static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("removed", false)


static func targets(gs, owner: int, card: Dictionary) -> Variant:
	var kind := str(card.get("target", "auto"))
	if kind != "coop-middle-sunny-ally" and kind != "coop-middle-basic-ally": return null
	var out: Array = []
	for u in gs.player(owner).units:
		if kind == "coop-middle-sunny-ally":
			if u.id == card.unitId or int(u.hp) <= 0 or u.get("removed", false) or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
		elif not gs.VerifiedRules.YanmieTrio.shikigami(u): continue
		out.append(str(u.uid))
	return out


static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.get("id") == FEATHER and inst.get("coopMiddleFeather", false):
		var enhanced := card.duplicate(true)
		enhanced.coopMiddleFeather = true
		enhanced.allowKnockedSource = true
		enhanced.value = int(enhanced.get("value", 2)) + 1
		enhanced.effects[0].value = int(enhanced.effects[0].value) + 1
		enhanced.text += "\n鎏金幻羽：气绝时可用，伤害+1。使用后，以津真天和鸩的气绝倒计时各-1。"
		return enhanced
	if card.get("id") != "c127130": return card
	var out := card.duplicate(true)
	var faces: Array = out.get("coopFaces", [out])
	var count: int = gs.VerifiedRules.Fortune.sixes(gs, owner)
	for face in faces:
		if face.get("unitId") != BUNNY: continue
		face.enhanced = count >= 3
		face.text += "\n本局已投出%d次6点。" % count
	return out


static func _bond_countdown(gs, owner: int, card: Dictionary, id: String) -> void:
	if not card.get("coopBond", false): return
	var idx := source(gs, owner, id)
	if idx >= 0: gs.VerifiedRules.Countdown.change(gs, owner, idx, -2, owner)


static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id) -> bool:
	var action := str(effect.get("action", ""))
	if not action.begins_with("coop-middle-"): return false
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[src]
	var bond := bool(card.get("coopBond", false))
	match action:
		"coop-middle-feather":
			for inst in p.hand:
				if inst.definitionId == FEATHER: inst.coopMiddleFeather = true
			_bond_countdown(gs, owner, card, ZHEN)
		"coop-middle-zhen-bond":
			_bond_countdown(gs, owner, card, YIJIN)
		"coop-middle-phoenix":
			if int(unit.get("coopMiddlePhoenixTurn", -1)) != gs.turn_counter:
				unit.coopMiddlePhoenixTurn = gs.turn_counter
				unit.coopMiddlePhoenixNames = []
			if bond: Cards.give(gs, owner, "mingdeng")
		"coop-middle-lamp-entry":
			if bond: Cards.give(gs, owner, "c12404")
		"coop-middle-bunny":
			if gs.VerifiedRules.Fortune.sixes(gs, owner) >= 3: gs.player(1-owner).coopMiddleTax = true
			var fortune := source(gs, owner, FORTUNE)
			if bond and fortune >= 0 and gs.VerifiedRules.Light.roll(gs, owner, 4, 6, fortune):
				var enemy: Dictionary = gs.player(1-owner)
				enemy.coopMiddleZero = true
				for foe in enemy.units: gs._recalc(foe)
		"coop-middle-fortune":
			# Revivals and their triggers must finish before any chosen form enters.
			gs.resolution_stack.append({"kind": "coop-middle-random-forms", "playerIndex": owner})
			if gs.VerifiedRules.Light.roll(gs, owner, 4, 6, src):
				for idx in range(p.units.size() - 1, -1, -1):
					gs.resolution_stack.append({"kind": "coop-middle-revive", "playerIndex": owner, "sourceIndex": idx})
		"coop-middle-draw-rabbit-win":
			if bond:
				var ids: Array = p.deck.filter(func(inst): return inst.definitionId == "c12710")
				if not ids.is_empty():
					gs._draw(owner, 1, -1, {"drawInstanceId": ids[gs.next_random() % ids.size()].instanceId})
		"coop-middle-smoke":
			var level := int(unit.level)
			if level < 1 or level > 3: return true
			var expected_uid := "%s:smoke-clone-%d" % [p.id, gs.next_card_id]
			gs.resolution_stack.append({"kind": "coop-middle-smoke-cast", "playerIndex": owner, "level": level, "summonerUid": unit.uid, "targetUid": expected_uid})
			gs.VerifiedRules.SunSmoke.summon(gs, owner, src)
		"coop-middle-smoke-bond":
			if bond:
				for i in p.units.size(): gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, i, 1)
		"coop-middle-sunny":
			if target.is_empty() or int(target.hp) <= 0: return true
			if not target.get("coopMiddleSunny", false):
				target.coopMiddleSunny = true
				gs.VerifiedRules.event(gs, "charm-attached", {"player": owner, "uid": target.uid, "charm": SUN_DOLL, "sourceUid": unit.uid})
			if bond: target.coopMiddleImmuneTurn = gs.turn_counter
		"coop-middle-bone-destroy":
			gs.VerifiedRules.Panguan.destroy(gs, owner, src, owner, src, card)
		"coop-middle-bone-timer":
			if int(unit.hp) <= 0 and int(unit.knockout) > 0: unit.knockout = 1
			if bond: Cards.give(gs, owner, "c17007")
		"coop-middle-yellow-damage":
			gs._deferred_winner_checks += 1
			gs._damage_avatar(owner, 4, owner, src)
			gs._damage_avatar(1-owner, 4, owner, src)
			gs._deferred_winner_checks -= 1
			gs._check_winner()
		"coop-middle-yellow-shuffle":
			if target.is_empty(): return true
			var pool := _exclusive_cards(target).filter(func(c): return int(c.level) == 1)
			# Cards may repeat when a shikigami has fewer than four level-one
			# cards. Choose each independently from the collectible set.
			if not pool.is_empty():
				for i in 4:
					var chosen: Dictionary = pool[gs.next_random() % pool.size()]
					p.deck.append(gs.VerifiedRules.Insight.instance(gs, owner, str(chosen.id)))
				gs._shuffle(p.deck)
			if bond: p.coopMiddleYellow = true
		"coop-middle-wind":
			var history: Dictionary = unit.get("coopMiddleWindHistory", {})
			var cards := history.values()
			for i in range(cards.size() - 1, -1, -1):
				var remembered: Dictionary = cards[i]
				gs.VerifiedRules.Forms.queue_trigger(gs, owner, src, {"card": remembered.card, "triggers": maxi(0, int(remembered.count) - 1)}, "风韵雅乐")
		"coop-middle-wind-bond":
			if bond:
				var awakenings := Content.cards_for_unit(MUSIC).filter(func(c): return c.get("awakening", false) and not c.get("skin", false))
				_give_random(gs, owner, awakenings)
		"coop-middle-music":
			p.coopMiddleMusic = int(p.get("coopMiddleMusic", 0)) + 1
			if bond:
				var idx := source(gs, owner, WIND)
				if idx >= 0: _give_random(gs, owner, _exclusive_cards(p.units[idx], "form"))
		_: return false
	return true


static func _exclusive_cards(unit: Dictionary, kind: String = "") -> Array:
	return Content.cards_for_unit(str(unit.id)).filter(func(c):
		if c.get("type") == "coop" or c.get("token", false) or c.get("skin", false): return false
		return kind.is_empty() or c.get("type") == kind
	)


static func _give_random(gs, owner: int, pool: Array) -> void:
	if not pool.is_empty(): Cards.give(gs, owner, str(pool[gs.next_random() % pool.size()].id))


static func _cast(gs, owner: int, src: int, card: Dictionary) -> void:
	var target = gs.VerifiedRules.SpellReplay.random_target(gs, owner, card)
	if card.get("target", "auto") != "auto" and target == null: return
	gs._push_card_frames(owner, str(card.id), target, card, src, 0, true)


static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("coop-middle-"): return false
	var owner := int(frame.playerIndex)
	var p: Dictionary = gs.player(owner)
	var src := int(frame.get("sourceIndex", -1))
	match kind:
		"coop-middle-revive":
			gs.VerifiedRules.YanmieTrio.revive(gs, owner, src)
		"coop-middle-random-forms":
			for idx in range(p.units.size() - 1, -1, -1):
				if active(p.units[idx]) and gs.VerifiedRules.OwlInsect.shikigami(p.units[idx]):
					gs.resolution_stack.append({"kind": "coop-middle-form", "playerIndex": owner, "sourceIndex": idx})
		"coop-middle-form":
			var u: Dictionary = p.units[src]
			if not active(u): return true
			var pool := _exclusive_cards(u, "form")
			if not pool.is_empty(): _cast(gs, owner, src, pool[gs.next_random() % pool.size()].duplicate(true))
		"coop-middle-smoke-cast":
			var clone := int(gs._unit_index_by_uid(owner, frame.get("targetUid", "")))
			if clone < 0 or not active(p.units[clone]) or p.units[clone].get("summonerUid") != frame.summonerUid: return true
			var id: String = ["c16401", "c16403", "c16408"][int(frame.level)-1]
			var spell := Content.card_def(id).duplicate(true)
			spell.smokeBurstSelected = true
			_cast(gs, owner, clone, spell)
		"coop-middle-phoenix-cast":
			var u: Dictionary = p.units[src]
			if not active(u): return true
			var pool := _exclusive_cards(u, "spell").filter(func(c):
				if c.get("awakening", false) or int(c.level) > int(frame.maxLevel): return false
				return c.get("target", "auto") == "auto" or not gs.valid_targets(owner, c).is_empty()
			)
			if not pool.is_empty(): _cast(gs, owner, src, pool[gs.next_random() % pool.size()].duplicate(true))
		"coop-middle-music-tick":
			var unit: Dictionary = p.units[src]
			gs.VerifiedRules.Countdown.change(gs, owner, src, -2 if int(unit.hp) <= 0 else -1, owner)
		_: return false
	return true


static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if src < 0: return
	_sunny_trigger(gs, owner, src)
	if not Content.is_spell(card): return
	var phoenix := source(gs, owner, PHOENIX)
	if phoenix < 0 or phoenix == src: return
	var u: Dictionary = gs.player(owner).units[phoenix]
	if not active(u) or int(u.get("coopMiddlePhoenixTurn", -1)) != gs.turn_counter: return
	var name := str(card.get("name", ""))
	if name in u.coopMiddlePhoenixNames: return
	u.coopMiddlePhoenixNames.append(name)
	gs.resolution_stack.append({"kind": "coop-middle-phoenix-cast", "playerIndex": owner, "sourceIndex": phoenix, "maxLevel": int(card.get("level", 0))})


static func completed(gs, frame: Dictionary, card: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var src := int(frame.sourceIndex)
	if card.get("coopMiddleFeather", false):
		for id in [YIJIN, ZHEN]:
			var idx := source(gs, owner, id)
			if idx >= 0 and int(gs.player(owner).units[idx].hp) <= 0:
				gs.VerifiedRules.reduce_countdown(gs, owner, idx, 1)
	if src < 0 or not Content.is_spell(card) or (not frame.get("usedFromHand", false) and card.get("sourceZone") != "insight"): return
	var p: Dictionary = gs.player(owner)
	if not p.realms.any(func(realm): return realm.get("nativeRealm") == FIRE_REALM): return
	var u: Dictionary = p.units[src]
	if not gs.VerifiedRules.OwlInsect.shikigami(u) or int(u.get("coopMiddleLightTurn", -1)) == gs.turn_counter: return
	u.coopMiddleLightTurn = gs.turn_counter
	gs.VerifiedRules.YanmieTrio.revive(gs, owner, source(gs, owner, LIGHT))


static func attack_started(gs, owner: int, src: int) -> void:
	_sunny_trigger(gs, owner, src)


static func _sunny_trigger(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if not u.get("coopMiddleSunny", false) or not active(u) or int(u.get("coopMiddleSunnyTurn", -1)) == gs.turn_counter: return
	u.coopMiddleSunnyTurn = gs.turn_counter
	gs.VerifiedRules.SunSmoke.gain_charge(gs, owner, src, 2, true)


static func extra_cost(gs, owner: int) -> int:
	return 1 if gs.current_player == owner and gs.player(owner).get("coopMiddleTax", false) else 0


static func noncombat_bonus(gs, owner: int, src: int, combat: bool) -> int:
	if combat or owner < 0 or src < 0 or src >= gs.player(owner).units.size(): return 0
	return int(int(gs.player(owner).units[src].get("coopMiddleLightTurn", -1)) == gs.turn_counter)


static func combat_immune(gs, unit: Dictionary) -> bool:
	return int(unit.get("coopMiddleImmuneTurn", -1)) == gs.turn_counter


static func zero_power(gs, owner: int, _unit: Dictionary) -> bool:
	return gs.player(owner).get("coopMiddleZero", false)


static func end_turn(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	p.erase("coopMiddleTax")
	if p.erase("coopMiddleZero"):
		for u in p.units: gs._recalc(u)


static func turn_start(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	var repeats := int(p.get("coopMiddleMusic", 0))
	p.erase("coopMiddleMusic")
	for n in repeats:
		for idx in range(p.units.size() - 1, -1, -1):
			var unit: Dictionary = p.units[idx]
			if not gs.VerifiedRules.OwlInsect.shikigami(unit): continue
			gs.resolution_stack.append({"kind": "coop-middle-music-tick", "playerIndex": owner, "sourceIndex": idx})


static func combat_snapshot(gs, owner: int, _src: int, victim: int, idx: int, options: Dictionary) -> void:
	if owner == victim or not options.get("coopMiddleZhen", false): return
	if options.has("coopMiddleZhenSnapshot"): return
	options.coopMiddleZhenSnapshot = {"victim": victim, "index": idx, "amount": gs.VerifiedRules.ArmorBreak.amount(gs, victim, idx)}


static func combat_finished(gs, owner: int, src: int, options: Dictionary) -> void:
	var data: Dictionary = options.get("coopMiddleZhenSnapshot", {})
	if not data.is_empty() and int(data.amount) > 0:
		gs.VerifiedRules.ArmorBreak.give(gs, owner, src, int(data.victim), int(data.index), int(data.amount))


static func rule_event(gs, kind: String, details: Dictionary) -> void:
	if kind != "form-trigger" or details.get("reason") == "风韵雅乐": return
	var owner := int(details.player)
	var idx: int = gs._unit_index_by_uid(owner, details.uid)
	if idx < 0: return
	var u: Dictionary = gs.player(owner).units[idx]
	if u.id != WIND: return
	var history: Dictionary = u.get("coopMiddleWindHistory", {})
	var card: Dictionary = details.card
	history[str(card.id)] = {"card": card.duplicate(true), "count": int(details.count)}
	u.coopMiddleWindHistory = history


static func knockout_changed(gs, owner: int, idx: int) -> void:
	var p: Dictionary = gs.player(owner)
	var unit: Dictionary = p.units[idx]
	if int(unit.hp) <= 0:
		if unit.erase("coopMiddleSunny"):
			gs.VerifiedRules.event(gs, "charm-removed", {"player": owner, "uid": unit.uid, "charm": SUN_DOLL})
		unit.erase("coopMiddleSunnyTurn")
		unit.erase("coopMiddleImmuneTurn")
	if unit.id != BONE or not p.get("coopMiddleYellow", false): return
	var level_one: Array = []
	var other: Array = []
	for inst in p.deck:
		var card := Content.card_def(str(inst.definitionId))
		if int(card.get("level", 0)) == 1: level_one.append(inst)
		else: other.append(inst)
	gs._shuffle(level_one)
	other.append_array(level_one)
	p.deck = other
	gs.VerifiedRules.event(gs, "coop-middle-deck-top", {"player": owner, "uid": unit.uid, "count": level_one.size()})
