extends "res://scripts/verify_essence_feast.gd"

# Keep the normal rules/native evidence unchanged; this exercises the AI entry point.
func ai_play(id: String, trick: bool = false) -> void:
	var gs := game()
	var p: Dictionary = gs.player(0)
	tough(gs)
	if id in ["c60303", "c60602"]:
		gs._knockout_unit(p.units[3])
	if id == "c60606" and not trick:
		gs._damage_avatar(0, 1, 1, 0)
	if id == "c63807":
		EF.gain_essence(gs, 0, 1)
		check(gs.play_card(0, 0, p.units[3].uid), "AI fixture marks actual prior ally")
	p.hand.clear()
	var h := give(gs, id)
	if trick:
		p.units[gs._source_index(0, Content.card_def(id))].level = 1
	var mode := " trick" if trick else " main"
	var choice: Dictionary = AI._best_card(gs, 0)
	check(choice.ok and choice.card_id == id and choice.hand == h, "AI selects actual card " + id + mode)
	if not choice.ok:
		return
	check(gs.can_play_card(0, choice.hand, choice.target, bool(choice.get("origin", false))).ok, "AI selects legal target " + id + mode)
	gs.command_log.clear()
	check(AI.take_action(gs, 0), "AI takes actual action " + id + mode)
	check(gs.command_log.any(func(c): return c.c == "play_card" and c.a.get("card", "") == id and c.a.get("target") == choice.target), "AI executes chosen card/target " + id + mode)
	check(gs.resolution_stack.is_empty() and gs.pending_choice.is_empty() and gs.response_window.is_empty(), "AI actual effect completes " + id + mode)

func run() -> void:
	var stores := Support.isolate_stores()
	for role_id in [603, 606, 638]:
		for n in range(1, 9):
			ai_play("c%d%02d" % [role_id, n])
	for id in ["c60307", "c60606", "c60608", "c63808"]:
		ai_play(id, true)
	var gs := game()
	EF.gain_essence(gs, 0, 4)
	gs.player(0).avatarHp = 20
	var choice: Dictionary = AI._best_card(gs, 0)
	check(choice.ok and choice.card_id == "shengmingjinghua" and choice.target == "avatar-0", "AI chooses real neutral stack4 and wounded player")
	check(AI.take_action(gs, 0) and gs.player(0).avatarHp == 24 and gs.player(0).hand.is_empty(), "AI actually uses neutral essence and resolves heal4")
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("ESSENCE_FEAST_AI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
