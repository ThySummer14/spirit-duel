extends "res://scripts/verify_insight.gd"

const RAIN_TEAM := ["yunv", "shantong", "yaohu", "bailang"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("RAIN_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(RAIN_TEAM, FOE, 620)
	prepare(gs)
	return gs

func passive_and_keeps() -> void:
	var gs := game()
	var p := gs.player(0)
	p.avatarHp = 29
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, Insight.STAR), "avatar-1") and p.avatarHp == 30 and p.avatarArmor == 0, "normal heal before cap")
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, Insight.STAR), "avatar-1") and p.avatarArmor == 1, "full health converts overflow")
	play(gs, "c62005")
	check(p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 5 and Insight.active(gs, 0), "awake body and entry insight")
	check(not gs.can_play_card(0, zone_index(gs, Insight.MOON), "invalid").ok, "invalid neutral target cannot consume")
	var friend: Dictionary = p.units[1]
	friend.hp -= 2
	p.avatarHp = 28
	put(gs, "c62006")
	check(gs.play_card(0, zone_index(gs, "c62006"), gs.player(1).units[0].uid) and p.avatarHp == 30 and p.avatarArmor == 2 and friend.hp == friend.maxHp - 1, "dedicated zone use heals team and extra avatar overflow")

	gs = game()
	p = gs.player(0)
	play(gs, "c62008")
	var realm: Dictionary = p.realms[0]
	check(realm.hp == 5 and p.hand.size() == 1 and Insight.active(gs, 0), "home enters and performs real normal draw")
	put(gs, "c62006")
	put(gs, "c62006")
	var idx := zone_index(gs, "c62006")
	check(gs.hand_card_def(0, idx).insightKeeps and gs._kw(gs.hand_card_def(0, idx), "instant"), "eligible card preview reflects home")
	check(gs.play_card(0, idx, "avatar-0") and Insight.active(gs, 0) and realm.rainKeepTurn == gs.turn_counter, "first dedicated card stays in insight")
	check(not gs.hand_card_def(0, zone_index(gs, "c62006")).get("insightKeeps", false), "bonus used once per turn")
	check(gs.play_card(0, zone_index(gs, "c62006"), "avatar-0") and not Insight.active(gs, 0), "second dedicated card ends insight")
	turn(gs, 0)
	turn(gs, 1)
	check(Insight.active(gs, 0) and p.hand.size() == 3, "next own turn realm grants insight and one extra draw")

func other_effects() -> void:
	var gs := game()
	var p := gs.player(0)
	play(gs, "c62001")
	check(Insight.active(gs, 0) and p.hand.size() == 1 and Insight.zone(gs, 0).size() == 3, "draw goes to original hand")
	Insight.leave_action(gs, 0)
	play(gs, "c62002")
	check(p.realms[0].hp == 3 and gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1, "bridge adds one genuine guard")
	Insight.enter(gs, 0)
	check(gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1, "bridge cannot repeat this turn")
	Insight.leave_action(gs, 0)
	play(gs, "c62003")
	var tear := gs.front_unit(0)
	check(tear.get("id") == "rain-tear" and tear.attack == 2 and tear.hp == 2 and tear.summoned, "form creates actual 2/2 summon")
	Insight.enter(gs, 0)
	check(gs.front_unit(0).uid == tear.uid, "same turn does not replace tear")
	check(gs.basic_attack(0, 1, p.units[1].uid) and tear.get("removed", false), "guard moves an actual ally and departed tear is removed")

	gs = game()
	p = gs.player(0)
	play(gs, "c62004")
	check(p.hand.size() == 1 and Insight.active(gs, 0), "repeat spell immediately draws and enters")
	turn(gs, 0)
	turn(gs, 1)
	check(p.hand.size() == 3 and Insight.active(gs, 0), "next own turn repeats exact effect")
	turn(gs, 0)
	turn(gs, 1)
	check(p.hand.size() == 4 and not Insight.active(gs, 0), "repeat expires after one own turn")

	gs = game()
	p = gs.player(0)
	var enemy: Dictionary = gs.player(1).units[0]
	enemy.hp = 8
	put(gs, "c62001")
	var idx := give(gs, "c62006")
	check(not gs.can_play_card(0, idx, "avatar-1").ok, "lament may not hit enemy avatar")
	check(gs.play_card(0, idx, enemy.uid) and enemy.hp == 4, "enemy damage counts actual zone size")
	p.avatarHp = 20
	play(gs, "c62006", "avatar-0")
	check(p.avatarHp == 24, "ally heal counts actual zone size")
	var shan: String = Content.cards_for_unit("shantong")[0].id
	var fox: String = Content.cards_for_unit("yaohu")[0].id
	put(gs, shan)
	put(gs, fox)
	for i in [1, 2, 3]: gs._knockout_unit(p.units[i])
	play(gs, "c62007")
	check(p.units[1].hp > 0 and p.units[2].hp > 0 and p.units[3].hp == 0 and Insight.active(gs, 0), "revives all and only owners of zone cards")

func ai_and_assets() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c620%02d" % n
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI actually plays " + id)
		var texture := load("res://assets/official/cards/%s.png" % id)
		check(texture is Texture2D and texture.get_width() > 200, "original art loads " + id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(RAIN_TEAM, FOE, 620)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c62006", "c62003"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0 and gs.valid_targets(0, gs.hand_card_def(0, 0)).has("avatar-0"), "native mixed-target card enters aiming mode")
		gs.player(0).avatarHp = 20
		await click(b._ally_target_btn)
		await settled(b)
		check(gs.player(0).avatarHp == 23 and b._hand_row.get_child_count() == 1, "native avatar click uses actual zone-size heal")
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(Insight.active(gs, 0) and gs.front_unit(0).get("id") == "rain-tear", "native form places summon and opens insight")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	passive_and_keeps()
	other_effects()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("RAIN checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
