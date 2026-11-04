class_name MengpoRules
extends RefCounted
## 移除牌库与同名牌不抽牌、不弃牌、不立即判定空库败北。
const Content := preload("res://scripts/content_loader.gd")

static func active(u: Dictionary) -> bool:
	return int(u.hp) > 0 and int(u.level) > 0 and not u.get("removed", false) and not u.get("baseRulesSuppressed", false)

static func _remember(gs, victim: int, inst: Dictionary, zone: String) -> void:
	var p: Dictionary = gs.player(victim)
	if not p.has("removedCards"): p.removedCards = []
	p.removedCards.append({"instance": inst.duplicate(true), "zone": zone})

static func _removed(gs, owner: int, src: int, victim: int, hand_count: int, deck_count: int, reason: String) -> void:
	if hand_count + deck_count <= 0: return
	gs._log("%s：%s移除手牌%d张、牌库%d张。" % [reason, gs.player(victim).name, hand_count, deck_count], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "mengpo-removed", {"player": owner, "uid": gs.player(owner).units[src].uid, "victimPlayer": victim, "handCount": hand_count, "deckCount": deck_count, "reason": reason})

static func bottom(gs, owner: int, src: int, victim: int, count: int, reason: String) -> void:
	var n: int = mini(maxi(count, 0), gs.player(victim).deck.size())
	for i in n: _remember(gs, victim, gs.player(victim).deck.pop_front(), "deck")
	_removed(gs, owner, src, victim, 0, n, reason)

static func same_name(gs, owner: int, src: int, victim: int, name: String, reason: String) -> void:
	var counts := {"hand": 0, "deck": 0}
	for zone in ["hand", "deck"]:
		var cards: Array = gs.player(victim)[zone]
		for i in range(cards.size() - 1, -1, -1):
			if Content.card_def(str(cards[i].definitionId)).get("name", "") != name: continue
			_remember(gs, victim, cards.pop_at(i), zone)
			counts[zone] += 1
	_removed(gs, owner, src, victim, int(counts.hand), int(counts.deck), reason)

static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int) -> void:
	if owner < 0 or src < 0 or victim == owner or amount <= 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if active(u) and Content.runtime_unit_def(u).get("mengpoMill", false):
		bottom(gs, owner, src, victim, 5 if u.awakened else 1, "孟婆能力")

static func announced(gs, owner: int, card: Dictionary) -> void:
	# 普通对战的奈何桥头；不采用有个牌局的底1专用改版。
	for observer in 2:
		for src in gs.player(observer).units.size():
			var u: Dictionary = gs.player(observer).units[src]
			if active(u) and u.get("formRules", {}).get("mengpoBridge", false):
				same_name(gs, observer, src, owner, str(card.name), "奈何桥头")

static func end_turn(gs, owner: int) -> void:
	for src in gs.player(owner).units.size():
		var u: Dictionary = gs.player(owner).units[src]
		if not active(u) or not u.get("formRules", {}).get("mengpoTurnEnd", false): continue
		for victim in [owner, 1 - owner]: bottom(gs, owner, src, victim, 1, "天降之物")

static func describe_card(gs, owner: int, card: Dictionary) -> Dictionary:
	if not card.get("mengpoRules", false): return card
	var out := card.duplicate(true)
	var count: int = gs.player(1 - owner).deck.size()
	var threshold := 12 if out.get("mengpoEnhance") == "swift" else 16
	var enhanced := count <= threshold
	out.enhanced = enhanced if out.has("mengpoEnhance") else false
	if out.has("mengpoEnhance"):
		out.text += "\n敌方牌库%d张：%s增强条件。" % [count, "满足" if enhanced else "未满足"]
	match str(out.get("mengpoEnhance", "")):
		"instant":
			out.keywords = ["instant"] if enhanced else []
		"body":
			out.value = {"attack": 8 if enhanced else 5, "hp": 10 if enhanced else 7, "setBase": true}
			out.effects[0].value = out.value.duplicate()
		"damage":
			out.value = 8 if enhanced else 4
			out.effects[0].value = out.value
		"swift": out.mengpoGrantSwift = enhanced
	return out

static func names(gs, owner: int, uid: String) -> Array:
	var idx: int = gs._unit_index_by_uid(1 - owner, uid)
	if idx < 0: return []
	var unit: Dictionary = gs.player(1 - owner).units[idx]
	if unit.get("removed", false): return []
	var ids: Array = []
	var seen: Array = []
	for card in Content.cards_for_unit(str(unit.id)):
		if card.get("token", false) or int(card.get("level", 1)) > int(unit.level) or seen.has(str(card.name)): continue
		ids.append(str(card.id))
		seen.append(str(card.name))
	return ids

static func name_units(gs, owner: int) -> Array:
	return gs.player(1 - owner).units.filter(func(u): return not names(gs, owner, str(u.uid)).is_empty()).map(func(u): return str(u.uid))

static func can_use(gs, owner: int, card: Dictionary) -> bool:
	return card.get("effect") != "mengpo-name" or not name_units(gs, owner).is_empty()

static func choice_card(gs, owner: int, iid: String) -> Variant:
	match str(gs.pending_choice.get("type", "")):
		"mengpo-name-unit":
			var idx: int = gs._unit_index_by_uid(1 - owner, iid)
			if idx < 0: return {}
			var u: Dictionary = gs.player(1 - owner).units[idx]
			return {"id": iid, "name": u.name, "unitId": u.id, "level": u.level, "type": "spell", "typeLabel": "选择式神", "text": "选择该式神的牌名。\n只可选等级≤%d的专属牌。\n可选%d种牌名；不查看实际手牌或牌库。" % [int(u.level), names(gs, owner, iid).size()]}
		"mengpo-name": return Content.card_def(iid)
		"mengpo-discard":
			for i in gs.player(owner).hand.size():
				if str(gs.player(owner).hand[i].instanceId) == iid: return gs.hand_card_def(owner, i)
			return {}
	return null

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary = gs.pending_choice
	if not str(c.get("type", "")).begins_with("mengpo-") or int(c.get("playerIndex", -1)) != owner or not c.instanceIds.has(iid): return false
	if c.type == "mengpo-name-unit":
		var ids := names(gs, owner, iid)
		if ids.is_empty(): return false
		gs._record("resolve_divination_choice", {"choice": c.type, "instanceId": iid}, owner)
		c.type = "mengpo-name"
		c.targetUid = iid
		c.instanceIds = ids
		c.hint = "选择该敌方式神当前等级允许的牌名 · 同名移除后再移除牌库底两张"
		gs.state_changed.emit()
		return true
	var src := int(c.sourceIndex)
	if c.type == "mengpo-name":
		if not names(gs, owner, str(c.targetUid)).has(iid): return false
		gs._record("resolve_divination_choice", {"choice": c.type, "instanceId": iid, "card": iid}, owner)
		same_name(gs, owner, src, 1 - owner, str(Content.card_def(iid).name), "忘忧的旋律")
		bottom(gs, owner, src, 1 - owner, 2, "忘忧的旋律")
	elif c.type == "mengpo-discard":
		var idx: int = gs.player(owner).hand.find_custom(func(i): return str(i.instanceId) == iid)
		if idx < 0: return false
		var inst: Dictionary = gs.player(owner).hand.pop_at(idx)
		gs._record("resolve_divination_choice", {"choice": c.type, "instanceId": iid, "card": inst.definitionId}, owner)
		gs._log("意外之喜弃掉「%s」。" % Content.card_def(str(inst.definitionId)).name, gs.TONE_CARD)
		gs.VerifiedRules.event(gs, "card-discarded", {"player": owner, "uid": gs.player(owner).units[src].uid, "card": Content.card_def(str(inst.definitionId)), "instanceId": iid})
	else: return false
	gs.pending_choice = {}
	gs.phase = "main"
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"mengpo-bottom": bottom(gs, owner, src, 1 - owner, int(effect.value), card.name)
		"mengpo-draw-discard":
			gs.resolution_stack.append({"kind": "charm-mengpo-discard", "playerIndex": owner, "sourceIndex": src})
			gs._draw(owner, 2)
		"mengpo-name":
			var ids := name_units(gs, owner)
			if ids.is_empty(): return true
			gs.pending_choice = {"type": "mengpo-name-unit", "playerIndex": owner, "sourceIndex": src, "zone": "catalog", "instanceIds": ids, "heading": "忘 忧 的 旋 律", "hint": "先选择一个敌方式神，再选择其当前等级允许的牌名"}
			gs.phase = "choice"
		"mengpo-awaken":
			gs._awaken(owner, src, card, effect.value)
			if card.get("mengpoGrantSwift", false):
				gs.player(owner).units[src].swift = true
				gs.VerifiedRules.event(gs, "swift-gained", {"player": owner, "uid": gs.player(owner).units[src].uid})
		_: return false
	return true

static func ai_choice(gs, owner: int) -> Variant:
	var kind := str(gs.pending_choice.get("type", ""))
	if not kind.begins_with("mengpo-"): return null
	var best := ""
	var best_score := -99999
	for iid in gs.pending_choice.instanceIds:
		var card: Dictionary = choice_card(gs, owner, str(iid))
		var score := int(card.get("level", 1)) * 10 + (5 if card.get("rarity") == "ssr" else 0)
		if kind == "mengpo-discard": score = -score
		if score > best_score: best_score = score; best = str(iid)
	return false if best.is_empty() else gs.resolve_divination_choice(owner, best)

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if not card.get("mengpoRules", false): return null
	var count: int = gs.player(1 - owner).deck.size()
	match str(card.effect):
		"mengpo-name": return 16 if can_use(gs, owner, card) else -999
		"mengpo-draw-discard": return -20 if gs.player(owner).deck.size() < 2 else 13
		"mengpo-awaken": return 12 + (4 if card.get("mengpoGrantSwift", false) else 0)
		"damage-enemy-front": return int(card.value) * 2 + (8 if gs.front_index(1 - owner) < 0 and gs.player(1 - owner).avatarHp <= int(card.value) else 0)
		"damage":
			var u: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
			return 12 + (6 if int(u.get("hp", 99)) <= 3 else 0) + mini(count, 3)
		"form": return 10 + int(card.value.attack) + (2 if count <= 16 else 0)
	return 0
