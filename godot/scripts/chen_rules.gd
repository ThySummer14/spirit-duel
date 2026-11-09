class_name ChenRules
extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const ID := "chen"
const BLESSINGS := ["chen-qisha", "chen-tianliang", "chen-tianxiang", "chen-tianfu", "chen-tiantong", "chen-tianji"]

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": ID})

static func present(gs, owner: int) -> Array:
	return gs.VerifiedRules.Insight.zone(gs, owner).filter(func(i): return i.definitionId in BLESSINGS)

static func missing(gs, owner: int, level: int) -> Array:
	var placed := present(gs, owner).map(func(i): return i.definitionId)
	return BLESSINGS.filter(func(id): return id not in placed and int(Content.card_def(id).level) <= level)

static func refresh(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	var blessings := present(gs, owner).map(func(i): return i.definitionId)
	u.chenZoneAttack = int("chen-qisha" in blessings)
	u.chenZoneHp = 2 if "chen-tianliang" in blessings else 0
	u.chenZoneTraits = []
	for id in blessings:
		var keyword := str(Content.card_def(id).get("chenZoneTrait", ""))
		if not keyword.is_empty(): u.chenZoneTraits.append(keyword)
	gs._recalc(u)

static func add(gs, owner: int, id: String) -> void:
	gs.VerifiedRules.Insight.place(gs, owner, gs.VerifiedRules.Insight.instance(gs, owner, id))

static func add_random(gs, owner: int, level: int, count: int) -> void:
	var ids := missing(gs, owner, level)
	for i in mini(count, ids.size()):
		add(gs, owner, str(ids.pop_at(int(gs.next_random() % ids.size()))))

static func to_hand(gs, owner: int, id: String, turn_only: bool = false) -> void:
	var hand: Array = gs.player(owner).hand
	if hand.size() >= int(gs.rules.maxHandSize): return
	var inst: Dictionary = gs.VerifiedRules.Insight.instance(gs, owner, id)
	if turn_only: inst.chenFreeTurn = gs.turn_counter
	hand.append(inst)
	gs.VerifiedRules.event(gs, "chen-card-to-hand", {"player": owner, "card": Content.card_def(id), "instanceId": inst.instanceId})

static func upgraded(gs, owner: int, idx: int) -> void:
	var u: Dictionary = gs.player(owner).units[idx]
	if u.id == ID and not u.get("baseRulesSuppressed", false): to_hand(gs, owner, "c62101")

static func entered(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if not u.awakened or not gs.VerifiedRules.Astral.active(u) or int(u.get("chenInsightTurn", -1)) == gs.turn_counter: return
	u.chenInsightTurn = gs.turn_counter
	if present(gs, owner).size() >= 3: gs.player(owner).chenNextFree = true
	else: add_random(gs, owner, 3, 1)

static func turn_start(gs, owner: int) -> void:
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.awakened and gs.VerifiedRules.Astral.active(u): gs.VerifiedRules.Insight.enter(gs, owner)

static func used(gs, owner: int, card: Dictionary) -> void:
	if not card.get("chenBlessing", false): return
	var src := source(gs, owner)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0 or not u.get("formRules", {}).get("chenPair", false): return
	for id in missing(gs, owner, int(card.level)):
		if id != card.id and int(Content.card_def(id).level) == int(card.level):
			add(gs, owner, id)
			break

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("chenRules", false): return card
	var view := card.duplicate(true)
	if card.id == "c62104":
		var count := present(gs, owner).size()
		view.value = {"attack": 2 + count, "hp": 4 + count, "setBase": true}
		view.effects[0].value = view.value
		view.currentCardStats = "当前形态：%d力量/%d生命" % [2 + count, 4 + count]
	if card.get("chenBlessing", false):
		view.chenCopyFree = int(inst.get("chenFreeTurn", -1)) == gs.turn_counter
		view.chenAwakenedFree = gs.player(owner).get("chenNextFree", false) and not view.chenCopyFree
	return view

static func reduce_damage(u: Dictionary, damage: int) -> int:
	return maxi(0, damage - 1) if "resolute" in u.get("chenZoneTraits", []) or u.get("chenCombatResolute", false) else damage

static func ward(gs, owner: int, idx: int) -> bool:
	var u: Dictionary = gs.player(owner).units[idx]
	if int(u.hp) <= 0 or not u.get("formRules", {}).get("chenWard", false) or int(u.get("chenWardTurn", -1)) == gs.turn_counter: return false
	var cards := present(gs, owner)
	if cards.is_empty(): return false
	var inst: Dictionary = cards[int(gs.next_random() % cards.size())]
	u.chenWardTurn = gs.turn_counter
	gs.VerifiedRules.Insight.remove(gs, owner, inst)
	gs.VerifiedRules.event(gs, "chen-ward", {"player": owner, "uid": u.uid, "card": Content.card_def(inst.definitionId)})
	return true

static func choose(gs, owner: int, ids: Array, copy: bool, heading: String) -> void:
	if ids.is_empty(): return
	gs.pending_choice = {"type": "chen-blessing", "playerIndex": owner, "instanceIds": ids, "copy": copy, "heading": heading,
		"hint": "选择要复制到手牌的祝星牌" if copy else "选择要放入启悟区的祝星牌"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String):
	var c: Dictionary = gs.pending_choice
	if c.get("type") != "chen-blessing" or int(c.playerIndex) != owner or iid not in c.instanceIds: return null
	if not c.copy: return Content.card_def(iid)
	for inst in present(gs, owner):
		if inst.instanceId == iid: return Content.card_def(inst.definitionId)
	return {}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var card = choice_card(gs, owner, iid)
	if card == null or card.is_empty(): return false
	var copy: bool = gs.pending_choice.copy
	gs.pending_choice = {}
	gs.phase = "main"
	gs._record("resolve_divination_choice", {"instanceId": iid, "choice": "chen-blessing", "card": card.id}, owner)
	if copy: to_hand(gs, owner, card.id, true)
	else: add(gs, owner, card.id)
	gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int):
	var c: Dictionary = gs.pending_choice
	if c.get("type") != "chen-blessing": return null
	var src := source(gs, owner)
	var u: Dictionary = gs.player(owner).units[src]
	var ids: Array = c.instanceIds
	var best := str(ids[0])
	var best_score := -100
	for id in ids:
		var card: Dictionary = choice_card(gs, owner, str(id))
		var score := int(card.level) * 4 if int(card.level) <= int(u.level) else -15
		if card.id == "chen-tiantong" and int(u.hp) <= 0: score += 50
		if card.id == "chen-tianliang" and int(u.hp) < 4: score += 15
		if score > best_score:
			best = str(id)
			best_score = score
	return resolve_choice(gs, owner, best)

static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
	if realm.get("nativeRealm") != "chen-stars": return false
	var src := source(gs, owner)
	if src >= 0:
		if present(gs, owner).size() >= 3: gs.VerifiedRules.Insight.enter(gs, owner)
		else: add_random(gs, owner, int(gs.player(owner).units[src].level), 1)
	return true

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary) -> bool:
	if not card.get("chenRules", false): return false
	var u: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"chen-course": choose(gs, owner, missing(gs, owner, int(u.level)), false, card.name)
		"chen-pair":
			gs._apply_form(owner, src, card)
			gs.VerifiedRules.Insight.enter(gs, owner)
		"chen-copy": choose(gs, owner, present(gs, owner).map(func(i): return i.instanceId), true, card.name)
		"chen-shift":
			gs.VerifiedRules.Insight.enter(gs, owner)
			add_random(gs, owner, int(u.level), 2)
		"chen-stars":
			gs._deploy_realm(owner, card)
			trigger_realm(gs, owner, gs.player(owner).realms.back())
		"chen-ward":
			gs._apply_form(owner, src, card)
			choose(gs, owner, missing(gs, owner, 3), false, card.name)
		"chen-awaken":
			gs.VerifiedRules.Insight.enter(gs, owner)
			gs._awaken(owner, src, card, effect.value)
		"chen-revive": gs.VerifiedRules.Peach.revive(gs, owner, src, u, false, false)
		_: return false
	return true
