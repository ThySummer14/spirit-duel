extends "res://scripts/verify_langyazi.gd"

const Treasure := preload("res://scripts/treasure_rules.gd")
const ROBBER := ["daorenshen", "shantong", "yaohu", "bailang"]
const RIVALS := ["bingyong", "xuenv", "hetong", "yaodaoji"]

func game() -> GS:
	var gs := GS.create(ROBBER, RIVALS, 626)
	prepare(gs)
	return gs

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("TREASURE_FAIL ", detail)

func choose(gs, id: String) -> void:
	check(gs.resolve_divination_choice(0, id), "choose " + id)

func options_and_payment() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	play(gs, Treasure.SMALL)
	check(gs.pending_choice.instanceIds == ["draw", "discount", "damage"] and p.energy == 40, "first treasure is instant and offers real three-way choice")
	check(not gs.resolve_divination_choice(1, "discount"), "opponent cannot choose on player's behalf")
	choose(gs, "discount")
	var costly := give(gs, "c62604")
	check(gs.card_payment(0, gs.hand_card_def(0, costly)).cost == 1, "one-level discount excludes two-level cards")
	var selected: Dictionary = foe.units[0]
	selected.hp = 4
	var low := give(gs, "c62602")
	check(gs.card_payment(0, gs.hand_card_def(0, low)).cost == 0, "one-level discount applies to a real low-level card")
	check(gs.play_card(0, low, selected.uid) and p.energy == 40 and p.treasureFreeLevelOne == 0, "successful use spends discount")
	check(selected.hp == 1, "claw deals exactly three damage")

	gs = game()
	p = gs.player(0)
	play(gs, Treasure.LARGE)
	choose(gs, "discount")
	costly = give(gs, "c62604")
	check(gs.play_card(0, costly) and p.energy == 40 and p.treasureFreeAny == 0, "great treasure discount pays for a level two card")
	gs = game()
	p = gs.player(0)
	play(gs, Treasure.SMALL)
	choose(gs, "discount")
	turn(gs, 0)
	turn(gs, 1)
	check(gs.card_payment(0, Content.card_def("c62601")).cost == 1, "unused discount expires after turn change")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	foe.units[1].keywords = ["veil"]
	play(gs, Treasure.LARGE)
	choose(gs, "damage")
	check(not gs.pending_choice.instanceIds.has(foe.units[1].uid) and not gs.resolve_divination_choice(0, p.units[1].uid), "treasure damage offers only legal enemy targets")
	choose(gs, "avatar-1")
	check(foe.avatarHp == 26 and p.hand.is_empty(), "great treasure deals four, no unselected draw or discount")

	gs = game()
	foe = gs.player(1)
	var summon := gs._make_unit("ordinary-treasure-summon", "shantong")
	summon.summoned = true
	summon.countsAsShikigami = false
	foe.units.append(summon)
	var hp := int(summon.hp)
	var claw := give(gs, "c62602")
	check(not gs.can_play_card(0, claw, summon.uid).ok, "claw is restricted to enemy shikigami")
	play(gs, Treasure.SMALL)
	choose(gs, "damage")
	check(summon.uid in gs.pending_choice.instanceIds, "treasure offers enemy non-shikigami character")
	summon.movementVeil = true
	check(not gs.resolve_divination_choice(0, summon.uid), "stale target is rejected if it acquires veil")
	summon.movementVeil = false
	choose(gs, summon.uid)
	check(int(summon.hp) == hp - 1 and int(foe.avatarHp) == 30, "real treasure target damages only the chosen summon")

func triggers_and_combat() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var unit: Dictionary = p.units[0]
	check(gs.basic_attack(0, 0) and foe.avatarHp == 27 and p.hand.size() == 1 and p.hand[0].definitionId == Treasure.SMALL, "actual avatar combat damage generates a treasure")
	gs._damage_avatar(1, 1, 0, 0, false, true)
	check(p.hand.size() == 1, "second combat damage in the same turn generates nothing")
	play(gs, "c62607")
	check(unit.awakened and unit.attack == 3 and unit.shield == 2 and foe.avatarHp == 23, "awakening is a direct strike with printed +2 armor")
	turn(gs, 0)
	turn(gs, 1)
	check(gs.basic_attack(0, 0) and p.hand.any(func(c): return c.definitionId == Treasure.LARGE), "awakened damage grants great treasure")
	gs = game()
	foe = gs.player(1)
	foe.avatarArmor = 8
	gs._damage_avatar(1, 1, 0, 0, false, true)
	gs._damage_avatar(1, 1, 0, 0)
	check(gs.player(0).hand.is_empty(), "fully absorbed combat and spell damage do not generate treasure")

	gs = game()
	foe = gs.player(1)
	gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
	check(gs.basic_attack(0, 0) and int(foe.avatarHp) < 30 and gs.player(0).hand.is_empty(), "paper form cannot activate treasure generation on real combat damage")

	gs = game()
	p = gs.player(0)
	unit = p.units[0]
	play(gs, "c62603")
	check(unit.attack == 3 and unit.hp == 4 and p.hand[0].definitionId == Treasure.SMALL, "day form entry creates actual treasure")
	for count in 4:
		unit.battlePower = 0
		var idx: int = p.hand.find_custom(func(inst): return inst.definitionId == Treasure.SMALL)
		if idx < 0: idx = give(gs, Treasure.SMALL)
		check(gs.play_card(0, idx), "spend real treasure in day form")
		choose(gs, "discount")
		check(gs.VerifiedRules.HairPower.amount(unit) == mini(3, count + 1), "day form uses real lifetime count capped at three")
	check(gs.hand_card_def(0, give(gs, "c62601")).combatOption.lethal, "treasure use unlocks attack lethal")
	check(gs.hand_card_def(0, give(gs, "c62605")).combatOption.immuneCombat, "treasure use unlocks pursuit combat immunity")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c62606")
	var discard := give(gs, "c62606")
	var iid: String = p.hand[discard].instanceId
	play(gs, Treasure.SMALL)
	check(gs.pending_choice.type == "treasure-discard", "night form executes draw without a mode prompt")
	choose(gs, iid)
	check(p.treasureFreeLevelOne == 1 and p.hand.any(func(c): return c.definitionId == Treasure.SMALL), "real discard triggers treasure and continues to discount")
	check(gs.pending_choice.type == "treasure-target", "night form still requests damage target")
	choose(gs, "avatar-1")
	check(foe.avatarHp == 29 and p.units[0].swift, "night form settles all three effects and retains swift")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	p.deck = [{"definitionId":"c62601", "instanceId":"vault-a"}, {"definitionId":"c62602", "instanceId":"vault-b"}, {"definitionId":"c62608", "instanceId":"vault-top"}]
	play(gs, "c62604")
	check(p.hand.size() == 2 and p.hand[0].instanceId in ["vault-a", "vault-b"] and p.deck.back().instanceId == "vault-top", "vault draws a real matching deck instance without touching top")
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "专项")
	gs._resolve_resolution_stack()
	check(p.deck.size() == 1 and p.hand.size() == 4, "vault departure draws another matching instance and generates treasure")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	p.units[0].level = 2
	play(gs, "c62608")
	check(gs.pending_choice.type == "treasure-mode" and p.treasureUseTurn == gs.turn_counter, "tail trick is played as actual treasure")
	choose(gs, "discount")
	check(p.treasureFreeLevelOne == 1 and gs.front_index(0) < 0, "tail trick does not perform full attacks")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	for i in range(1, 4): gs._knockout_unit(foe.units[i])
	foe.units[0].maxHp = 40
	foe.units[0].hp = 40
	foe.units[0].attack = 20
	foe.units[0].factionPermanent = "紫岩"
	play(gs, "c62608")
	check(foe.units[0].hp == 22 and p.units[0].hp == 4, "tail resolves exactly three attacks, critical only on 紫岩 and immune to counters")

func ai_and_assets() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c626%02d" % n
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI uses " + id)
		var texture := load("res://assets/official/cards/%s.png" % id)
		check(texture is Texture2D and texture.get_width() > 200, "original art loads " + id)
	var gs := game()
	give(gs, Treasure.LARGE)
	gs.player(1).avatarHp = 4
	check(AI.take_action(gs, 0) and AI.take_action(gs, 0) and AI.take_action(gs, 0) and gs.winner == 0, "AI makes legal lethal treasure choice and target")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(ROBBER, RIVALS, 626)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		var summon := gs._make_unit("ui-treasure-summon", "shantong")
		summon.summoned = true
		summon.countsAsShikigami = false
		gs.player(1).units.append(summon)
		var hp := int(summon.hp)
		hand(b, [Treasure.SMALL])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._choice_layer != null and faces(b._choice_layer).size() == 3, "native treasure presents all three modes")
		await click(choice_face(b, "damage"))
		await settled(b)
		check(choice_face(b, "avatar-1") != null and choice_face(b, summon.uid) != null, "native damage mode presents both avatar and summon")
		await click(choice_face(b, summon.uid))
		await settled(b)
		check(b._choice_layer == null and int(summon.hp) == hp - 1 and gs.player(1).avatarHp == 30, "native choice hits the selected summon and exits")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	options_and_payment()
	triggers_and_combat()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("TREASURE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
