extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const UNIT := "luohou"
const TOKEN := "luohou-malefic-star"
const REALM := "w13-luohou-93146"
const DISCARD := "w13-luohou-93147"
const DISCARD_CHOICE := "luohou-discard"

static func source(gs, owner: int) -> int:
	return gs._source_index(owner, {"unitId": UNIT})

static func active(unit: Dictionary) -> bool:
	return int(unit.hp) > 0 and int(unit.level) > 0 and not unit.get("baseRulesSuppressed", false) and not unit.get("removed", false)

static func frame(gs, owner: int, action: String, extra: Dictionary = {}) -> void:
	gs.resolution_stack.append({"kind": "luohou-" + action, "playerIndex": owner}.merged(extra))

static func star_indices(cards: Array) -> Array:
	return range(cards.size()).filter(func(i): return cards[i].definitionId == TOKEN)

static func divining(gs, deck_owner: int, controller: int) -> void:
	var idx := source(gs, controller)
	if idx < 0: return
	var unit: Dictionary = gs.player(controller).units[idx]
	if not active(unit): return
	var p: Dictionary = gs.player(controller)
	if not unit.awakened and int(p.get("luohouDivinedTurn", -1)) == gs.turn_counter: return
	p.luohouDivinedTurn = gs.turn_counter
	var deck: Array = gs.player(deck_owner).deck
	var count := 2 if unit.awakened else 1
	for _i in count:
		var star: Dictionary = gs.VerifiedRules.Insight.instance(gs, deck_owner, TOKEN)
		deck.insert(int(gs.next_random() % (deck.size() + 1)), star)
	gs.VerifiedRules.event(gs, "luohou-stars-inserted", {"player": controller, "deckPlayer": deck_owner, "count": count})

static func drawn(gs, owner: int, inst: Dictionary, draw_context: Dictionary = {}) -> void:
	if gs.opening_deal: return
	var p: Dictionary = gs.player(owner)
	var idx := source(gs, owner)
	var card := Content.card_def(str(inst.definitionId))
	if card.get("luohouMalefic", false):
		frame(gs, owner, "draw")
		if draw_context.has("luohouDeathOmen"):
			frame(gs, owner, "death-omen-hit", {"context": draw_context.luohouDeathOmen, "iid": inst.instanceId})
	if idx >= 0 and card.get("luohouOuterStar", false):
		var unit: Dictionary = p.units[idx]
		if active(unit) and unit.get("formRules", {}).get("luohouBlackForm", false) and int(unit.get("luohouBlackTurn", -1)) != gs.turn_counter:
			unit.luohouBlackTurn = gs.turn_counter
			frame(gs, owner, "black-hit")
	if int(p.get("restoredDrawCount", 0)) == 2 and p.realms.any(func(r): return r.get("cardId", "") == REALM and int(r.hp) > 0):
		frame(gs, owner, "realm-hit")

static func end_turn(gs, owner: int) -> void:
	var hand: Array = gs.player(owner).hand
	var stars := star_indices(hand)
	for i in range(stars.size() - 1, -1, -1):
		frame(gs, owner, "expire", {"iid": hand[stars[i]].instanceId})

static func can_use(gs, owner: int, card: Dictionary, inst: Dictionary) -> bool:
	if card.id != DISCARD: return true
	return gs.player(owner).hand.any(func(other): return other.instanceId != inst.instanceId)

static func targets(gs, owner: int, card: Dictionary):
	if card.get("effect") != "luohou-scorch": return null
	var result: Array = []
	for side in [owner, 1-owner]:
		for unit in gs.player(side).units:
			if int(unit.hp) <= 0 or not gs.VerifiedRules.OwlInsect.shikigami(unit): continue
			if side != owner and (gs.VerifiedRules.Combat.has(unit, "veil") or gs.VerifiedRules.Movement.has_veil(unit)): continue
			result.append(unit.uid)
	return result

static func can_play_malefic(gs, owner: int, card: Dictionary, target) -> Dictionary:
	if target != null: return {"ok": false, "reason": "凶星没有目标。"}
	return gs.VerifiedRules.BattleShop.can_play_neutral(gs, owner, card, target)

static func resolve_frame(gs, item: Dictionary) -> bool:
	var kind := str(item.get("kind", ""))
	if not kind.begins_with("luohou-"):
		var card: Dictionary = item.get("cardOverride", {})
		if not card.get("luohouMalefic", false): return false
		if kind == "card-announce":
			gs.VerifiedRules.Xuan.announced(gs, int(item.playerIndex), card)
			gs._log("%s 使用「凶星」。" % gs.player(int(item.playerIndex)).name, gs.TONE_CARD)
			gs.VerifiedRules.event(gs, "card-announced", {"player": int(item.playerIndex), "card": card, "uid": ""})
		return true
	var owner := int(item.playerIndex)
	var idx := source(gs, owner)
	var p: Dictionary = gs.player(owner)
	match kind:
		"luohou-draw": gs._draw(owner, 1)
		"luohou-heal": gs._heal_avatar(owner, 3)
		"luohou-fire": gs._set_fire(owner, int(p.energy) + 1)
		"luohou-enemy-discard":
			var hand: Array = gs.player(1-owner).hand
			if not hand.is_empty(): gs.discard_hand_card(1-owner, int(gs.next_random() % hand.size()))
		"luohou-divine": gs.VerifiedRules.Divination.start(gs, owner, int(item.count))
		"luohou-black-hit": gs.VerifiedRules.base_damage_avatar(gs, owner, idx, 1-owner, 3)
		"luohou-realm-hit":
			for i in gs.player(1-owner).units.size():
				var unit: Dictionary = gs.player(1-owner).units[i]
				if int(unit.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(unit):
					gs.VerifiedRules.base_damage_unit(gs, owner, idx, 1-owner, i, 1)
		"luohou-death-omen-draw":
			gs._draw(owner, 3, -1, {"luohouDeathOmen": item.context})
		"luohou-death-omen-hit":
			var old: Dictionary = gs._card_effect_context
			gs._card_effect_context = item.context
			var src := int(item.context.get("sourceIndex", idx))
			for i in gs.player(1-owner).units.size():
				var enemy: Dictionary = gs.player(1-owner).units[i]
				if int(enemy.hp) > 0 and gs.VerifiedRules.OwlInsect.shikigami(enemy):
					gs._damage_unit(1-owner, i, 1, owner, src)
			gs._card_effect_context = old
			gs.VerifiedRules.event(gs, "luohou-death-omen", {"player": owner, "instanceId": item.iid})
		"luohou-scorch-queue":
			var hand: Array = p.hand
			var indices := star_indices(hand)
			for i in range(indices.size() - 1, -1, -1): p.deck.append(hand.pop_at(indices[i]))
			if not indices.is_empty():
				gs._shuffle(p.deck)
				gs.VerifiedRules.Glutton.mark_hand(gs, owner)
				for _i in indices.size(): frame(gs, owner, "spell-hit", {"uid": item.uid, "side": item.side, "context": item.context})
		"luohou-spell-hit":
			var victim := int(item.side)
			var target: int = gs._unit_index_by_uid(victim, item.uid)
			if target >= 0:
				var old: Dictionary = gs._card_effect_context
				gs._card_effect_context = item.context
				gs._damage_unit(victim, target, 1, owner, idx)
				gs._card_effect_context = old
		"luohou-transit":
			var deck: Array = p.deck
			var revealed := deck.slice(maxi(0, deck.size()-6))
			for inst in revealed:
				gs.VerifiedRules.event(gs, "deck-revealed", {"player": owner, "deckPlayer": owner, "instanceId": inst.instanceId, "card": gs.describe_card_instance(owner, inst)})
			for inst in revealed:
				if inst.definitionId != TOKEN: continue
				deck.erase(inst)
				frame(gs, owner, "transfer", {"star": inst, "context": item.context})
		"luohou-transfer":
			var hand: Array = gs.player(1-owner).hand
			if hand.size() < int(gs.rules.maxHandSize):
				gs.VerifiedRules.Baize.put_hand(gs, 1-owner, item.star)
			else:
				var old: Dictionary = gs._card_effect_context
				gs._card_effect_context = item.context
				gs.VerifiedRules.ThreeTail.projectile(gs, owner, idx, 3, "凶星凌日")
				gs._card_effect_context = old
		"luohou-expire":
			var index: int = p.hand.find_custom(func(inst): return inst.instanceId == item.iid)
			if index >= 0:
				gs.discard_hand_card(owner, index)
				if idx >= 0: gs._heal_avatar(owner, 1)
				else: gs._damage_avatar(owner, 2)
	return true

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary) -> bool:
	match str(effect.get("action", "")):
		"luohou-scorch":
			if target.is_empty(): return true
			var side := owner if gs._unit_index_by_uid(owner, target.uid) >= 0 else 1-owner
			var idx: int = gs._unit_index_by_uid(side, target.uid)
			frame(gs, owner, "scorch-queue", {"uid": target.uid, "side": side, "context": gs._card_effect_context})
			gs._damage_unit(side, idx, 5, owner, src)
		"luohou-augury":
			var deck: Array = gs.player(owner).deck
			for _i in 2: deck.append(gs.VerifiedRules.Insight.instance(gs, owner, TOKEN))
			gs._shuffle(deck)
			frame(gs, owner, "draw")
			gs.VerifiedRules.Divination.start(gs, owner, 2)
		"luohou-death-omen":
			frame(gs, owner, "death-omen-draw", {"context": gs._card_effect_context})
			gs.VerifiedRules.Divination.start(gs, owner, 3)
		"luohou-black-form":
			gs._apply_form(owner, src, card)
			frame(gs, owner, "heal")
			gs.VerifiedRules.Divination.start(gs, owner, 2)
		"luohou-transit":
			frame(gs, owner, "transit", {"context": gs._card_effect_context})
			gs.VerifiedRules.Divination.start(gs, owner, 6, owner, {"luohouTransit": true})
		"luohou-realm": gs._deploy_realm(owner, card)
		"luohou-discard":
			var ids: Array = gs.player(owner).hand.map(func(inst): return inst.instanceId)
			Choice.offer(gs, owner, DISCARD_CHOICE, ids, "趋凶避吉", {"zone": "hand", "hint": "选择要弃掉的一张手牌。"})
		"luohou-awake":
			gs._awaken(owner, src, card, {"attack": 1, "hp": 1})
			gs.VerifiedRules.Divination.start(gs, 1-owner, 2, owner, {"luohouOpponent": true})
		_: return false
	return true

static func choice_card(gs, owner: int, iid: String):
	if not Choice.matches(gs, owner, iid, DISCARD_CHOICE): return null
	for inst in gs.player(owner).hand:
		if str(inst.instanceId) == iid:
			var view: Dictionary = gs.describe_card_instance(owner, inst).duplicate(true)
			view.choiceInstanceId = iid
			return view
	return null

static func choose(gs, owner: int, iid: String) -> bool:
	if not Choice.matches(gs, owner, iid, DISCARD_CHOICE): return false
	var hand: Array = gs.player(owner).hand
	var i := hand.find_custom(func(inst): return str(inst.instanceId) == iid)
	if i < 0: return false
	Choice.accept(gs, owner, iid)
	var discard_star: bool = hand[i].definitionId == TOKEN
	if discard_star: frame(gs, owner, "enemy-discard")
	frame(gs, owner, "fire")
	frame(gs, owner, "divine", {"count": 2})
	gs.discard_hand_card(owner, i)
	Choice.finish(gs)
	return true

static func ai_choice(gs, owner: int):
	if gs.pending_choice.get("type") != DISCARD_CHOICE: return null
	if int(gs.pending_choice.get("playerIndex", -1)) != owner: return false
	var cards: Array = gs.player(owner).hand.filter(func(inst): return inst.instanceId in gs.pending_choice.instanceIds)
	cards.sort_custom(func(a, b): return discard_score(gs, owner, a) > discard_score(gs, owner, b))
	return choose(gs, owner, str(cards[0].instanceId)) if not cards.is_empty() else false

static func discard_score(gs, owner: int, inst: Dictionary) -> int:
	if inst.definitionId == TOKEN: return 100
	var card := Content.card_def(str(inst.definitionId))
	var idx: int = gs._source_index(owner, card)
	if idx < 0: return 40
	return int(card.level) + (20 if int(gs.player(owner).units[idx].level) < int(card.level) else 0)

static func prefer_divination(gs, owner: int, deck_owner: int, card: Dictionary):
	if card.id != TOKEN: return null
	if gs.pending_choice.get("luohouTransit", false): return true
	if deck_owner != owner: return source(gs, deck_owner) < 0
	return true

static func score(gs, owner: int, card: Dictionary, target):
	if not card.get("luohouRules", false): return null
	var p: Dictionary = gs.player(owner)
	var foe: Dictionary = gs.player(1-owner)
	match str(card.effect):
		"luohou-malefic":
			return 1 if source(gs, owner) >= 0 and p.hand.size() >= int(gs.rules.maxHandSize) - 1 else (-20 if source(gs, owner) >= 0 else 15 + (45 if int(p.avatarHp) <= 6 else 0))
		"luohou-scorch":
			var idx: int = gs._unit_index_by_uid(1-owner, target)
			if idx < 0: return -50
			var enemy: Dictionary = foe.units[idx]
			var amount := 5 + star_indices(p.hand).size()
			return 50 + (23 if int(enemy.hp) + int(enemy.shield) <= amount else 0)
		"luohou-augury": return 50
		"luohou-death-omen":
			var stars := star_indices(p.deck).size()
			return 45 + 3 * mini(6, stars) if p.deck.size() - stars >= 3 else -50
		"luohou-black-form": return 55
		"luohou-transit": return 18 + star_indices(p.deck).size() * 4
		"luohou-realm": return 45 if not p.realms.any(func(r): return r.get("cardId", "") == REALM) else 5
		"luohou-discard": return 60 if not star_indices(p.hand).is_empty() else 31
		"luohou-awake": return 65
	return 0
