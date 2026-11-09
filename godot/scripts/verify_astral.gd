extends "res://scripts/verify_insight.gd"

const Astral := preload("res://scripts/astral_rules.gd")
const STAR_TEAM := ["huang-qiming", "shantong", "yaohu", "bailang"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ASTRAL_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(STAR_TEAM, FOE, 617)
	prepare(gs)
	return gs

func combat_insight() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var src: Dictionary = p.units[0]
	var target: Dictionary = foe.units[0]
	check(src.attack == 2 and src.hp == 6, "printed basic body")
	target.front = 1
	target.hp = 20
	target.shield = 3
	target.attack = 0
	check(gs.basic_attack(0, 0) and not Insight.active(gs, 0), "fully absorbed damage does not trigger")
	p.attackUsed = false
	target.shield = 0
	var other := put(gs, Content.cards_for_unit("shantong")[0].id)
	check(gs.basic_attack(0, 0) and p.insightOnlyUnit == Astral.ID, "first actual combat damage restricts to own and neutral")
	check(not gs.can_play_card(0, Insight.zone(gs, 0).find(other)).ok, "cannot play another unit's card in restricted insight")
	check(Insight.leave_action(gs, 0), "restricted insight may be ended")
	p.attackUsed = false
	check(gs.basic_attack(0, 0) and not Insight.active(gs, 0), "subsequent damage on same turn cannot repeat basic trigger")

	gs = game()
	foe = gs.player(1)
	gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
	check(gs.basic_attack(0, 0) and int(foe.avatarHp) < 30 and not Insight.active(gs, 0), "paper form deals real combat damage without restoring suppressed Insight")

	gs = game()
	p = gs.player(0)
	var flow := give(gs, "c61703")
	var original: Dictionary = p.hand[flow]
	check(gs.play_card(0, flow) and Insight.zone(gs, 0).has(original), "normal Star Flow moves same instance into insight zone")
	check(Insight.leave_action(gs, 0), "leave combat's first insight")
	play(gs, "c61701")
	var before: int = p.energy
	check(gs.basic_attack(0, 0) and p.energy == before, "Star River grants a usable swift attack")
	check(Astral.bonus(gs, 0, Insight.STAR) == 1, "Star River enhances Star Command")

func burst_and_origins() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	play(gs, "c61704")
	check(p.units[0].awakened and Astral.bonus(gs, 0, Astral.BURST) == 1, "Gift awakens and enhances burst")
	play(gs, "c61702")
	check(Insight.zone(gs, 0).filter(func(inst): return inst.definitionId == Astral.BURST).size() == 3, "awake extra burst and two printed bursts")
	var burst := zone_index(gs, Astral.BURST)
	var before: int = foe.avatarHp
	check(gs.valid_targets(0, gs.hand_card_def(0, burst)).has("avatar-0"), "burst can also target ally")
	check(gs.play_card(0, burst, "avatar-1") and foe.avatarHp == before - 3 and Insight.active(gs, 0), "burst hits selected target without leaving insight")
	check(Insight.leave_action(gs, 0), "end after burst")
	check(gs.basic_attack(0, 0) and str(p.insightOnlyUnit).is_empty(), "awakened combat damage enters unrestricted insight")
	check(Insight.leave_action(gs, 0), "leave awake combat insight")
	play(gs, "c61706")
	check(p.units[0].attack == 5 and p.units[0].maxHp == 6, "Star Traveler real body")
	Insight.enter(gs, 0)
	before = gs.VerifiedRules.HairPower.amount(p.units[0])
	check(gs.play_card(0, zone_index(gs, Astral.BURST), "avatar-1") and gs.VerifiedRules.HairPower.amount(p.units[0]) == before + 1 and p.units[0].shield > 0, "Star Traveler gains resources from actual zone use")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	var form := give(gs, "c61707")
	check(gs.hand_card_def(0, form).originCard.id == "c17807", "guardian exposes original card")
	check(gs.play_card(0, form, null, true), "origin selected in actual play")
	var health: int = foe.avatarHp
	play(gs, "c61701")
	check(p.units[0].get("form", {}).get("cardId") == "c17807" and foe.avatarHp < health, "origin form launches real combat after playing realm")
	Insight.leave_action(gs, 0)
	var soldier := give(gs, "c61706")
	check(gs.play_card(0, soldier, null, true) and p.units[0].get("form", {}).get("cardId") == "c17805" and p.units[0].attack == 6, "realm counts for Star Track origin")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	var placed: Array = []
	for i in 5: placed.append(put(gs, "c61703"))
	play(gs, "c61708")
	check(placed.filter(func(i): return i.definitionId == Astral.BURST).size() == 4 and placed.all(func(i): return Insight.zone(gs, 0).has(i)), "hole transforms four existing non-neutral instances")
	var cost_before: int = p.energy
	gs.kw_usage(0, "instant").used = true
	check(gs.play_card(0, zone_index(gs, Astral.BURST), "avatar-1") and p.energy == cost_before, "hole makes neutral zone cards free even after using instant")

func guard() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var target: Dictionary = foe.units[0]
	target.hp = 30
	target.attack = 20
	play(gs, "c61707")
	var summon := gs._make_unit("ordinary-astral-summon", "shantong")
	summon.summoned = true
	summon.countsAsShikigami = false
	foe.units.append(summon)
	var summoned_hp := int(summon.hp)
	put(gs, Astral.BURST)
	check(gs.play_card(0, zone_index(gs, Astral.BURST), summon.uid) and int(summon.hp) == summoned_hp - 2, "starburst can damage a non-shikigami character")
	check(int(p.units[0].get("astralGuardianTurn", -1)) != gs.turn_counter, "non-shikigami spell target does not consume Guardian")
	put(gs, Astral.BURST)
	put(gs, Astral.BURST)
	var hp: int = p.units[0].hp
	var energy: int = p.energy
	check(gs.play_card(0, zone_index(gs, Astral.BURST), target.uid) and target.hp == 23 and p.units[0].hp == hp, "guard targets same enemy with damage and immune combat")
	check(gs.play_card(0, zone_index(gs, Astral.BURST), target.uid) and target.hp == 21 and p.energy <= energy, "guard combat limited to once per turn")

func ai_and_assets() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c617%02d" % n
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
		b.setup(STAR_TEAM, FOE, 617)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c61702"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var burst := zone_index(gs, Astral.BURST)
		check(Insight.active(gs, 0) and burst >= 0, "native play displays starburst")
		if burst >= 0:
			await click(b._hand_row.get_child(burst))
			await settled(b)
			check(b._pending_target_card == burst and gs.valid_targets(0, gs.hand_card_def(0, burst)).has("avatar-1"), "native burst selects targets")
			var hp: int = gs.player(1).avatarHp
			await click(b._enemy_target_btn)
			await settled(b)
			check(gs.player(1).avatarHp == hp - 2 and Insight.active(gs, 0), "native avatar click resolves damage and keeps insight")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	combat_insight()
	burst_and_origins()
	guard()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("ASTRAL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
