extends "res://scripts/verify_insight.gd"

const Chen := preload("res://scripts/chen_rules.gd")
const CHEN_TEAM := ["chen", "shantong", "yaohu", "bailang"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CHEN_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(CHEN_TEAM, FOE, 621)
	prepare(gs)
	return gs

func hand_and_area() -> void:
	var gs := GS.create(CHEN_TEAM, FOE, 621)
	var p := gs.player(0)
	var src: Dictionary = p.units[0]
	check(src.attack == 2 and src.hp == 4 and p.hand.any(func(i): return i.definitionId == "c62101"), "first real upgrade gives course")
	p.hand.clear()
	gs._knockout_unit(src)
	check(gs.VerifiedRules.UpgradeBlessing.raise_level(gs, 0, 0) and p.hand.any(func(i): return i.definitionId == "c62101"), "actual knocked upgrade still gives course")

	gs = game()
	p = gs.player(0)
	src = p.units[0]
	src.level = 1
	play(gs, "c62101")
	check(gs.pending_choice.instanceIds == ["chen-qisha", "chen-tianliang"], "course lists only missing at eligible level")
	check(not gs.resolve_divination_choice(0, "chen-tianfu") and gs.resolve_divination_choice(0, "chen-qisha"), "invalid choice rejected, legal card placed")
	check(Chen.present(gs, 0).size() == 1 and src.attack == 3, "placed qisha immediately grants power")
	var original: Dictionary = Chen.present(gs, 0)[0]
	play(gs, "c62103")
	check(gs.resolve_divination_choice(0, original.instanceId) and p.hand[0].definitionId == original.definitionId and p.hand[0].instanceId != original.instanceId, "copy uses selected instance and preserves original")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 0, "copy has no cost this turn")
	gs.turn_counter += 1
	check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 1, "copy discount expires")
	p.hand.clear()
	play(gs, "c62102")
	var before: int = p.hand.size()
	check(gs.play_card(0, zone_index(gs, "chen-qisha")) and p.hand.size() == before + 1, "qisha resolves real combat and draw")
	check(not Insight.active(gs, 0) and src.attack == 2 and src.maxHp == 6 and zone_index(gs, "chen-tianliang") >= 0, "using blessing removes its aura and adds the missing other of equal level")
	play(gs, "c62101")
	check(gs.pending_choice.instanceIds == ["chen-qisha"], "present blessing is excluded")
	check(gs.resolve_divination_choice(0, "chen-qisha"), "re-add previously consumed blessing")
	src.level = 3
	play(gs, "c62104")
	check(src.attack == 5 and src.maxHp == 8, "form locks printed enhancement separately from standing aura")
	var li: Dictionary = Insight.zone(gs, 0)[zone_index(gs, "chen-tianliang")]
	Insight.remove(gs, 0, li)
	check(src.maxHp == 6, "only the zone health bonus drops after card leaves")

func realms_and_ward() -> void:
	var gs := game()
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	u.level = 2
	play(gs, "c62105")
	check(Insight.active(gs, 0) and Chen.present(gs, 0).size() == 2 and Chen.present(gs, 0).all(func(i): return int(Content.card_def(i.definitionId).level) <= 2), "shift draws two distinct eligible blessings")
	Insight.leave_action(gs, 0)
	play(gs, "c62106")
	check(p.realms[0].hp == 4 and Chen.present(gs, 0).size() == 3 and not Insight.active(gs, 0), "realm grants another blessing below threshold")
	turn(gs, 0)
	turn(gs, 1)
	check(Insight.active(gs, 0), "realm enters insight at three on next turn")

	gs = game()
	p = gs.player(0)
	u = p.units[0]
	play(gs, "c62107")
	check(gs.resolve_divination_choice(0, "chen-tianxiang") and u.maxHp == 6, "gatekeeper can choose any level")
	check(gs._damage_unit(0, 0, 6, 1).damage == 5 and u.hp == 1 and Chen.present(gs, 0).size() == 1, "reduction checked before lethal and consumes nothing")
	check(gs._damage_unit(0, 0, 2, 1).damage == 0 and u.hp == 1 and Chen.present(gs, 0).is_empty(), "lethal damage prevented by consuming actual card")
	Chen.add(gs, 0, "chen-qisha")
	check(gs.VerifiedRules.Panguan.destroy(gs, 1, 0, 0, 0), "second direct destruction on same turn is not prevented")
	check(Chen.present(gs, 0).size() == 1, "second event consumes no extra blessing")

	gs = game()
	play(gs, "c62107")
	check(gs.resolve_divination_choice(0, "chen-tianfu"), "choose ward fuel")
	check(not gs.VerifiedRules.Panguan.destroy(gs, 1, 0, 0, 0) and gs.player(0).units[0].hp == 6 and Chen.present(gs, 0).is_empty(), "first direct destruction is prevented")

func awakening_and_battle() -> void:
	var gs := game()
	var p := gs.player(0)
	for id in ["chen-qisha", "chen-tianliang", "chen-tianji"]: Chen.add(gs, 0, id)
	play(gs, "c62108")
	check(Insight.active(gs, 0) and p.units[0].awakened and not p.get("chenNextFree", false), "printed entry insight precedes awakening")
	turn(gs, 0)
	turn(gs, 1)
	check(Insight.active(gs, 0) and p.chenNextFree, "awake next turn enters and grants cost waiver")
	var before: int = p.energy
	check(gs.play_card(0, zone_index(gs, "chen-qisha")) and p.energy == before and not p.chenNextFree, "one actual blessing uses waiver")
	Insight.enter(gs, 0)
	check(not p.chenNextFree, "no second trigger that turn")

	gs = game()
	p = gs.player(0)
	var enemy: Dictionary = gs.player(1).units[0]
	enemy.front = 1
	enemy.hp = 20
	enemy.attack = 7
	Chen.add(gs, 0, "chen-tianliang")
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, "chen-tianliang")) and p.units[0].hp == 4 and enemy.hp == 16, "tianliang attack has combat immunity")
	gs._knockout_unit(p.units[0])
	Chen.add(gs, 0, "chen-tiantong")
	Insight.enter(gs, 0)
	enemy.hp = 1
	enemy.attack = 0
	check(gs.play_card(0, zone_index(gs, "chen-tiantong")) and p.units[0].hp > 0 and gs.player(1).avatarHp < 30, "tiantong can be played while knocked out and revives before piercing attack")

	gs = game()
	p = gs.player(0)
	p.avatarHp = 20
	Chen.add(gs, 0, "chen-tianji")
	Insight.enter(gs, 0)
	check(gs.VerifiedRules.Combat.has(p.units[0], "veil"), "tianji grants zone veil")
	check(gs.play_card(0, zone_index(gs, "chen-tianji")) and p.avatarHp == 24 and not gs.VerifiedRules.Combat.has(p.units[0], "veil"), "tianji card steals life and its zone veil departs")

func ai_and_assets() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c621%02d" % n
		if n == 3: Chen.add(gs, 0, "chen-qisha")
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI actually plays " + id)
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, 0) and gs.pending_choice.is_empty(), "AI resolves blessing choice")
		var texture := load("res://assets/official/cards/%s.png" % id)
		check(texture is Texture2D and texture.get_width() > 200, "original art loads " + id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(CHEN_TEAM, FOE, 621)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c62101", "c62103"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var option = choice_face(b, "chen-qisha")
		check(option != null, "native derived blessing choice is visible")
		await click(option)
		await settled(b)
		var placed: Array = Chen.present(gs, 0)
		check(placed.size() == 1 and gs.player(0).units[0].attack == 3, "native choice places exact card and aura")
		await click(b._hand_row.get_child(0))
		await settled(b)
		if not placed.is_empty():
			var copied = choice_face(b, placed[0].definitionId)
			check(copied != null, "native copy displays real instance")
			if copied != null: await click(copied)
			await settled(b)
			check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 0, "native copy resolves actual discount")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	hand_and_area()
	realms_and_ward()
	awakening_and_battle()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("CHEN checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
