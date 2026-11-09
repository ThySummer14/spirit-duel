extends RefCounted

const Choice := preload("res://scripts/restored_card_choices.gd")
const KIND := "destiny-deck"
const FOLLOW := "destiny-follow"
const REVERSE := "destiny-reverse"

static func offer(gs, chooser: int, deck_owner: int, continuation: Dictionary = {}) -> bool:
	if not continuation.is_empty(): gs.resolution_stack.append(continuation)
	var deck: Array = gs.player(deck_owner).deck
	if deck.is_empty(): return false
	if deck.size() == 1:
		record(gs, chooser, deck_owner, false)
		return false
	var position := "己方" if chooser == deck_owner else "敌方"
	return Choice.offer(gs, chooser, KIND, [FOLLOW, REVERSE], "命运抉择", {
		"deckOwner": deck_owner,
		"hint": "查看%s牌库顶与牌库底，选择保留位置或交换。" % position,
	})

static func choice_card(gs, chooser: int, id: String):
	if not Choice.matches(gs, chooser, id, KIND): return null
	var deck_owner := int(gs.pending_choice.deckOwner)
	var deck: Array = gs.player(deck_owner).deck
	if deck.is_empty(): return null
	var follow := id == FOLLOW
	var instance: Dictionary = deck.back() if follow else deck.front()
	var card: Dictionary = gs.describe_card_instance(deck_owner, instance, false).duplicate()
	card.name = ("顺应 · 牌库顶｜" if follow else "逆天 · 牌库底｜") + str(card.name)
	card.text = ("保持两张牌的位置。\n" if follow else "交换两张牌的位置。\n") + str(card.get("text", ""))
	if not follow and gs.pending_choice.get("drawOnReverse", false):
		card.choiceExplanation = "交换牌库顶与牌库底，然后抽一张牌。"
	return card

static func choose(gs, chooser: int, id: String) -> bool:
	if not Choice.matches(gs, chooser, id, KIND): return false
	var decision := Choice.accept(gs, chooser, id)
	var deck_owner := int(decision.deckOwner)
	var deck: Array = gs.player(deck_owner).deck
	var reverse := id == REVERSE and deck.size() > 1
	if reverse:
		var bottom: Dictionary = deck.front()
		deck[0] = deck.back()
		deck[deck.size() - 1] = bottom
		if decision.get("drawOnReverse", false):
			gs.resolution_stack.append({"kind": "charm-extra-draw", "playerIndex": chooser, "count": 1})
	if not deck.is_empty(): record(gs, chooser, deck_owner, reverse)
	Choice.finish(gs)
	return true

static func record(gs, chooser: int, deck_owner: int, reverse: bool) -> void:
	var player: Dictionary = gs.player(chooser)
	var field := "destinyReversed" if reverse else "destinyFollowed"
	player[field] = int(player.get(field, 0)) + 1
	gs._log("%s选择%s。" % [player.name, "逆天改命" if reverse else "顺应命运"], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "destiny-resolved", {"player": chooser, "deckPlayer": deck_owner, "reversed": reverse})
	gs.VerifiedRules.BaizeYuanqi.destiny(gs, chooser, deck_owner, gs.player(deck_owner).deck.front() if reverse else {})

static func reveal_top(gs, chooser: int, deck_owner: int) -> Dictionary:
	var deck: Array = gs.player(deck_owner).deck
	if deck.is_empty(): return {}
	return reveal(gs, chooser, deck_owner, deck.back())

static func reveal_bottom(gs, chooser: int, deck_owner: int) -> Dictionary:
	var deck: Array = gs.player(deck_owner).deck
	return {} if deck.is_empty() else reveal(gs, chooser, deck_owner, deck.front())

static func reveal(gs, chooser: int, deck_owner: int, instance: Dictionary) -> Dictionary:
	var card: Dictionary = gs.describe_card_instance(deck_owner, instance, false)
	gs._log("%s揭示了「%s」。" % [gs.player(chooser).name, card.get("name", "未知卡牌")], gs.TONE_CARD)
	gs.VerifiedRules.event(gs, "deck-revealed", {"player": chooser, "deckPlayer": deck_owner, "instanceId": instance.instanceId, "card": card})
	return instance

static func ai_choice(gs, chooser: int):
	if gs.pending_choice.get("type") != KIND: return null
	if int(gs.pending_choice.playerIndex) != chooser: return false
	var deck_owner := int(gs.pending_choice.deckOwner)
	var top = choice_card(gs, chooser, FOLLOW)
	var bottom = choice_card(gs, chooser, REVERSE)
	var reverse := false
	if top != null and bottom != null:
		var top_level := int(top.get("level", 0))
		var bottom_level := int(bottom.get("level", 0))
		reverse = bottom_level < top_level if deck_owner == chooser else bottom_level > top_level
		if gs.VerifiedRules.BaizeYuanqi.prefer_bottom(gs, chooser, deck_owner, top): reverse = true
	if gs.pending_choice.get("drawOnReverse", false): reverse = true
	return choose(gs, chooser, REVERSE if reverse else FOLLOW)
