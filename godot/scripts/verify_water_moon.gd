extends "res://scripts/verify_insight.gd"

const Water := preload("res://scripts/water_moon_rules.gd")
const TEAM := ["zhuiyueshen-shuiyue", "shantong", "yaohu", "bailang"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WATER_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(TEAM, FOE, 618)
	prepare(gs)
	return gs

func zones_and_marks() -> void:
	var gs := game()
	var p := gs.player(0)
	var w: Dictionary = p.units[0]
	check(w.attack == 2 and w.hp == 4, "printed basic body")
	give(gs, "c61802")
	give(gs, "c61804")
	give(gs, "c61807")
	give(gs, "c61808")
	var original: Array = p.hand.duplicate()
	var deck_size: int = p.deck.size()
	play(gs, "c61801")
	check(gs.pending_choice.instanceIds.size() == 5, "mulligan shows four real hand instances and finish")
	for i in 3:
		check(gs.resolve_divination_choice(0, original[i].instanceId), "mulligan selects distinct actual instance")
	check(p.hand.size() == 4 and p.deck.size() == deck_size - 3 and p.hand.has(original[3]), "draws three replacements and retains unselected card")
	check(Insight.active(gs, 0) and original.slice(0, 3).all(func(i): return Insight.zone(gs, 0).has(i)), "moved cards keep identities and then enter insight")
	check(w.get("waterLumen", false) and gs.rule_events.filter(func(e): return e.kind == "water-spirit-charm").size() == 1, "lumen attaches once even when multiple cards move")
	p.energy = 0
	var lament := zone_index(gs, "c61804")
	check(gs._kw(gs.hand_card_def(0, lament), "instant") and gs.play_card(0, lament), "lumen grants instant at zero fire")
	check(not w.get("waterLumen", false) and gs.kw_usage(0, "instant").used, "actual card spends lumen and instant allowance")
	check(gs.resolve_divination_choice(0, Water.ALL), "resolve area branch")
	check(Insight.zone(gs, 0).any(func(i): return i.instanceId == original[1].instanceId and i.waterUsed), "first use from zone returns original")
	Insight.enter(gs, 0)
	check(not gs.can_play_card(0, zone_index(gs, "c61804")).ok, "renewed charm cannot bypass spent instant")
	p.energy = 1
	check(not gs._kw(gs.hand_card_def(0, zone_index(gs, "c61804")), "instant"), "lumen does not grant instant with existing fire")
	check(gs.play_card(0, zone_index(gs, "c61804")) and gs.resolve_divination_choice(0, Water.ALL) and zone_index(gs, "c61804") < 0, "second use consumes same instance")

	gs = game()
	p = gs.player(0)
	w = p.units[0]
	put(gs, Water.AWAKEN)
	play(gs, "c61806")
	check(w.attack == 3 and w.hp == 5 and p.hand.any(func(i): return i.definitionId == Water.AWAKEN), "swap moves full previous zone into ordinary hand")
	check(Insight.zone(gs, 0).is_empty(), "previous hand had only the form")
	turn(gs, 0)
	turn(gs, 1)
	check(not w.awakened and zone_index(gs, Water.AWAKEN) >= 0, "turn-start awakening examines zone before swap")
	turn(gs, 0)
	turn(gs, 1)
	check(w.awakened and w.attack == 5 and w.maxHp == 7, "next own turn casts from actual zone without hand play")
	check(p.energy == int(gs.rules.maxEnergy), "automatic awakening spends no fire")
	Insight.leave_action(gs, 0)
	var shan := str(Content.cards_for_unit("shantong")[0].id)
	var placed := put(gs, shan)
	check(p.units[1].waterReturnLight and not w.get("waterLumen", false), "placing ally card attaches溯光 to that ally only")
	Insight.enter(gs, 0)
	var n := Insight.zone(gs, 0).find(placed)
	check(gs._kw(gs.hand_card_def(0, n), "instant") and gs.effective_card_cost(0, gs.hand_card_def(0, n)) == 0, "awakening grants instant with fire still available")

func forms_fill_and_reflect() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var top: Dictionary = p.deck.back()
	play(gs, "c61803")
	check(Insight.zone(gs, 0).has(top) and not Insight.active(gs, 0), "dance moves actual top card below threshold")
	put(gs, "c61801")
	put(gs, "c61801")
	turn(gs, 0)
	turn(gs, 1)
	check(Insight.active(gs, 0) and Insight.zone(gs, 0).size() == 6, "dance enters when existing count is six without drawing")
	Insight.leave_action(gs, 0)
	var deck_size: int = p.deck.size()
	play(gs, "c61805")
	check(Insight.active(gs, 0) and Insight.zone(gs, 0).size() == int(gs.rules.maxHandSize) and p.deck.size() == deck_size - 6, "fill adds precisely missing original deck cards")
	Insight.leave_action(gs, 0)

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	var enemy_forms: Array = Content.cards_for_unit("bingyong").filter(func(c): return c.type == "form")
	var form_id: String = enemy_forms[0].id
	var idx := give(gs, form_id, 1)
	var old: Dictionary = foe.hand[idx]
	var projected := gs.describe_card_instance(1, old)
	foe.hand.erase(old)
	gs._apply_form(1, 0, projected)
	var reflect_idx := give(gs, "c61802")
	check(not gs.can_play_card(0, reflect_idx, foe.units[1].uid).ok, "reflect rejects unformed enemy")
	check(not gs.can_play_card(0, reflect_idx, p.units[0].uid).ok, "reflect rejects allies")
	check(gs.play_card(0, reflect_idx, foe.units[0].uid) and foe.units[0].form.is_empty() and Insight.zone(gs, 1).has(old), "reflect moves enemy form instance into their zone")
	check(zone_index(gs, "c61802") >= 0 and not Insight.active(gs, 1), "first reflect also enters own zone without starting opponent insight")
	var sea := Content.card_def("c17801").duplicate(true)
	var realm_inst := {"definitionId": sea.id, "instanceId": "reflect-realm"}
	sea.playedInstance = realm_inst
	sea.realm.returnOnDestroy = true
	sea.realm.returnInstance = realm_inst
	gs._deploy_realm(1, sea)
	Insight.enter(gs, 0)
	check(gs.play_card(0, zone_index(gs, "c61802"), foe.realms[0].uid) and foe.realms.is_empty(), "reflect accepts actual enemy realm")
	check(Insight.zone(gs, 1).has(realm_inst) and not foe.hand.has(realm_inst) and zone_index(gs, "c61802") < 0, "moved realm is not destroyed or duplicated by its return ability")

func options_and_divination() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var enemy: Dictionary = foe.units[0]
	enemy.hp = 9
	play(gs, "c61804")
	check(gs.resolve_divination_choice(0, Water.SINGLE), "select single-target mode")
	check(gs.pending_choice.instanceIds.has(p.units[1].uid) and not gs.pending_choice.instanceIds.has("avatar-1"), "single mode allows allied shikigami but no players")
	check(gs.resolve_divination_choice(0, enemy.uid) and enemy.hp == 4 and zone_index(gs, "c61804") >= 0, "single mode deals five then returns first use")

	gs = game()
	p = gs.player(0)
	var original: Dictionary = p.deck.back()
	var n := give(gs, "c61808")
	var cast: Dictionary = p.hand[n]
	check(gs.play_card(0, n) and gs.pending_choice.type == "native-divination", "normal 引月 performs real divination")
	check(gs.resolve_divination_choice(0, original.instanceId) and gs.resolve_divination_choice(0, "divination-place-top"), "actual top choice")
	check(p.hand.has(original) and Insight.zone(gs, 0).any(func(i): return i.instanceId == cast.instanceId), "draw retrieves selected card and first 引月 moves itself")
	Insight.enter(gs, 0)
	p.energy = 2
	var next: Dictionary = p.deck.back()
	check(gs.play_card(0, zone_index(gs, "c61808")) and gs.resolve_divination_choice(0, next.instanceId) and gs.resolve_divination_choice(0, "divination-place-top"), "second use still divines and draws")
	check(p.energy == 2 and p.hand.has(next) and zone_index(gs, "c61808") < 0 and not Insight.active(gs, 0), "zone use earns one real fire and does not return twice")

func capacity_and_neutral_cards() -> void:
	var gs := GS.create(["zhuiyueshen-shuiyue", "tianzhao", "fansi", "haifangzhu"], FOE, 618)
	prepare(gs)
	var p := gs.player(0)
	play(gs, "c61805")
	check(Insight.zone(gs, 0).size() == Insight.CAPACITY, "fill hits shared twelve-card limit")
	var extra := Insight.instance(gs, 0, "c61808")
	check(not Insight.place(gs, 0, extra) and not Insight.zone(gs, 0).has(extra), "overflow burns only incoming instance")
	var deck_top: Dictionary = p.deck.back()
	Solar.draw(gs, 0, 1)
	check(not p.deck.has(deck_top) and not Insight.zone(gs, 0).has(deck_top) and not deck_top.has("sunlight"), "burned draw does not get a sunlight attachment")
	Insight.leave_action(gs, 0)
	for inst in Insight.zone(gs, 0).duplicate(): Insight.remove(gs, 0, inst)
	p.hand.clear()

	var food: Dictionary = gs.VerifiedRules.Cooking.gain_ingredient(gs, 0, 2, "mountain")
	var ally: Dictionary = p.units[1]
	var power: int = ally.attack
	p.hand.erase(food)
	Insight.place(gs, 0, food)
	Insight.enter(gs, 0, "huang-qiming")
	check(gs.play_card(0, 0, ally.uid) and ally.attack > power and not Insight.active(gs, 0), "neutral food plays from restricted zone and ends it")
	check(gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("instanceId") == food.instanceId and e.a.get("sourceZone") == "insight"), "neutral food records the real zone")

	gs.VerifiedRules.EssenceFeast.gain_essence(gs, 0, 2)
	var essence: Dictionary = p.hand.pop_back()
	Insight.place(gs, 0, essence)
	Insight.enter(gs, 0, "huang-qiming")
	p.avatarHp = 25
	check(gs.play_card(0, 0, "avatar-0") and p.avatarHp == 27 and not Insight.active(gs, 0), "neutral essence uses actual stacks and closes the zone")
	check(gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("instanceId") == essence.instanceId and e.a.get("sourceZone") == "insight"), "neutral essence records the real zone")

	gs = game()
	p = gs.player(0)
	play(gs, "c61806")
	check(gs.play_card(0, 0, "avatar-1") and gs.player(1).avatarHp == 28 and zone_index(gs, Insight.STAR) >= 0, "star moved to hand keeps its effect and returns to insight")
	var u: Dictionary = p.units[0]
	put(gs, "c61801")
	check(u.get("waterLumen", false), "lumen attaches before knockout")
	gs._knockout_unit(u)
	check(not u.get("waterLumen", false), "lumen disappears on actual knockout")

func ai_and_assets() -> void:
	for n in range(1, 9):
		var gs := game()
		var id := "c618%02d" % n
		if n == 2: gs._deploy_realm(1, Content.card_def("c17801"))
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI legally uses " + id)
		var steps := 0
		while not gs.pending_choice.is_empty() and steps < 10:
			steps += 1
			if not AI.take_action(gs, 0): break
		check(gs.pending_choice.is_empty(), "AI completes actual choices for " + id)
		var face := load("res://assets/official/cards/%s.png" % id)
		check(face is Texture2D and face.get_width() > 200, "original art " + id)

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(TEAM, FOE, 618)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c61801", "c61804", "c61803"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var selected := choice_face(b, "c61804")
		check(selected != null, "native mulligan displays actual hand card")
		if selected != null: await click(selected)
		await settled(b)
		var finish := choice_face(b, Water.FINISH)
		check(finish != null, "native optional finish is visible")
		if finish != null: await click(finish)
		await settled(b)
		check(Insight.active(gs, 0) and zone_index(gs, "c61804") >= 0, "native selection moves card into zone")
		if zone_index(gs, "c61804") >= 0:
			await click(b._hand_row.get_child(zone_index(gs, "c61804")))
			await settled(b)
			var mode := choice_face(b, Water.SINGLE)
			check(mode != null, "native single-target mode visible")
			if mode != null: await click(mode)
			await settled(b)
			var target: Dictionary = gs.player(1).units[0]
			var hp: int = target.hp
			var option := choice_face(b, target.uid)
			check(option != null, "native specific target visible")
			if option != null: await click(option)
			await settled(b)
			check(target.hp == maxi(0, hp-5) and not Insight.active(gs, 0), "native mode and target apply actual damage")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	zones_and_marks()
	forms_fill_and_reflect()
	options_and_divination()
	capacity_and_neutral_cards()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("WATER checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
