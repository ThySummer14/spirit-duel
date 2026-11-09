extends "res://scripts/verify_langyazi.gd"

const Insight := preload("res://scripts/insight_rules.gd")
const Solar := preload("res://scripts/solar_rules.gd")
const SUN_TEAM := ["tianzhao", "shantong", "yaohu", "bailang"]
const FOE := ["bingyong", "xuenv", "hetong", "yaodaoji"]

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("INSIGHT_FAIL ", detail)

func game() -> GS:
	var gs := GS.create(SUN_TEAM, FOE, 623)
	prepare(gs)
	var p := gs.player(0)
	p.insightZone = p.insightZone.filter(func(inst): return Content.card_def(inst.definitionId).get("insightNeutral", false))
	return gs

func put(gs, id: String, light: int = 0) -> Dictionary:
	var inst := Insight.instance(gs, 0, id)
	if light > 0: inst.sunlight = light
	Insight.place(gs, 0, inst)
	return inst

func zone_index(gs, id: String) -> int:
	return Insight.zone(gs, 0).find_custom(func(inst): return inst.definitionId == id)

func core_zone() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var hidden := give(gs, "c62304")
	var hidden_iid: String = p.hand[hidden].instanceId
	check(gs.playable_card_count(0) == 1 and Insight.zone(gs, 0).size() == 3, "starter cards are separate from hand before insight")
	Insight.enter(gs, 0)
	var star_index := zone_index(gs, Insight.STAR)
	var star := gs.card_instance(0, star_index)
	check(gs.playable_card_count(0) == 3 and gs.hand_card_def(0, star_index).sourceZone == "insight", "active view lists only insight zone")
	check(gs.play_card(0, star_index, "avatar-1") and foe.avatarHp == 28 and p.energy == 40, "neutral star hits selected character for free")
	check(not Insight.active(gs, 0) and p.hand[0].instanceId == hidden_iid and Insight.zone(gs, 0).has(star), "playing returns star instance and restores original hand")
	check(gs.command_log.back().a.sourceZone == "insight", "replay command records actual zone")

	gs._deploy_realm(1, Content.card_def("c60808"))
	Insight.enter(gs, 0)
	var moon := zone_index(gs, Insight.MOON)
	var realm_id: String = foe.realms[0].uid
	for u in p.units: u.level = 0
	check(not gs.can_play_card(0, moon, realm_id).ok, "moon requires a living level-one ally")
	p.units[1].level = 1
	check(gs.play_card(0, moon, realm_id) and foe.realms.is_empty() and zone_index(gs, Insight.MOON) < 0, "moon destroys the selected realm and is consumed")

	Insight.enter(gs, 0)
	var sun := zone_index(gs, Insight.SUN)
	var target: Dictionary = foe.units[2]
	check(not gs.can_play_card(0, sun, target.uid).ok, "sun requires a living level-two ally")
	p.units[1].level = 2
	var before: int = foe.hand.size()
	check(gs.play_card(0, sun, target.uid) and target.hp == 0 and foe.hand.size() == before + 1, "sun actually destroys and lets enemy draw")
	Insight.enter(gs, 0)
	check(not Insight.leave_action(gs, 1) and Insight.leave_action(gs, 0), "own manual end of insight is legal")
	Insight.enter(gs, 0)
	turn(gs, 0)
	check(not Insight.active(gs, 0), "turn end restores hand")

func sun_effects() -> void:
	var gs := game()
	var p := gs.player(0)
	var foe := gs.player(1)
	var normal_size: int = p.hand.size()
	var first: Dictionary = p.deck.back()
	play(gs, "c62301")
	check(Insight.active(gs, 0) and Insight.zone(gs, 0).size() == 5 and p.hand.size() == normal_size, "光涤 moves exactly two original deck cards into separate zone")
	check(Insight.zone(gs, 0).has(first) and first.sunlight == 1, "original drawn instance carries sunlight")
	var total: int = foe.units.reduce(func(sum, u): return sum + int(u.hp), 0)
	check(Insight.leave_action(gs, 0), "manual exit resolves sunlight")
	check(p.deck.has(first) and Insight.zone(gs, 0).size() == 3 and foe.units.reduce(func(sum, u): return sum + int(u.hp), 0) == total - 2, "marked cards return to deck and deal individual damage, neutral cards stay")

	gs = game()
	p = gs.player(0)
	var u: Dictionary = p.units[0]
	play(gs, "c62302")
	check(u.attack == 3 and u.maxHp == 4 and Insight.zone(gs, 0).size() == 4, "solar goddess installs exact form and places one card")
	put(gs, "c62304", 1)
	turn(gs, 0)
	turn(gs, 1)
	check(Insight.active(gs, 0) and Insight.zone(gs, 0).size() == 7, "next turn resolves base and form draws, enters at three marked")
	check(p.hand.size() == 1, "normal turn draw still goes to hand while in insight")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	u = p.units[0]
	play(gs, "c62305")
	check(gs.pending_choice.instanceIds == ["solar-damage", "solar-awaken"], "awakening offers actual independent choices")
	check(gs.resolve_divination_choice(0, "solar-damage") and not u.awakened and u.attack == 2 and p.solarLightBonus == 1, "damage mode only grants persistent bonus")
	play(gs, "c62305")
	check(gs.pending_choice.instanceIds == ["solar-awaken"] and gs.resolve_divination_choice(0, "solar-awaken"), "only remaining awakening mode is available")
	check(u.awakened and u.attack == 3 and u.maxHp == 5, "awakening gives printed +1/+1")
	var marked := put(gs, "c62304", 1)
	Solar.attach(gs, 0, marked)
	Insight.enter(gs, 0)
	var id := zone_index(gs, "c62304")
	check(gs.hand_card_def(0, id).sunlight == 2 and "instant" in gs.hand_card_def(0, id).keywords, "re-attachment stacks on the same card and awakening grants instant")
	total = foe.units.reduce(func(sum, x): return sum + int(x.hp), 0)
	check(Insight.leave_action(gs, 0) and foe.units.reduce(func(sum, x): return sum + int(x.hp), 0) == total - 3, "two attachments plus permanent enhancement deal three")
	check(p.deck.has(marked), "stacked card returns to deck as original instance")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	foe.units[0].front = 1
	foe.units[0].hp = 12
	foe.units[0].maxHp = 12
	play(gs, "c62306")
	check(Insight.leave_action(gs, 0) and foe.units[0].hp == 8, "神圣裁决 projects two doubled packets at battle zone")
	foe.units[0].front = 0
	var projectile := put(gs, "c62304", 1)
	Insight.enter(gs, 0)
	check(Insight.leave_action(gs, 0) and foe.avatarHp == 29 and p.deck.has(projectile), "without front the projectile hits player for undoubled amount")

	gs = game()
	p = gs.player(0)
	foe = gs.player(1)
	play(gs, "c62303")
	var usable := put(gs, "c62304", 1)
	var return_card := put(gs, "c62308", 1)
	foe.units[0].hp = 10
	check(gs.play_card(0, zone_index(gs, "c62304"), foe.units[0].uid), "actual marked dedicated card is playable from insight")
	check(Insight.active(gs, 0) and p.deck.has(return_card) and not p.deck.has(usable) and Insight.zone(gs, 0).size() == 4, "刑神场 starts new insight after prior area sends unused light back")

	gs = game()
	p = gs.player(0)
	var dead: Dictionary = p.units[1]
	gs._knockout_unit(dead)
	p.deck.append({"instanceId": "palace-original", "definitionId": Content.cards_for_unit(dead.id)[0].id})
	play(gs, "c62308")
	check(dead.hp == dead.maxHp and p.realms[0].hp == 5, "高天原 revives the owner of attached card")
	var next := put(gs, "c62304")
	Solar.attach(gs, 0, next)
	check(p.units[0].shield == 2 and gs.VerifiedRules.HairPower.amount(p.units[0]) == 2, "living owner gains battle power and armor")

func ai_and_assets() -> void:
	var scope := game()
	var foe := scope.player(1)
	foe.units[0].level = 0
	foe.units[0].hp = 10
	foe.units[1].summoned = true
	foe.units[2].movementVeil = true
	var strike := give(scope, "c62304")
	check(not scope.can_play_card(0, strike, foe.units[1].uid).ok and not scope.can_play_card(0, strike, foe.units[2].uid).ok, "天照单体法术排除普通召唤物和帷幕")
	check(scope.play_card(0, strike, foe.units[0].uid) and foe.units[0].hp == 5, "天照单体法术可指定并命中零勾存活式神")
	for n in range(1, 9):
		var gs := game()
		var id := "c623%02d" % n
		give(gs, id)
		check(AI.take_action(gs, 0) and gs.command_log.any(func(e): return e.c == "play_card" and e.a.get("card", "") == id), "AI actually plays " + id)
		var texture := load("res://assets/official/cards/%s.png" % id)
		check(texture is Texture2D and texture.get_width() > 200, "original art loads " + id)
	var gs := game()
	Insight.enter(gs, 0)
	check(AI.take_action(gs, 0) and not Insight.active(gs, 0) and gs.command_log.back().a.card == Insight.SUN, "AI chooses a legal neutral card and target")

func find_button(n: Node, title: String) -> Button:
	if n is Button and n.text == title: return n
	for child in n.get_children():
		var found := find_button(child, title)
		if found != null: return found
	return null

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(SUN_TEAM, FOE, 623)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		hand(b, ["c62301", "c62305"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(Insight.active(gs, 0) and b._hand_row.get_child_count() >= 5 and gs.player(0).hand.size() == 1, "native card row switches to separate zone")
		var stop := find_button(b, "结束启悟")
		check(stop != null, "native end insight button visible")
		await click(stop)
		await settled(b)
		check(not Insight.active(gs, 0) and b._hand_row.get_child_count() == 1, "native manual exit restores hand")
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(choice_face(b, "solar-awaken") != null, "native awakening choice shown")
		await click(choice_face(b, "solar-awaken"))
		await settled(b)
		check(gs.player(0).units[0].awakened, "native awakening choice applies body and passive")
		var target: Dictionary = gs.player(1).units[1]
		target.level = 0
		target.hp = 10
		hand(b, ["c62304"])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(b._pending_target_card == 0, "native Solar spell opens unit selection")
		await click(b._unit_widget(target.uid))
		await settled(b)
		check(target.hp == 5, "native Solar spell hits the selected level-zero shikigami")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	core_zone()
	sun_effects()
	ai_and_assets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("INSIGHT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
