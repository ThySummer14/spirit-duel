extends SceneTree

const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("RESTORATION_CROSS_FAIL ", message)

func game() -> GS:
	var gs := GS.create(["yujiazhu", "yi", "mianqiling", "rihefang"], ["mianqiling", "bingyong", "taohuayao", "shuweng"], 189208239)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	gs.rule_events.clear()
	return gs

func give(gs, id: String, owner: int = 0) -> String:
	var iid := "restoration-cross-%d" % gs.next_card_id
	gs.next_card_id += 1
	gs.player(owner).hand.append({"instanceId": iid, "definitionId": id})
	return iid

func play(gs, id: String, target = null, owner: int = 0) -> String:
	var iid := give(gs, id, owner)
	check(gs.play_card(owner, gs.player(owner).hand.size() - 1, target), "actual use " + id)
	return iid

func finish(gs) -> void:
	var guard := 0
	while not gs.pending_choice.is_empty() and guard < 30:
		guard += 1
		check(AI._resolve_choice(gs, 0), "resume actual choice " + str(gs.pending_choice.get("type", "")))
	check(guard < 30 and gs.resolution_stack.is_empty(), "cross-character continuations finish")

func talisman_damage() -> void:
	var gs := game()
	gs.current_player = 1
	play(gs, "c20803", null, 1)
	check(gs.resolve_divination_choice(1, "青岚"), "enemy selects its actual form faction")
	gs.current_player = 0
	var target: Dictionary = gs.player(1).units[0]
	play(gs, "c18901", target.uid)
	var hp := int(target.hp)
	var hit := gs._damage_unit(1, 0, 1, 0, 2)
	check(hit.dealt == 0 and int(target.hp) == hp and target.has("yujDoomTurn"), "same-faction damage reduced to zero cannot trigger drive talisman")
	hit = gs._damage_unit(1, 0, 2, 0, 2)
	gs._resolve_resolution_stack()
	check(int(hit.dealt) == 1 and int(target.hp) == 0, "one actual damage after faction reduction triggers the real marked knockout")
	check(not target.has("yujDoomTurn") and target.form.is_empty(), "actual knockout removes talisman and form together")

func review_and_search() -> void:
	var gs := game()
	var p: Dictionary = gs.player(0)
	var realm_iid := play(gs, "c18906")
	var form_iid := play(gs, "c20806")
	check(int(gs.VerifiedRules.Yujiazhu.quote_burst(gs, 0, 0, 3).amount) == 2, "installed fox realm actually discounts nominal burst")
	check(gs.VerifiedRules.Combat.has(p.units[2], "veil"), "installed blue wheel has its real faction keyword")
	play(gs, "c23907")
	check(p.realms.is_empty() and p.units[2].form.is_empty(), "review removes both real realm and form before shuffle divination")
	check(gs.pending_choice.get("type") == "native-divination", "returned objects cause an actual resumable shuffle ability")
	check(not gs.VerifiedRules.Combat.has(p.units[2], "veil") and int(gs.VerifiedRules.Yujiazhu.quote_burst(gs, 0, 0, 3).amount) == 3, "removed form and realm no longer provide veil or burst discount")
	check(p.deck.any(func(i): return str(i.instanceId) == realm_iid) and p.deck.any(func(i): return str(i.instanceId) == form_iid), "review returns both exact physical instances")
	finish(gs)
	check(gs.rule_events.filter(func(e): return e.kind == "yi-shuffle-divination").size() == 1, "returning multiple objects shuffles the same deck once")
	var wheel_events := gs.rule_events.filter(func(e): return e.kind == "mian-reincarnation").size()
	check(gs.end_turn(0) and gs.end_turn(1), "actual turn cycle after review")
	check(gs.rule_events.filter(func(e): return e.kind == "mian-reincarnation").size() == wheel_events, "returned wheel cannot change faction at next turn start")
	play(gs, "c23904", p.units[0].uid)
	check(gs.pending_choice.get("type") == "yi-search" and realm_iid in gs.pending_choice.instanceIds, "ally search offers the returned physical realm")
	check(gs.resolve_divination_choice(0, realm_iid), "player retrieves that exact returned realm")
	var idx: int = p.hand.find_custom(func(i): return str(i.instanceId) == realm_iid)
	check(idx >= 0 and gs.play_card(0, idx), "returned and retrieved realm can actually be replayed")
	check(int(gs.VerifiedRules.Yujiazhu.quote_burst(gs, 0, 0, 3).amount) == 2, "replaying restored realm reinstates its real discount")

func burst_payment_labels() -> void:
	var gs := game()
	gs.player(0).units[0].charge = 3
	give(gs, "c18904")
	check(gs.VerifiedRules.Movement.request_burst(gs, 0, 0), "ordinary burst opens real payment choice")
	check(gs.VerifiedRules.Movement.choice_card(gs, 0, "burst:3").currentCardStats == "爆能3", "unmodified burst keeps its existing badge")
	gs = game()
	play(gs, "c16607")
	gs.player(0).units[0].charge = 0
	give(gs, "c18904")
	check(gs.VerifiedRules.Movement.request_burst(gs, 0, 0), "awakened sun permits an actual zero-energy burst choice")
	check(gs.VerifiedRules.Movement.choice_card(gs, 0, "burst:3").currentCardStats == "爆能3 · 日和坊免支付", "free burst badge states the real waived payment")
	check(not gs.player(0).has("sunFreeChargeTurn") and int(gs.player(0).units[0].charge) == 0, "viewing the free option cannot consume the allowance or energy")

func _initialize() -> void:
	talisman_damage()
	review_and_search()
	burst_payment_labels()
	print("RESTORATION_CROSS_OK checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
