extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DOG_DEMON_SUN_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(["rihefang", "caitongzi", "quanshen", "taohuayao"], ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 111121166)
	for side in gs.players:
		side.hand.clear(); side.energy = 40; side.levelUpUsed = true
		for unit in side.units: unit.level = 3
	return gs

func give(gs, id: String) -> int:
	var p: Dictionary = gs.player(0)
	p.hand.append({"instanceId": "dog-demon-sun-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return p.hand.size() - 1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "actual use " + id)

func rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var demon: Dictionary = p.units[1]
	play(gs, "c11103")
	check(demon.attack == 6 and demon.get("demonGrowth", 0) == 3, "haoken provides real nonpermanent growth")
	play(gs, "c16606", demon.uid)
	check(demon.attack == 3 and not demon.has("demonGrowth"), "sun reset removes demon growth and its rollback ledger")
	gs._knockout_unit(demon, 1, 0); gs._resolve_resolution_stack()
	gs.VerifiedRules.Peach.revive(gs, 0, 3, demon, false, false)
	check(demon.attack == 3 and demon.maxHp == 4, "later actual knockout and revival preserve base stats")
	play(gs, "c11107")
	check(demon.attack == 6, "reset and knockout preserve broken arm's true historic strength")
	gs = game(); p = gs.player(0); var dog: Dictionary = p.units[2]
	var base_attack := int(dog.attack); var base_hp := int(dog.maxHp)
	play(gs, "xinshen-lianmo")
	check(dog.attack == base_attack + 1 and dog.maxHp == base_hp + 1, "training actually grants permanent +1/+1")
	play(gs, "c16606", dog.uid)
	check(dog.attack == base_attack + 1 and dog.maxHp == base_hp + 1, "sun reset preserves actual permanent training")
	gs._knockout_unit(dog, 1, 0); gs._resolve_resolution_stack()
	gs.VerifiedRules.Peach.revive(gs, 0, 3, dog, false, false)
	check(dog.attack == base_attack + 1 and dog.maxHp == base_hp + 1, "training still persists after subsequent knockout and revival")
	gs = game(); p = gs.player(0); dog = p.units[2]
	base_attack = int(dog.attack); base_hp = int(dog.maxHp)
	play(gs, "c12106")
	check(gs.end_turn(0) and gs.end_turn(1), "real turn cycle triggers awakened dog growth")
	check(dog.attack == base_attack + 2 and dog.maxHp == base_hp + 2, "awakening and end-turn growth are both applied")
	play(gs, "c16606", dog.uid)
	check(dog.attack == base_attack + 2 and dog.maxHp == base_hp + 2, "sun reset preserves both distinct permanent growth sources")
	gs = game(); p = gs.player(0)
	gs._grow_unit(gs.player(1).units[0], 4, 0); var h := give(gs, "c16606")
	var best: Dictionary = AI._best_card(gs, 0)
	check(best.ok and best.hand == h and gs.can_play_card(0, h, best.target).ok, "AI still selects a legal sun-reset target")

func run() -> void:
	var stores := Support.isolate_stores(); var args := OS.get_cmdline_user_args()
	var only := args.has("--rules-only")
	for arg in args:
		if not str(arg).begins_with("--"): out = str(arg)
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme(); rules()
	if not only: await ui_rules()
	Support.cleanup_stores(stores); Support.cleanup_audio(); await process_frame; await process_frame
	print("DOG_DEMON_SUN_OK checks=%d failures=%d rules_only=%s" % [checks, failures, only])
	quit(0 if failures == 0 else 1)

func ui_rules() -> void:
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var b := Battle.new(); b.setup(["rihefang", "caitongzi", "quanshen", "taohuayao"], ["bingyong", "fenghuanghuo", "yaodaoji", "baizangzhu"], 111166)
		b._ai_thinking = true
		for side in b.gs.players:
			side.hand.clear(); side.energy = 40; side.levelUpUsed = true
			for unit in side.units: unit.level = 3
		root.add_child(b); await create_timer(0.3).timeout; await settled(b)
		var p: Dictionary = b.gs.player(0); var demon: Dictionary = p.units[1]; var dog: Dictionary = p.units[2]
		hand(b, ["c11103"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(demon.attack == 6, "mouse uses haoken for real temporary strength")
		hand(b, ["c16606"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		check(b._pending_target_card == 0 and b._unit_widget(demon.uid).selected, "actual target interface exposes demon")
		await capture("%d-01-reset-target" % physical.x)
		await click(b._unit_widget(demon.uid)); await settled(b)
		check(demon.attack == 3 and not demon.has("demonGrowth"), "mouse reset removes growth once")
		b.gs._knockout_unit(demon, 1, 0); b.gs._resolve_resolution_stack(); b.gs.VerifiedRules.Peach.revive(b.gs, 0, 3, demon, false, false)
		check(demon.attack == 3 and demon.maxHp == 4, "mouse-triggered reset does not reappear after knockout")
		var attack := int(dog.attack); var hp := int(dog.maxHp)
		hand(b, ["xinshen-lianmo"]); b.gs.kw_usage(0, "instant").used = false
		await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		hand(b, ["c16606"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
		await click(b._unit_widget(dog.uid)); await settled(b)
		check(dog.attack == attack + 1 and dog.maxHp == hp + 1, "mouse reset preserves permanent dog training")
		await capture("%d-02-permanent-training" % physical.x)
		b.queue_free(); await process_frame; await process_frame
