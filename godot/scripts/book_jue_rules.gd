class_name BookJueRules
extends RefCounted
## Reveals attach to card instances. Choices and damage history contain only JSON data.
const FINISH := "__book-jue-finish__"

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) >= 1 and not unit.get("removed", false)

static func opening_extra(gs, owner: int) -> int:
	var extra := 0
	for unit in gs.player(owner).units:
		extra += int(ContentLoader.runtime_unit_def(unit).get("bookOpeningCards", 0))
	return extra

static func empty_draw(gs, owner: int) -> bool:
	var p: Dictionary = gs.player(owner)
	if not p.get("bookEmptyDraw", false): return false
	var src: int = gs._unit_index_by_uid(owner, p.get("bookEmptyDrawSource", ""))
	var context: Dictionary = gs._card_effect_context
	gs._card_effect_context = {}
	gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,10)
	gs._card_effect_context = context
	gs.VerifiedRules.event(gs, "book-empty-draw", {"player": owner, "uid": p.get("bookEmptyDrawSource", "")})
	# One draw action, regardless of its requested card count, replaces once.
	return true

static func reveal(gs, owner: int, inst: Dictionary, observer: int) -> void:
	if inst.get("revealed", false): return
	inst.revealed = true
	gs.VerifiedRules.event(gs, "hand-revealed", {"player": owner, "observer": observer, "instanceId": inst.instanceId, "card": ContentLoader.card_def(str(inst.definitionId))})

static func turn_start(gs, owner: int, src: int) -> void:
	var unit: Dictionary = gs.player(owner).units[src]
	if not active(unit) or not ContentLoader.runtime_unit_def(unit).get("jueReveal", false): return
	var enemy := 1 - owner
	var pool: Array = gs.player(enemy).hand.filter(func(i): return not i.get("revealed", false))
	if unit.awakened:
		for inst in pool: reveal(gs, enemy, inst, owner)
	elif not pool.is_empty(): reveal(gs, enemy, pool[int(floor(gs.randf01() * pool.size()))], owner)

static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary, from_hand: bool = true) -> Dictionary:
	var out := card.duplicate(true)
	out.handRevealed = from_hand and bool(inst.get("revealed", false))
	out.handInstanceId = str(inst.get("instanceId", ""))
	var revealed: Array = gs.player(1 - owner).hand.filter(func(i): return i.get("revealed", false))
	if card.get("bookHandForm", false):
		var body := maxi(1, gs.player(owner).hand.size())
		out.value = {"attack": body, "hp": body, "setBase": true}
		out.effects[0].value = out.value.duplicate()
		out.text += "\n当前%d力量/%d生命。" % [body, body]
	if card.get("jueMimic", false):
		var armor := 0
		var power := 0
		for shown in revealed:
			if ContentLoader.card_def(str(shown.definitionId)).get("type") in ["spell", "awakening"]: armor += 1
			else: power += 1
		out.value = power
		out.effects[0].value = power
		out.combatOption = {"shield": armor}
		out.text += "\n当前+%d力量/+%d护甲。" % [power, armor]
	if card.get("jueMazeEnhance", false) and revealed.size() == gs.player(1 - owner).hand.size():
		out.keywords = out.get("keywords", []).duplicate()
		if not out.keywords.has("instant"): out.keywords.append("instant")
		out.text += "\n敌方手牌全部已展示：瞬发。"
	if out.handRevealed:
		out.text += "\n已展示给对手。"
		for observer in gs.player(1 - owner).units:
			if active(observer) and observer.get("formRules", {}).get("jueHandTax", false):
				out.cost = int(out.get("cost", 0)) + 1
				out.jueHandTax = 1
				break
	return out

static func targets(gs, owner: int, card: Dictionary) -> Variant:
	if card.get("target") == "enemy-unit-any-state":
		return gs.player(1 - owner).units.filter(func(u): return not u.get("removed", false)).map(func(u): return u.uid)
	if card.get("target") == "enemy-damaged-unit-this-turn":
		return gs.player(1 - owner).units.filter(func(u): return int(u.hp) > 0 and int(u.get("jueDamageDealtTurn", -1)) == gs.turn_counter).map(func(u): return u.uid)
	return null

static func announced(gs, frame: Dictionary, card: Dictionary) -> void:
	if frame.get("automatic", false) or not frame.get("usedFromHand", false): return
	var owner := int(frame.playerIndex)
	if card.get("handRevealed", false):
		for src in gs.player(1 - owner).units.size():
			var observer: Dictionary = gs.player(1 - owner).units[src]
			if active(observer) and observer.get("formRules", {}).get("jueSpiritSight", false):
				var context: Dictionary = gs._card_effect_context
				gs._card_effect_context = {}
				gs._damage_avatar(owner, 2, 1 - owner, src)
				if gs.winner < 0: gs._heal_avatar(1 - owner, 2)
				gs._card_effect_context = context

static func damage_dealt(gs, owner: int, src: int, amount: int) -> void:
	if owner < 0 or src < 0 or amount <= 0: return
	gs.player(owner).units[src].jueDamageDealtTurn = gs.turn_counter

static func avatar_damaged(gs, owner: int, src: int, victim: int, amount: int) -> void:
	if owner < 0 or src < 0 or amount <= 0: return
	var source: Dictionary = gs.player(owner).units[src]
	damage_dealt(gs, owner, src, amount)
	if victim == owner: return
	if active(source) and source.get("formRules", {}).get("bookAvatarDraw", false): gs._draw(owner, 1)
	if gs.winner < 0 and int(gs.player(victim).avatarHp) > 0 and int(source.hp) > 0:
		gs.VerifiedRules.automatic_response(gs, victim, "enemy-unit-damaged-avatar", source.uid, {"kind": "response-complete"})

static func turn_draw(gs, owner: int) -> bool:
	for unit in gs.player(owner).units:
		if active(unit) and unit.get("formRules", {}).get("bookMindChoice", false):
			if not gs.player(owner).deck.is_empty():
				gs.start_divination(owner, {"id": "c11904", "divination": {"count": 3}}, {}, false)
				gs.pending_choice.type = "book-mind"
				gs.pending_choice.heading = "明 心"
				gs.pending_choice.title = "明心 · 选择一张置入手牌"
				gs.pending_choice.hint = "检视牌库顶三张 · 选择一张置入手牌"
			return true
	return false

static func _dispatch_options(gs, owner: int, victim: int, shown_only: bool) -> Array:
	var out: Array = []
	if not gs.player(victim).deck.is_empty():
		for inst in gs.player(victim).hand:
			if not shown_only or inst.get("revealed", false): out.append(str(inst.instanceId))
	out.append(FINISH)
	return out

static func start_dispatch(gs, owner: int, victim: int, shown_only: bool, draw_after: bool) -> void:
	gs.pending_choice = {"type": "book-dispatch", "playerIndex": owner, "zoneOwner": victim, "zone": "hand", "remaining": 3, "returned": [], "shownOnly": shown_only, "drawAfter": draw_after, "instanceIds": _dispatch_options(gs, owner, victim, shown_only), "heading": "强 索" if shown_only else "云 游", "title": "选择一张手牌调度，或结束调度", "hint": "剩余3次 · 替换牌不会立即抽回 · 可提前结束"}
	gs.phase = "choice"

static func choice_card(gs, owner: int, iid: String) -> Variant:
	if gs.pending_choice.get("type") not in ["book-dispatch", "book-mind"]: return null
	if iid == FINISH: return {"id": FINISH, "name": "结束调度", "typeLabel": "选择", "text": "保留当前手牌，结束剩余调度。"}
	var zone_owner := int(gs.pending_choice.get("zoneOwner", owner))
	for inst in gs.player(zone_owner).get(str(gs.pending_choice.get("zone", "deck")), []):
		if str(inst.instanceId) == iid: return ContentLoader.card_def(str(inst.definitionId))
	return {}

static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var choice: Dictionary = gs.pending_choice
	if choice.get("type") not in ["book-dispatch", "book-mind"] or int(choice.playerIndex) != owner or not choice.instanceIds.has(iid): return false
	var victim := int(choice.get("zoneOwner", owner))
	var p: Dictionary = gs.player(victim)
	if choice.type == "book-mind":
		var idx := -1
		for i in p.deck.size():
			if str(p.deck[i].instanceId) == iid: idx = i
		if idx < 0: return false
		var selected: Dictionary = p.deck.pop_at(idx)
		gs.VerifiedRules.BondDream.fetched(gs, selected)
		if p.hand.size() < int(gs.rules.maxHandSize): p.hand.append(selected)
		gs._record("resolve_divination_choice", {"instanceId": iid, "card": selected.definitionId, "choice": "book-mind"}, owner)
		gs.pending_choice = {}
	else:
		if iid == FINISH:
			gs._record("resolve_divination_choice", {"instanceId": iid, "card": "", "choice": "book-dispatch", "victimPlayer": victim}, owner)
		if iid != FINISH:
			var idx := -1
			for i in p.hand.size():
				if str(p.hand[i].instanceId) == iid: idx = i
			if idx < 0 or p.deck.is_empty() or (choice.shownOnly and not p.hand[idx].get("revealed", false)): return false
			var rejected: Dictionary = p.hand[idx]
			var replacement: Dictionary = p.deck.pop_back()
			gs.VerifiedRules.BondDream.fetched(gs, replacement)
			rejected.erase("revealed")
			choice.returned.append(rejected)
			p.hand[idx] = replacement
			choice.remaining = int(choice.remaining) - 1
			gs._record("resolve_divination_choice", {"instanceId": iid, "card": rejected.definitionId, "choice": "book-dispatch", "victimPlayer": victim}, owner)
		if iid == FINISH or int(choice.remaining) <= 0 or _dispatch_options(gs, owner, victim, bool(choice.shownOnly)).size() == 1:
			p.deck.append_array(choice.returned)
			if not choice.returned.is_empty(): gs._shuffle(p.deck)
			gs.pending_choice = {}
			if choice.drawAfter and gs.winner < 0: gs._draw(owner, 1)
		else:
			choice.instanceIds = _dispatch_options(gs, owner, victim, bool(choice.shownOnly))
			choice.hint = "剩余%d次 · 可提前结束" % int(choice.remaining)
	if gs.pending_choice.is_empty():
		gs.phase = "main"
		gs._resolve_resolution_stack()
	gs.state_changed.emit()
	return true

static func ai_choice(gs, owner: int) -> Variant:
	if gs.pending_choice.get("type") not in ["book-dispatch", "book-mind"]: return null
	if int(gs.pending_choice.playerIndex) != owner: return false
	var best := FINISH
	var best_score := -999
	for iid in gs.pending_choice.instanceIds:
		if iid == FINISH: continue
		var card: Dictionary = choice_card(gs, owner, str(iid))
		var score := int(card.get("level", 0)) * 10
		if gs.pending_choice.get("type") == "book-dispatch" and int(gs.pending_choice.zoneOwner) == owner:
			var src: int = gs._source_index(owner, card)
			if src >= 0 and (int(gs.player(owner).units[src].hp) <= 0 or int(gs.player(owner).units[src].level) < int(card.level)): score += 100
		if score > best_score:
			best_score = score
			best = str(iid)
	return gs.resolve_divination_choice(owner, best)

static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	var unit: Dictionary = gs.player(owner).units[src]
	match str(effect.get("action", "")):
		"book-ink":
			if not target.is_empty(): gs.resolution_stack.append({"kind": "charm-book-ink", "playerIndex": owner, "sourceIndex": src, "targetId": target.uid, "bonus": int(card.get("foxHandDamageBonus", 0))})
			gs._draw(owner, 1)
		"book-universe":
			for teammate in gs.player(owner).units:
				if teammate.id == unit.id or teammate.get("summoned", false): continue
				var pool: Array = ContentLoader.cards_for_unit(str(teammate.id)).filter(func(c): return not c.get("token", false) and not c.get("alternateArt", false))
				if pool.is_empty(): continue
				var obtained: Dictionary = pool[int(floor(gs.randf01() * pool.size()))]
				var p: Dictionary = gs.player(owner)
				var generated := {"instanceId": "%s-c%d" % [p.id, gs.next_card_id], "definitionId": str(obtained.id)}
				gs.next_card_id += 1
				if p.hand.size() < int(gs.rules.maxHandSize): p.hand.append(generated)
				gs.VerifiedRules.event(gs, "card-generated", {"player": owner, "uid": unit.uid, "card": obtained, "burned": p.hand.size() >= int(gs.rules.maxHandSize) and not p.hand.has(generated)})
		"book-dispatch": start_dispatch(gs, owner, owner, false, false)
		"jue-dispatch": start_dispatch(gs, owner, 1 - owner, true, true)
		"book-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
			gs.player(owner).bookEmptyDraw = true
			gs.player(owner).bookEmptyDrawSource = unit.uid
		"jue-read":
			if not target.is_empty():
				for inst in gs.player(1 - owner).hand:
					if target.id in ContentLoader.card_unit_ids(ContentLoader.card_def(str(inst.definitionId))): reveal(gs, 1 - owner, inst, owner)
		"jue-bomb":
			if target.is_empty(): return true
			var amount := 2 + int(card.get("foxHandDamageBonus", 0))
			for victim in 2:
				var idx: int = gs._unit_index_by_uid(victim, target.uid)
				if idx < 0: continue
				for inst in gs.player(victim).hand:
					if inst.get("revealed", false) and target.id in ContentLoader.card_unit_ids(ContentLoader.card_def(str(inst.definitionId))): amount += 2
				gs._damage_unit(victim, idx, amount, owner, src)
		"jue-grudge":
			if target.is_empty() or not targets(gs, owner, card).has(target.uid): return true
			gs.VerifiedRules.Panguan.destroy(gs, owner, src, 1 - owner, gs._unit_index_by_uid(1 - owner, target.uid), card)
		"jue-awaken":
			unit.awakened = true
			unit.passive_hooks = []
			gs._grow_unit(unit, int(effect.value.attack), int(effect.value.hp))
			for inst in gs.player(1 - owner).hand: reveal(gs, 1 - owner, inst, owner)
		_: return false
	return true

static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	if card.get("formRules", {}).get("bookAvatarDraw", false): gs.player(owner).units[src].swift = true

static func score_card(gs, owner: int, card: Dictionary, target_id) -> Variant:
	if card.get("unitId") not in ["shuweng", "jue"]: return null
	var src: int = gs._source_index(owner, card)
	if src < 0: return -100
	if card.get("effect") in ["book-ink", "jue-bomb"]:
		if gs._unit_index_by_uid(owner, target_id) >= 0: return -100
		return 65
	if card.get("effect") == "jue-grudge": return 80 + int(gs._unit_by_uid(gs.player(1 - owner).units, target_id).get("attack", 0))
	if card.get("effect") == "jue-read":
		var target: Dictionary = gs._unit_by_uid(gs.player(1 - owner).units, target_id)
		var hidden: int = gs.player(1 - owner).hand.filter(func(i): return not i.get("revealed", false) and target.get("id") in ContentLoader.card_unit_ids(ContentLoader.card_def(str(i.definitionId)))).size()
		return 30 + hidden * 8 if hidden > 0 else -100
	if card.get("effect") in ["book-awaken", "jue-awaken"]: return 55 if not gs.player(owner).units[src].awakened else -100
	if card.get("type") == "form": return 50 if gs.player(owner).units[src].get("form", {}).get("cardId") != card.id else -100
	if card.get("effect") == "book-dispatch": return 30 if not gs.player(owner).hand.is_empty() and not gs.player(owner).deck.is_empty() else -100
	if card.get("effect") == "jue-dispatch": return 42
	if card.get("effect") == "book-universe": return 44
	if card.get("id") == "c11901": return 50
	if card.get("jueMimic", false): return 50 + int(card.value) * 4 + int(card.get("combatOption", {}).get("shield", 0)) * 2
	return null
