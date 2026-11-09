class_name SandBookRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const UNIT := "alaina"
const LIMITLESS := "sandLimitless"
const ENDLESS := "sandEndless"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": UNIT})

static func _pool(gs, victim: int, exclude: String = "") -> Array:
	return gs.player(victim).deck.filter(func(i): return str(i.instanceId) != exclude)

static func _label(key: String) -> String:
	return "无穷无尽" if key == LIMITLESS else "无始无终"

static func _attach(gs, owner: int, victim: int, inst: Dictionary, key: String, mark: Dictionary = {}) -> void:
	if inst.is_empty() or inst not in gs.player(victim).deck: return
	if key == "eyeCurses":
		inst.eyeCurses = int(inst.get("eyeCurses", 0)) + 1
		gs.VerifiedRules.event(gs, "eye-curse-attached", {"player": owner, "victimPlayer": victim, "instanceId": inst.instanceId, "count": inst.eyeCurses})
		return
	var marks: Array = inst.get(key, [])
	if key in [LIMITLESS, ENDLESS] and marks.any(func(m): return int(m.owner) == owner): return
	marks.append({"owner": owner} if mark.is_empty() else mark.duplicate(true))
	inst[key] = marks
	gs.VerifiedRules.event(gs, "deck-charm-attached", {"player": owner, "victimPlayer": victim, "instanceId": inst.instanceId, "charm": key, "count": marks.size()})
	gs.VerifiedRules.BondDream.refresh(gs)

static func _random_attach(gs, owner: int, victim: int, key: String, count: int, top: int = -1) -> void:
	var pool := _pool(gs, victim)
	if top > 0: pool = pool.slice(maxi(0, pool.size()-top))
	pool = pool.filter(func(i): return not i.get(key, []).any(func(m): return int(m.owner) == owner))
	gs._shuffle(pool)
	for inst in pool.slice(0, count): _attach(gs, owner, victim, inst, key)

static func _copy_random(gs, owner: int, victim: int, exclude: String, key: String, mark: Dictionary) -> void:
	var pool := _pool(gs, victim, exclude)
	if key in [LIMITLESS, ENDLESS]:
		pool = pool.filter(func(i): return not i.get(key, []).any(func(m): return int(m.owner) == owner))
	if pool.is_empty(): return
	_attach(gs, owner, victim, pool[gs.next_random() % pool.size()], key, mark)

static func _charms(owner: int, victim: int, inst: Dictionary) -> Array:
	var result: Array = []
	for key in [LIMITLESS, ENDLESS, "bondMarks", "nightmareMarks"]:
		for mark in inst.get(key, []):
			if int(mark.get("owner", -1)) == owner: result.append({"key": key, "mark": mark.duplicate(true)})
	if victim != owner and int(inst.get("eyeCurses", 0)) > 0: result.append({"key": "eyeCurses", "mark": {}})
	return result

static func has_charm(owner: int, victim: int, inst: Dictionary) -> bool:
	return not _charms(owner, victim, inst).is_empty()

static func event(gs, kind: String, details: Dictionary) -> void:
	if kind not in ["deck-charm-attached", "eye-curse-attached"]: return
	var owner := int(details.player)
	var victim := int(details.victimPlayer)
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if not gs.VerifiedRules.BondDream.active(unit) or not unit.get("formRules", {}).get("sandHoly", false) or int(unit.get("sandHolyTurn", -1)) == gs.turn_counter: return
	var inst: Dictionary = gs.VerifiedRules.Divination.instance(gs, victim, str(details.instanceId))
	if inst.is_empty(): return
	var key := str(details.get("charm", "eyeCurses"))
	var mark: Dictionary = {} if key == "eyeCurses" else inst.get(key, []).back()
	unit.sandHolyTurn = gs.turn_counter
	_copy_random(gs, owner, victim, str(inst.instanceId), key, mark)

static func drawn(gs, victim: int, inst: Dictionary, context: Dictionary) -> bool:
	if gs.opening_deal or (source(gs, victim) < 0 and source(gs, 1-victim) < 0): return false
	var player: Dictionary = gs.player(victim)
	if int(player.get("sandDrawTurn", -1)) != gs.turn_counter:
		player.sandDrawTurn = gs.turn_counter
		player.sandDrawCount = 0
	player.sandDrawCount += 1
	var depth: int = gs.resolution_stack.size()
	for owner in [victim, 1-victim]:
		var charms := _charms(owner, victim, inst)
		if charms.is_empty(): continue
		if int(context.get("sandRewindOwner", -1)) == owner:
			gs.player(owner).sandRewindMarked = int(gs.player(owner).get("sandRewindMarked", 0)) + 1
		var src := source(gs, owner)
		if src < 0: continue
		var u: Dictionary = gs.player(owner).units[src]
		if gs.VerifiedRules.BondDream.active(u):
			if int(u.get("sandPassiveTurn", -1)) != gs.turn_counter:
				u.sandPassiveTurn = gs.turn_counter
				u.sandPassiveUses = 0
			if int(u.sandPassiveUses) < (3 if u.awakened else 1):
				u.sandPassiveUses += 1
				var chosen: Dictionary = charms[gs.next_random() % charms.size()] if u.awakened and charms.size() > 1 else charms[0]
				gs.resolution_stack.append({"kind": "sand-passive", "playerIndex": owner, "sourceIndex": src, "victim": victim, "charm": chosen if u.awakened else {}})
		for item in charms:
			if item.key in [LIMITLESS, ENDLESS]:
				gs.resolution_stack.append({"kind": "sand-draw-charm", "playerIndex": owner, "sourceIndex": src, "victim": victim, "charm": item.key, "definitionId": inst.definitionId, "first": int(player.sandDrawCount) == 1})
	inst.erase(LIMITLESS)
	inst.erase(ENDLESS)
	return gs.resolution_stack.size() > depth

static func _triggers_for_both(gs, owner: int, count: int, marked: bool) -> void:
	gs.resolution_stack.append({"kind": "sand-draw", "playerIndex": 1-owner, "charmOwner": owner, "count": count, "marked": marked})
	gs.resolution_stack.append({"kind": "sand-draw", "playerIndex": owner, "charmOwner": owner, "count": count, "marked": marked})

static func _wash(gs, victim: int, inst: Dictionary, owner: int = -1) -> void:
	var p: Dictionary = gs.player(victim)
	p.hand.erase(inst)
	if inst not in p.deck: p.deck.append(inst)
	if owner >= 0: _attach(gs, owner, victim, inst, LIMITLESS)
	gs._shuffle(p.deck)

static func _revive(gs, victim: int, idx: int) -> void:
	if idx < 0: return
	var target: Dictionary = gs.player(victim).units[idx]
	if int(target.hp) <= 0: gs.VerifiedRules.Peach.revive(gs, victim, source(gs, victim), target, false, false)
	if int(target.hp) <= 0: return
	target.swift = true
	gs.VerifiedRules.Combat.grant_inspired(gs, victim, idx)

static func _source_projectile(gs, owner: int, src: int) -> void:
	if src >= 0: gs.VerifiedRules.base_damage_projectile(gs, owner, src, 1)

static func _draw_charm(gs, frame: Dictionary) -> void:
	var owner := int(frame.playerIndex)
	var victim := int(frame.victim)
	var idx: int = gs._source_index(victim, Content.card_def(str(frame.definitionId)))
	if frame.charm == ENDLESS:
		_revive(gs, victim, idx)
		return
	if idx < 0: return
	var amount := 3 if frame.first else 5
	var unit: Dictionary = gs.player(victim).units[idx]
	if int(unit.hp) > 0:
		gs._damage_unit(victim, idx, amount, owner, int(frame.sourceIndex))
	elif gs.player(owner).realms.any(func(r): return int(r.hp) > 0 and r.get("nativeRealm") == "sand-library"):
		gs._damage_avatar(victim, amount, owner, int(frame.sourceIndex))

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.kind)
	if not kind.begins_with("sand-"): return false
	var owner := int(frame.playerIndex)
	match kind:
		"sand-draw":
			if int(frame.count) > 1:
				var next := frame.duplicate()
				next.count -= 1
				gs.resolution_stack.append(next)
			var context := {}
			if frame.get("marked", false): context.sandCharmOwner = int(frame.charmOwner)
			if frame.has("rewindOwner"): context.sandRewindOwner = int(frame.rewindOwner)
			gs._draw(owner, 1, -1, context)
		"sand-rewind-finish":
			for victim in [owner, 1-owner]:
				var p: Dictionary = gs.player(victim)
				var hand: Array = p.hand.duplicate()
				gs._shuffle(hand)
				for inst in hand.slice(0, 3):
					p.hand.erase(inst)
					p.deck.append(inst)
				if not hand.is_empty(): gs._shuffle(p.deck)
			var p: Dictionary = gs.player(owner)
			var count := 1 + int(p.get("sandRewindMarked", 0))
			p.erase("sandRewindMarked")
			gs.VerifiedRules.BondDream.refresh(gs)
			gs.VerifiedRules.Divination.start(gs, owner, count)
		"sand-draw-charm":
			_draw_charm(gs, frame)
		"sand-passive":
			_source_projectile(gs, owner, int(frame.sourceIndex))
			if not frame.charm.is_empty(): _copy_random(gs, owner, int(frame.victim), "", str(frame.charm.key), frame.charm.mark)
	return true

static func offer(gs, owner: int, zone_owner: int, kind: String, insts: Array, title: String, hint: String) -> void:
	if insts.is_empty(): return
	gs.pending_choice = {"type": kind, "playerIndex": owner, "zoneOwner": zone_owner, "instanceIds": insts.map(func(i): return str(i.instanceId)), "title": title, "heading": title, "hint": hint}
	gs.phase = "choice"

static func choice_card(gs, _owner: int, iid: String):
	if str(gs.pending_choice.get("type", "")) not in ["charm-sand-top", "charm-twin-discover"]: return null
	var victim := int(gs.pending_choice.zoneOwner)
	var inst: Dictionary = gs.VerifiedRules.Divination.instance(gs, victim, iid)
	if inst.is_empty(): return {}
	return gs.describe_card_instance(victim, inst, false)

static func obtain(gs, owner: int, inst: Dictionary) -> void:
	var p: Dictionary = gs.player(owner)
	if p.hand.size() >= int(gs.rules.get("maxHandSize", 12)):
		gs._log("手牌已满，「%s」被烧毁。" % Content.card_def(str(inst.definitionId)).name, gs.TONE_DANGER)
		return
	p.hand.append(inst)

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if int(choice.playerIndex) != owner or iid not in choice.instanceIds: return false
	var victim := int(choice.zoneOwner)
	var inst: Dictionary = gs.VerifiedRules.Divination.instance(gs, victim, iid)
	if inst.is_empty(): return false
	gs.pending_choice = {}
	gs.phase = "main"
	if choice.type == "charm-twin-discover":
		gs.player(owner).deck.erase(inst)
		gs.VerifiedRules.BondDream.fetched(gs, inst)
		obtain(gs, owner, inst)
	else:
		_attach(gs, owner, victim, inst, LIMITLESS)
	gs._record("resolve_divination_choice", {"instanceId": iid, "card": inst.definitionId, "choice": choice.type}, owner)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var choice: Dictionary = gs.pending_choice
	if str(choice.get("type", "")) not in ["charm-sand-top", "charm-twin-discover"]: return null
	if int(choice.playerIndex) != owner: return false
	var victim := int(choice.zoneOwner)
	var best := ""
	var score := -999
	for iid in choice.instanceIds:
		var inst: Dictionary = gs.VerifiedRules.Divination.instance(gs, victim, str(iid))
		if inst.is_empty(): continue
		var card := Content.card_def(str(inst.definitionId))
		var src: int = gs._source_index(victim, card)
		var active: bool = src >= 0 and int(gs.player(victim).units[src].hp) > 0
		var current := 4 if active else 0
		if owner != victim:
			current += gs.player(victim).deck.find(inst) - gs.player(victim).deck.size()
			if inst.get(LIMITLESS, []).any(func(mark): return int(mark.owner) == owner): current -= 10
		else:
			if active and int(gs.player(victim).units[src].level) >= int(card.level): current += 6
			if card.type == "realm": current += 2
		if current > score:
			best = str(iid)
			score = current
	return not best.is_empty() and resolve_choice(gs, owner, best)

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var unit: Dictionary = gs.player(owner).units[src]
	if gs.VerifiedRules.BondDream.active(unit) and unit.get("formRules", {}).get("sandBook", false):
		_triggers_for_both(gs, owner, 1, true)

static func realm_turn(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "sand-library": return false
	_random_attach(gs, owner, 1-owner, LIMITLESS, 1)
	return true

static func targets(gs, owner: int, card: Dictionary):
	if card.get("id", "") != "c64106": return null
	return gs.player(1-owner).units.filter(func(u): return int(u.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and not gs.VerifiedRules.Combat.has(u, "veil")).map(func(u): return str(u.uid))

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if card.is_empty(): return card
	var view := card
	for key in [LIMITLESS, ENDLESS]:
		if inst.get(key, []).is_empty(): continue
		if is_same(view, card): view = card.duplicate(true)
		view.text += "\n结附「%s」。" % _label(key)
	if card.id != "c64107": return view
	var src := source(gs, owner)
	if src < 0 or int(gs.player(owner).units[src].level) >= 3: return view
	view = view.duplicate(true)
	view.printedLevel = card.level
	view.level = 1
	view.currentCardStats = "戏法：双方各抽一张牌"
	view.effect = "sand-trick"
	view.effects = [{"action": "sand-trick", "target": "auto", "value": 0}]
	return view

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	if not str(effect.action).begins_with("sand-"): return false
	var enemy := 1-owner
	match str(effect.action):
		"sand-peek":
			var deck: Array = gs.player(enemy).deck
			var top: Array = deck.slice(maxi(0, deck.size()-3))
			top.reverse()
			offer(gs, owner, enemy, "charm-sand-top", top, "九次幂", "查看敌方牌库顶，选择一张牌结附「无穷无尽」。")
		"sand-form":
			gs._apply_form(owner, src, card, effect.value)
			if card.id == "c64102": _random_attach(gs, owner, enemy, LIMITLESS, 1, 3)
			else:
				_random_attach(gs, owner, owner, ENDLESS, 3)
				_random_attach(gs, owner, enemy, LIMITLESS, 3)
				_triggers_for_both(gs, owner, 1, true)
		"sand-rewind":
			gs.player(owner).sandRewindMarked = 0
			gs.resolution_stack.append({"kind": "sand-rewind-finish", "playerIndex": owner})
			for victim in [enemy, owner]:
				gs.resolution_stack.append({"kind": "sand-draw", "playerIndex": victim, "count": 3, "rewindOwner": owner})
		"sand-awaken":
			gs._awaken(owner, src, card, effect.value)
		"sand-library":
			gs._deploy_realm(owner, card)
			_random_attach(gs, owner, enemy, LIMITLESS, 1)
		"sand-bind":
			var cancelled: Dictionary = card.get("sandCounter", {})
			if not cancelled.is_empty():
				var rid := int(cancelled.resolutionId)
				gs.resolution_stack = gs.resolution_stack.filter(func(f): return int(f.get("resolutionId", -1)) != rid)
				var played: Dictionary = cancelled.card
				gs.VerifiedRules.event(gs, "card-nullified", {"player": enemy, "resolutionId": rid, "card": played})
				_wash(gs, enemy, played.playedInstance, owner)
				gs.VerifiedRules.Insight.used(gs, enemy, played, played.playedInstance, false)
			elif not target.is_empty():
				var pool: Array = gs.player(enemy).hand.filter(func(inst): return target.id in Content.card_unit_ids(Content.card_def(str(inst.definitionId))))
				if not pool.is_empty(): _wash(gs, enemy, pool[gs.next_random() % pool.size()], owner)
		"sand-final":
			_random_attach(gs, owner, enemy, LIMITLESS, 3)
			_triggers_for_both(gs, owner, 2, true)
		"sand-trick":
			_triggers_for_both(gs, owner, 1, false)
	return true

static func score(gs, owner: int, card: Dictionary):
	if not str(card.get("effect", "")).begins_with("sand-"): return null
	match str(card.effect):
		"sand-peek": return 45 if not gs.player(1-owner).deck.is_empty() else -100
		"sand-rewind": return 40 if gs.player(owner).deck.size() >= 3 else -95
		"sand-bind": return 30 if not gs.player(1-owner).hand.is_empty() else -90
		"sand-final": return 72
		"sand-trick": return 25 if not gs.player(owner).deck.is_empty() else -90
	return 54
