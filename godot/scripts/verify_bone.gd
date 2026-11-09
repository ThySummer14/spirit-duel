extends "res://scripts/verify_insight.gd"

const Bone := preload("res://scripts/bone_rules.gd")
const TEAM := ["gunv", "shantong", "yaohu", "bailang"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BONE_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(TEAM, FOE, 619)
	prepare(gs)
	return gs

func summoning_and_revive() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = p.units[0]
	check(u.attack == 2 and u.hp == 5, "base body")
	play(gs, "c61902")
	check(p.realms[0].hp == 4 and gs.VerifiedRules.HairPower.guard_count(gs, 0) == 1, "bird enters with a real guard")
	u.front = 1
	gs._knockout_unit(u, 1, 0)
	gs._resolve_resolution_stack()
	var remains := gs.front_unit(0)
	check(remains.get("id") == Bone.REMAINS and remains.attack == 2 and remains.hp == 4, "one original 1/2 fused with the bird's 1/2")
	check(p.units.size() == 5 and p.realms[0].hp == 4, "fusion keeps one body and original realm keeps durability")
	play(gs, "c61905")
	check(u.awakened and u.hp == 0 and u.attack == 3 and u.maxHp == 6, "awakening works while knocked out with printed +1/+1")
	check(remains.attack == 3 and remains.hp == 6, "awakening adds a real third remains")
	var other: Dictionary = p.units[1]
	gs._knockout_unit(other, 1, 0, 3)
	gs._resolve_resolution_stack()
	check(other.knockout == 2 and remains.attack == 3, "awake countdown applies while bone is dead but reserve ally cannot summon")
	play(gs, "c61906")
	check(u.hp == 7 and u.attack == 7 and u.form.cardId == "c61906", "shed enters and revives with the new body plus awakening")
	gs._knockout_unit(u, 1, 0)
	gs._resolve_resolution_stack()
	check(u.hp == 6 and u.form.is_empty() and remains.attack == 4, "shed revives after actual death and base summons again")
	gs._knockout_unit(u, 1, 0)
	gs._resolve_resolution_stack()
	check(u.hp == 0 and remains.attack == 5, "discarded form cannot revive again")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c61903", foe.units[0].uid)
	remains = gs.front_unit(0)
	check(remains.get("id") == Bone.REMAINS and remains.attack == 1 and remains.hp == 2 and foe.units[0].frozen > 0, "borrow skin stuns and summons original stats")
	check(gs.basic_attack(0, 1) and remains.get("removed", false), "leave combat zone removes remains")

func combat_and_targets() -> void:
	for id in ["c61901", "c61907"]:
		var gs := game()
		var p := gs.player(0)
		var foe := gs.player(1)
		var target: Dictionary = foe.units[2]
		target.attack = 15
		target.hp = 20
		target.shield = 20
		foe.units[0].front = 1
		var idx := give(gs, id)
		check(not gs.can_play_card(0, idx, "avatar-1").ok, "pursuit only targets shikigami")
		check(gs.play_card(0, idx, target.uid) and p.units[0].hp == 0 and gs.front_unit(0).get("id") == Bone.REMAINS, "real combat against chosen reserve target causes own knockout")
		if id == "c61901":
			check(target.hp == 0 and foe.units[0].hp > 0, "怨生 destroys chosen fighter through armor")
		else:
			check(target.hp == 20 and target.frozen > 0 and foe.avatarFrozen > 0 and foe.units[0].frozen == 0, "一步一息 stuns opponent and player")
		gs = game()
		target = gs.player(1).units[2]
		target.attack = 0
		target.hp = 20
		play(gs, id, target.uid)
		check(target.hp > 0 and target.frozen == 0 and gs.player(1).get("avatarFrozen", 0) == 0, "surviving attacker produces no death effect")
		gs = game()
		target = gs.player(1).units[2]
		target.summoned = true
		target.attack = 15
		target.hp = 20
		target.shield = 20
		play(gs, id, target.uid)
		check(gs.player(0).units[0].hp == 0 and target.hp == 20 and target.frozen == 0, "death effect against a shikigami skips an ordinary summon")
		check((gs.player(1).get("avatarFrozen", 0) > 0) == (id == "c61907"), "一步一息 still stuns the player independently")

	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	p.units[0].level = 2
	foe.units[1].level = 2
	var blade := give(gs, "c61904")
	check(not gs.can_play_card(0, blade, foe.units[0].uid).ok, "blade forbids higher level")
	check(not gs.can_play_card(0, blade, p.units[1].uid).ok, "blade forbids selecting an ally")
	check(gs.play_card(0, blade, foe.units[1].uid) and p.units[0].hp == 0 and foe.units[1].hp == 0 and gs.front_unit(0).get("id") == Bone.REMAINS, "blade destroys both including own reserve bone")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c61908")
	var remains := gs.front_unit(0)
	check(remains.get("swift", false) and p.realms[0].hp == 6, "dream summons with actual swift")
	gs._knockout_unit(remains, 1, 0)
	gs._resolve_resolution_stack()
	check(foe.units[0].hp > 0 and remains.removed, "dream does not retaliate for a summon")
	gs._knockout_unit(p.units[1], 1, 0)
	gs._resolve_resolution_stack()
	check(foe.units[0].hp == 0, "dream actually destroys the enemy killer")

func ai_and_assets() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c619%02d" % n
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI legally uses " + id)
		var face := load("res://assets/official/cards/%s.png" % id)
		check(face is Texture2D and face.get_width() > 200, "original card image " + id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(TEAM, FOE, 619)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		gs.player(0).units[0].level = 2
		gs.player(1).units[0].level = 2
		hand(b, ["c61904", "c61906"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0 and gs.valid_targets(0, gs.hand_card_def(0, 0)).size() == 1, "native blade selects only correct level")
		var target := b._unit_widget(gs.player(1).units[0].uid)
		check(target != null, "native target is displayed")
		if target != null: await click(target)
		await settled(b)
		check(gs.player(0).units[0].hp == 0 and gs.front_unit(0).get("id") == Bone.REMAINS, "native target starts real summoning")
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.player(0).units[0].hp == 6, "native knockout form revives")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	summoning_and_revive()
	combat_and_targets()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("BONE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
