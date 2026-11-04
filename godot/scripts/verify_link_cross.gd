extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const Link := preload("res://scripts/link_rules.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LINK_CROSS_FAIL ", message)

func instance(gs, id: String) -> Dictionary:
	gs.next_card_id += 1
	return {"instanceId": "link-cross-%d" % gs.next_card_id, "definitionId": id}

func _initialize() -> void:
	var gs := GS.create(["liangmianfo", "biyehua", "shuweng", "xuenv"], ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 238)
	for side in gs.players:
		side.hand.clear()
		side.deck.clear()
		side.energy = 20
		side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	var p: Dictionary = gs.player(0)
	var foe: Dictionary = gs.player(1)
	check(gs.card_instance(0, -1).is_empty() and not gs.can_play_card(0, -1).ok, "negative hand index is rejected with no active link")
	# Generate deck permission through a real linked card, not a fabricated grant.
	p.hand.append(instance(gs, "c23808"))
	check(gs.play_card(0, 0), "install wind/thunder form")
	p.deck.append(instance(gs, "c23802"))
	p.hand.append(instance(gs, "c23801"))
	check(gs.play_card(0, 0) and gs.pending_choice.get("type") == "native-link", "real use opens link choice")
	var original := str(gs.pending_choice.options[0].instanceId)
	check(gs.resolve_divination_choice(0, original) and Link.ready_hand(gs, 0) == 0, "select original card")
	check(gs.play_card(0, 0) and gs.playable_card_count(0) == 1, "resolve use and make other deck card available")
	# The Firelight Road bonus is explicitly a hand-card effect. The other
	# form's deck permission must neither claim hand origin nor trigger it.
	p.realms.append({"uid": "cross-road", "hp": 5, "nativeRealm": "lily-road"})
	p.realms.append({"uid": "cross-voyage", "hp": 5, "nativeRealm": "lily-voyage"})
	p.deck.append(instance(gs, "c11902"))
	check(gs.playable_card_count(0) == 2 and gs.hand_card_def(0, 0).get("lilyFromDeck", false), "voyage top and separately granted deck card occupy distinct slots")
	var view: Dictionary = gs.hand_card_def(0, 1)
	check(view.get("twoFacesFromDeck", false) and view.sourceZone == "deck", "wind form card retains its actual deck origin")
	check(not view.has("lilyRoadDamage") and not view.get("lilyFromDeck", false) and not view.keywords.has("instant"), "hand-only lily realm does not enhance the deck card")
	var avatar_hp := int(p.avatarHp)
	var fire := int(p.energy)
	var deck_id := str(gs.card_instance(0, 1).instanceId)
	check(gs.play_card(0, 1, foe.units[0].uid), "use granted deck card against legal target")
	check(int(p.avatarHp) == avatar_hp and int(p.energy) == fire and not gs.kw_usage(0, "instant").used, "first deck use is free without lily self-damage or instant consumption")
	check(p.deck.size() == 1 and p.deck.back().definitionId == "c11902", "using granted card preserves the different voyage top")
	var command: Dictionary = gs.command_log.filter(func(item): return item.c == "play_card").back()
	check(command.a.get("sourceZone") == "deck" and command.a.get("instanceId") == deck_id, "command log preserves deck origin and physical instance")
	p.hand.append(instance(gs, "c23802"))
	view = gs.hand_card_def(0, 0)
	check(view.sourceZone == "hand" and view.get("lilyRoadDamage", 0) == 1 and view.keywords.has("instant"), "same realm still enhances an actual level-one hand card")
	check(gs.play_card(0, 0, foe.units[1].uid) and int(p.avatarHp) == avatar_hp - 1, "actual enhanced hand use pays the realm's self-damage")
	# Wind/thunder form observes links from other allies as well.
	gs = GS.create(["liangmianfo", "heitongzi", "baitongzi", "shuweng"], ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 239)
	for side in gs.players:
		side.hand.clear()
		side.deck.clear()
		side.energy = 20
		side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	p = gs.player(0)
	p.hand.append(instance(gs, "c23808"))
	check(gs.play_card(0, 0), "install form for another ally's link")
	p.hand.append(instance(gs, "c24007"))
	p.deck.append(instance(gs, "c24107"))
	check(gs.play_card(0, 0) and gs.pending_choice.get("type") == "native-link", "black and white ally triggers a separate real link")
	original = str(gs.pending_choice.options[0].instanceId)
	check(gs.resolve_divination_choice(0, original) and gs.play_card(0, 0), "finish black ally's linked form")
	view = gs.hand_card_def(0, 0)
	check(view.id == "c24107" and view.get("twoFacesFromDeck", false) and not view.get("linkedUse", false), "form grants the unselected ally card without inventing a linked enhancement")
	fire = int(p.energy)
	check(gs.play_card(0, 0) and int(p.energy) == fire and p.deck.is_empty() and gs.pending_choice.is_empty(), "granted ally card is usable from deck without a recursive link")
	print("LINK_CROSS_OK checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
