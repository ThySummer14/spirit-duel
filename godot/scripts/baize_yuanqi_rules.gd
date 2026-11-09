extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const UNIT := "baize-yuanqi"
const BLESS := "w13-baize-yuanqi-93110"
const CUT := "w13-baize-yuanqi-93113"
const EPOCH := "w13-baize-yuanqi-93114"
const SHAKE := "w13-baize-yuanqi-93115"
const INSIGHT := "fate-baize-insight"
const CAUSAL := "fate-baize-reversal"
const HAND := "yuanqi-hand-top"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": UNIT})

static func present(gs) -> bool:
	return source(gs, 0) >= 0 or source(gs, 1) >= 0

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func avatar_veil(gs, owner: int) -> bool:
	return gs.player(owner).realms.any(func(realm): return int(realm.hp) > 0 and realm.get("nativeRealm", "") == "yuanqi-penglai")

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("yuanqiRules", false): return card
	var src := source(gs, owner)
	if src < 0: return card
	var result := card.duplicate(true)
	var stacks := int(inst.get("yuanqiBottomStacks", 0))
	result.yuanqiBottomStacks = stacks
	if stacks > 0 and str(card.id) in [BLESS, SHAKE]:
		result.enhanced = true
		result.text += "\n本牌已因占卜或命运抉择置底 %d 次。" % stacks
	if card.id == SHAKE: result.attackBonus = stacks
	if card.id == EPOCH: result.originCard = gs.VerifiedRules.Wave7Reworks.origin(gs, owner, gs.player(owner).units[src], "c27307")
	return result

static func _passive(gs, owner: int, was_destiny: bool) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or (was_destiny and not u.awakened) or int(u.get("yuanqiInsightTurn", -1)) == gs.turn_counter: return
	u.yuanqiInsightTurn = gs.turn_counter
	Choice.give(gs, owner, CAUSAL if u.awakened else INSIGHT)

static func _bottom_frames(gs, owner: int, cards: Array) -> void:
	var src := source(gs, owner)
	if src < 0: return
	for i in range(cards.size() - 1, -1, -1):
		var inst: Dictionary = cards[i]
		match str(inst.definitionId):
			BLESS, SHAKE:
				inst.yuanqiBottomStacks = int(inst.get("yuanqiBottomStacks", 0)) + 1
			CUT:
				gs.resolution_stack.append({"kind": "yuanqi-bottom-cut", "playerIndex": owner, "sourceIndex": src})
			EPOCH:
				gs.resolution_stack.append({"kind": "yuanqi-bottom-insight", "playerIndex": owner, "sourceIndex": src})

static func divined(gs, choice: Dictionary) -> void:
	var owner := int(choice.playerIndex)
	var deck_owner := int(choice.get("zoneOwner", owner))
	var placed: Array = []
	for iid in choice.bottom:
		var inst: Dictionary = gs.VerifiedRules.Divination.instance(gs, deck_owner, str(iid))
		if not inst.is_empty(): placed.append(inst)
	if choice.get("yuanqiInsightDraw", false) and placed.any(func(inst): return Content.card_def(str(inst.definitionId)).get("unitId") == UNIT):
		gs.resolution_stack.append({"kind": "yuanqi-insight-draw", "playerIndex": owner})
	_passive(gs, owner, false)
	_bottom_frames(gs, deck_owner, placed)

static func destiny(gs, owner: int, deck_owner: int, placed_bottom: Dictionary) -> void:
	_passive(gs, owner, true)
	var src := source(gs, owner)
	if src >= 0:
		var u: Dictionary = gs.player(owner).units[src]
		if active(u) and u.get("formRules", {}).get("yuanqiOrder", false) and int(u.get("yuanqiFormDestinyTurn", -1)) != gs.turn_counter:
			u.yuanqiFormDestinyTurn = gs.turn_counter
			gs.resolution_stack.append({"kind": "yuanqi-form-projectile", "playerIndex": owner, "sourceIndex": src})
	if not placed_bottom.is_empty(): _bottom_frames(gs, deck_owner, [placed_bottom])

static func drawn(gs, owner: int) -> void:
	if owner != gs.current_player or gs.opening_deal or gs.player(owner).deck.is_empty(): return
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not active(u) or not u.get("formRules", {}).get("yuanqiOrder", false) or int(u.get("yuanqiFormDrawTurn", -1)) == gs.turn_counter: return
	u.yuanqiFormDrawTurn = gs.turn_counter
	var deck: Array = gs.player(owner).deck
	deck.append(deck.pop_front())

static func realm_tick(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm", "") != "yuanqi-penglai": return false
	var p: Dictionary = gs.player(owner)
	if int(p.get("destinyReversed", 0)) >= 3:
		gs.resolution_stack.append({"kind": "yuanqi-realm-revive", "playerIndex": owner})
	if int(p.get("destinyFollowed", 0)) >= 3:
		gs.resolution_stack.append({"kind": "yuanqi-insight-draw", "playerIndex": owner})
	return true

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect") != "yuanqi-hand-top" or gs.player(owner).hand.size() >= 2

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") not in ["yuanqi-bless", "yuanqi-cut"]: return null
	var units := Choice.targetable_shikigami(gs, owner, owner)
	if card.effect == "yuanqi-cut": units.append_array(Choice.targetable_shikigami(gs, owner, 1 - owner))
	return units.map(func(u): return u.uid)

static func choice_card(gs, owner: int, iid: String):
	if not Choice.matches(gs, owner, iid, HAND): return null
	for inst in gs.player(owner).hand:
		if str(inst.instanceId) != iid: continue
		var card: Dictionary = gs.describe_card_instance(owner, inst)
		var result := card.duplicate(true)
		result.text = "将此牌置入牌库顶。\n" + str(result.text)
		return result
	return null

static func choose(gs, owner: int, iid: String) -> bool:
	if not Choice.matches(gs, owner, iid, HAND): return false
	var hand: Array = gs.player(owner).hand
	var index := hand.find_custom(func(inst): return str(inst.instanceId) == iid)
	if index < 0: return false
	Choice.accept(gs, owner, iid)
	gs.player(owner).deck.append(hand.pop_at(index))
	gs.resolution_stack.append({"kind": "yuanqi-multiple-destiny", "playerIndex": owner, "remaining": 3})
	Choice.finish(gs)
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != HAND: return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	var options: Array = gs.player(owner).hand.filter(func(inst): return inst.instanceId in gs.pending_choice.instanceIds)
	options.sort_custom(func(a, b): return int(Content.card_def(str(a.definitionId)).level) > int(Content.card_def(str(b.definitionId)).level))
	return not options.is_empty() and choose(gs, owner, str(options[0].instanceId))

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	if src < 0 or not str(effect.get("action", "")).begins_with("yuanqi-"): return false
	var p: Dictionary = gs.player(owner)
	var u: Dictionary = p.units[src]
	match str(effect.action):
		"yuanqi-bless":
			if not target.is_empty() and int(target.hp) > 0:
				var growth := 1 + int(card.get("yuanqiBottomStacks", 0))
				gs.VerifiedRules.Wave7Reworks.grow(gs, target, growth, growth, true)
		"yuanqi-cut":
			if target.is_empty() or int(target.hp) <= 0: return true
			for side in [owner, 1-owner]:
				var idx: int = gs._unit_index_by_uid(side, target.uid)
				if idx < 0: continue
				gs._damage_unit(side, idx, 5 + int(u.get("spellPower", 0)), owner, src)
				break
		"yuanqi-epoch":
			var copies: Array = []
			if not p.deck.is_empty(): copies.append(p.deck.back())
			if p.deck.size() > 1: copies.append(p.deck.front())
			gs.VerifiedRules.Destiny.offer(gs, owner, owner, {"kind": "yuanqi-epoch-copy", "playerIndex": owner, "copies": copies})
		"yuanqi-shake":
			gs._resolve_combat(owner, src, int(card.get("yuanqiBottomStacks", 0)), true, false, false, false, null, false, {"towerStun": true, "yuanqiStunOverflow": true})
		"yuanqi-hand-top":
			Choice.offer(gs, owner, HAND, p.hand.map(func(inst): return str(inst.instanceId)), "决因果", {"hint": "选择一张手牌置于牌库顶，再进行三次命运抉择。"})
		"yuanqi-awaken":
			gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
			for zone in ["deck", "hand", "insightZone"]:
				for inst in p.get(zone, []):
					if inst.definitionId == INSIGHT: inst.definitionId = CAUSAL
		"yuanqi-insight":
			gs.VerifiedRules.Divination.start(gs, owner, 2, owner, {"yuanqiInsightDraw": true})
		"yuanqi-reversal":
			if gs.VerifiedRules.Destiny.offer(gs, owner, owner):
				gs.pending_choice.drawOnReverse = true
		_: return false
	return true

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var kind := str(frame.get("kind", ""))
	if not kind.begins_with("yuanqi-"): return false
	var owner := int(frame.playerIndex)
	var src := int(frame.get("sourceIndex", -1))
	match kind:
		"yuanqi-bottom-cut":
			var candidates: Array = Choice.live_units(gs, 1 - owner)
			if not candidates.is_empty():
				var picked: Dictionary = candidates[int(gs.next_random() % candidates.size())]
				gs.VerifiedRules.base_damage_unit(gs, owner, src, 1 - owner, gs._unit_index_by_uid(1 - owner, picked.uid), 2)
		"yuanqi-bottom-insight":
			Choice.give(gs, owner, INSIGHT)
		"yuanqi-insight-draw":
			gs._draw(owner, 1)
		"yuanqi-form-projectile":
			gs.VerifiedRules.base_damage_projectile(gs, owner, src, 2, "定乾坤")
		"yuanqi-multiple-destiny":
			var remaining := int(frame.remaining) - 1
			gs.VerifiedRules.Destiny.offer(gs, owner, owner, {"kind": kind, "playerIndex": owner, "remaining": remaining} if remaining > 0 else {})
		"yuanqi-realm-revive":
			var p: Dictionary = gs.player(owner)
			var candidates: Array = []
			for i in p.units.size():
				var u: Dictionary = p.units[i]
				if int(u.hp) <= 0 and int(u.knockout) > 0 and gs.VerifiedRules.OwlInsect.shikigami(u) and gs.VerifiedRules.Rebirth.can_revive(u): candidates.append(i)
			if not candidates.is_empty(): gs.VerifiedRules.Countdown.change(gs, owner, int(candidates[int(gs.next_random() % candidates.size())]), -1)
		"yuanqi-epoch-copy":
			for card in frame.copies:
				var fields: Dictionary = card.duplicate(true)
				fields.erase("instanceId")
				fields.erase("definitionId")
				Choice.give(gs, owner, str(card.definitionId), fields)
		_: return false
	return true

static func score(gs, owner: int, card: Dictionary, target):
	if not card.get("yuanqiRules", false): return null
	if card.id == CUT:
		var u: Dictionary = gs._unit_by_uid(gs.player(1-owner).units, target)
		if u.is_empty(): return -30
		var src := source(gs, owner)
		if src < 0: return -30
		var damage := 5 + int(gs.player(owner).units[src].get("spellPower", 0))
		return 80 if int(u.hp) + int(u.get("shield", 0)) <= damage else 56
	if card.id == BLESS:
		var u: Dictionary = gs._unit_by_uid(gs.player(owner).units, target)
		return 47 + int(card.get("yuanqiBottomStacks", 0)) * 4 + (4 if int(u.get("front", 0)) == 1 else 0)
	if card.get("type") == "awakening": return 25
	return 60

static func prefer_bottom(gs, chooser: int, deck_owner: int, card: Dictionary) -> bool:
	if chooser != deck_owner or source(gs, chooser) < 0: return false
	if gs.pending_choice.get("yuanqiInsightDraw", false) and card.get("unitId") == UNIT:
		var prior: Array = gs.pending_choice.get("bottom", [])
		if not prior.any(func(iid):
			var inst: Dictionary = gs.VerifiedRules.Divination.instance(gs, deck_owner, str(iid))
			return Content.card_def(str(inst.get("definitionId", ""))).get("unitId") == UNIT
		): return true
	return str(card.get("id", "")) in [BLESS, CUT, SHAKE]
