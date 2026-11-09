extends "res://scripts/verify_insight.gd"

const Luo := preload("res://scripts/luohou_rules.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")
const TEAM := ["luohou", "bailang", "hetong", "shantong"]
const FOES := ["yaohu", "xuenv", "bingyong", "yaodaoji"]
const OMEN := "w13-luohou-93141"
const HIT := "w13-luohou-93142"
const AUGURY := "w13-luohou-93143"
const FORM := "w13-luohou-93144"
const TRANSIT := "w13-luohou-93145"
const REALM := "w13-luohou-93146"
const DISCARD := "w13-luohou-93147"
const AWAKEN := "w13-luohou-93148"
const STAR := Luo.TOKEN

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LUOHOU_FAIL ", detail)

func fixture() -> GS:
	var gs := GS.create(TEAM, FOES, 93141)
	prepare(gs)
	for side in 2:
		var p := gs.player(side)
		p.deck.clear()
		for i in 12: p.deck.append(Insight.instance(gs, side, "c11301"))
		for u in p.units: u.front = 0
	return gs

func auto_choices(gs: GS) -> void:
	for _i in 32:
		if gs.pending_choice.is_empty(): break
		check(AI.take_action(gs, gs.action_player()), "AI chooses legal " + str(gs.pending_choice.get("type", "")))
	check(gs.pending_choice.is_empty(), "choice resolves")

func place_all(gs: GS, stars_first: bool = false) -> void:
	if gs.pending_choice.is_empty(): return
	var c := gs.pending_choice
	var owner := int(c.playerIndex)
	var ids: Array = c.instanceIds.duplicate()
	if stars_first:
		var side := int(c.zoneOwner)
		ids.sort_custom(func(a,b): return Divination.instance(gs, side, a).definitionId == STAR and Divination.instance(gs, side, b).definitionId != STAR)
	for id in ids:
		check(gs.resolve_divination_choice(owner, str(id)), "choose physical deck instance")
		check(gs.resolve_divination_choice(owner, Divination.TOP), "place deck instance at top")

func catalog_and_ai() -> void:
	var gs := fixture()
	var unit: Dictionary = gs.player(0).units[0]
	check(unit.attack == 2 and unit.maxHp == 5 and gs.VerifiedRules.Factions.get_faction(unit) == "紫岩", "body 2/5 purple")
	var omen := Content.card_def(OMEN)
	check(omen.name == "死兆" and omen.nativeCardId == 66808 and omen.type == "spell" and omen.level == 3 and omen.cost == 1, "national client card 66808 retains save ID with confirmed name, type, level and fire")
	for id in [OMEN, HIT, AUGURY, FORM, TRANSIT, REALM, DISCARD, AWAKEN, STAR]:
		var c := Content.card_def(id)
		check(c.get("verifiedRules", false) and ResourceLoader.exists("res://assets/official/cards/" + id + ".png"), id + " verified native and official art")
		gs = fixture()
		var owner := 1 if id == STAR else 0
		if owner == 1: turn(gs, 0)
		if id == DISCARD: give(gs, STAR)
		var index := give(gs, id, owner)
		var best := AI._best_card(gs, owner)
		check(best.ok and best.card_id == id and gs.can_play_card(owner, index, best.target).ok, id + " is legally considered by AI")
		if best.ok: check(gs.play_card(owner, index, best.target), id + " uses normal entry")
		auto_choices(gs)
	gs = fixture()
	var p := gs.player(0)
	p.deck.clear()
	for id in [STAR, "c11301", STAR]: p.deck.append(gs.VerifiedRules.Insight.instance(gs, 0, id))
	var index := give(gs, OMEN)
	check(gs.can_play_card(0, index).ok and not AI._best_card(gs, 0).ok, "三张含凶星的薄牌库仍可手动施放死兆，AI 避免连抽耗尽")

func augury_and_awaken() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var unit: Dictionary = p.units[0]
	play(gs, AUGURY)
	check(Luo.star_indices(p.deck).size() == 3 and gs.pending_choice.instanceIds.size() == 2 and p.hand.is_empty(), "2 washed plus 1 passive before divination, draw waits")
	place_all(gs)
	check(not p.hand.is_empty(), "normal draw resumes")
	Divination.start(gs, 0, 1)
	check(Luo.star_indices(p.deck + p.hand).size() == 3, "base quota once per turn")
	place_all(gs)
	var old: Array = foe.deck.duplicate()
	play(gs, AWAKEN)
	check(unit.awakened and unit.attack == 3 and unit.maxHp == 6, "awakening raises native body")
	check(gs.pending_choice.zoneOwner == 1 and gs.pending_choice.playerIndex == 0 and Luo.star_indices(foe.deck).size() == 2, "controller divines enemy deck after two attached stars")
	check(foe.deck.filter(func(c): return c.definitionId != STAR) == old, "inserted stars do not shuffle existing deck")
	check(not gs.resolve_divination_choice(1, str(gs.pending_choice.instanceIds[0])), "opponent cannot complete controller choice")
	place_all(gs)
	var before := Luo.star_indices(p.deck).size()
	Divination.start(gs, 0, 2)
	check(Luo.star_indices(p.deck).size() == before + 2, "awakening removes quota")
	place_all(gs)

func death_omen() -> void:
	for top_order in [[STAR, "c11301", STAR, "c11301", STAR, "c11301"], [STAR, STAR, "c11301", "c11301", "c11301"], ["c11301", "c11301", "c11301"]]:
		var gs := fixture()
		var p := gs.player(0)
		var foe := gs.player(1)
		var caster: Dictionary = p.units[0]
		var fire: int = p.energy
		var token := gs._make_unit("death-omen-non-shikigami", "yaohu")
		token.summoned = true
		token.countsAsShikigami = false
		foe.units.append(token)
		p.deck.clear()
		p.deck.append(Insight.instance(gs, 0, "c11301"))
		for i in range(top_order.size()-1, -1, -1): p.deck.append(Insight.instance(gs, 0, top_order[i]))
		p.luohouDivinedTurn = gs.turn_counter
		var spell := give(gs, OMEN)
		caster.level = 2
		check(not gs.can_play_card(0, spell).ok, "death omen needs three勾")
		caster.level = 3
		var hps: Array = foe.units.map(func(unit): return int(unit.hp))
		var enemy_hp: int = foe.avatarHp
		check(gs.play_card(0, spell), "death omen uses actual hand entry")
		check(gs.pending_choice.type == "native-divination" and gs.pending_choice.instanceIds.size() == 3 and p.energy == fire-1 and p.hand.is_empty(), "death omen offers actual divination three before drawing")
		place_all(gs)
		var printed_stars := 3 if top_order.size() == 6 else (1 if top_order.size() == 5 else 0)
		var hits := gs.rule_events.filter(func(event): return event.kind == "luohou-death-omen")
		check(hits.size() == printed_stars and p.hand.size() == top_order.size() and p.deck.size() == 1, "death omen marks actual printed draw instances and each star still draws its bonus")
		check(foe.avatarHp == enemy_hp, "death omen does not target the opposing player")
		for i in foe.units.size():
			var loss := 0 if foe.units[i].get("summoned", false) else printed_stars
			check(int(foe.units[i].hp) == hps[i] - loss, "each counted star deals one pulse to enemy shikigami only")
		p.deck.push_back(Insight.instance(gs, 0, STAR))
		gs._draw(0, 1)
		check(gs.rule_events.filter(func(event): return event.kind == "luohou-death-omen").size() == printed_stars, "later unrelated star draw does not repeat death omen")

func discard_and_damage() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	var only := give(gs, DISCARD)
	check(not gs.can_play_card(0, only).ok, "discard needs another hand card")
	give(gs, "c11301", 1)
	var star := give(gs, STAR)
	var iid: String = p.hand[star].instanceId
	var fire: int = p.energy
	check(gs.play_card(0, only) and gs.pending_choice.type == Luo.DISCARD_CHOICE, "real hand choice opens")
	check(not gs.resolve_divination_choice(1, iid) and gs.resolve_divination_choice(0, iid), "discard validates owner and instance")
	check(foe.hand.size() == 1 and gs.pending_choice.type == "native-divination", "divination follows discard before enemy discard")
	place_all(gs)
	check(foe.hand.is_empty() and p.energy == fire, "special discard resolves enemy discard and returns paid fire")
	give(gs, "c11301")
	give(gs, "c11301", 1)
	play(gs, DISCARD)
	auto_choices(gs)
	check(foe.hand.size() == 1, "ordinary discard never strips enemy hand")

	var target: Dictionary = foe.units[0]
	target.level = 0
	gs._grow_unit(target, 0, 16)
	var old_hp: int = target.hp
	give(gs, STAR)
	give(gs, STAR)
	play(gs, HIT, target.uid)
	check(target.hp == old_hp - 7 and Luo.star_indices(p.hand).is_empty(), "0勾 target takes 5 plus two distinct hits")
	check(Luo.star_indices(p.deck).size() >= 2, "cast returns physical stars to own deck")

func realm_and_form() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	play(gs, REALM)
	check(p.realms.size() == 1 and p.realms[0].hp == 5, "space-time enters with printed durability")
	play(gs, REALM)
	check(p.realms.size() == 1, "new time realm replaces same-side time realm")
	p.restoredDrawTurn = gs.turn_counter
	p.restoredDrawCount = 0
	var old: Array = foe.units.map(func(u): return int(u.hp))
	gs._draw(0, 1)
	check(foe.units.map(func(u): return int(u.hp)) == old, "first draw no AoE")
	gs._draw(0, 1)
	check(foe.units.map(func(u): return int(u.hp)) == old.map(func(h): return h - 1) and foe.avatarHp == 30, "second draw hits enemy shikigami only")
	gs._draw(0, 1)
	check(foe.units.map(func(u): return int(u.hp)) == old.map(func(h): return h - 1), "third draw no extra AoE")
	p.avatarHp = 19
	play(gs, FORM)
	check(p.units[0].attack == 4 and p.units[0].maxHp == 6 and p.avatarHp == 19, "shape installed before choice, heal awaits")
	place_all(gs)
	check(p.avatarHp == 22, "entry heals three after choice")
	p.deck.append(Insight.instance(gs, 0, STAR))
	var count: int = p.hand.size()
	gs._draw(0, 1)
	check(p.hand.size() >= count + 2 and foe.avatarHp == 27, "star draws again and form damages enemy player")
	p.deck.append(Insight.instance(gs, 0, REALM))
	gs._draw(0, 1)
	check(foe.avatarHp == 27, "second Star Beyond draw has no same-turn form effect")

func transit_and_token() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var foe := gs.player(1)
	p.deck.clear()
	for id in ["c11301", STAR, STAR, STAR]: p.deck.append(Insight.instance(gs, 0, id))
	p.luohouDivinedTurn = gs.turn_counter
	for i in int(gs.rules.maxHandSize) - 1: give(gs, "c11301", 1)
	play(gs, TRANSIT)
	check(gs.pending_choice.type == "native-divination" and Luo.star_indices(foe.hand).is_empty(), "transit first pauses for actual divination")
	place_all(gs, true)
	check(Luo.star_indices(p.deck).is_empty() and Luo.star_indices(foe.hand).size() == 1 and foe.avatarHp == 24, "transit sends one and fires two separate projectiles")
	p.avatarHp = 20
	give(gs, STAR)
	give(gs, STAR)
	turn(gs, 0)
	check(p.avatarHp == 22 and Luo.star_indices(p.hand).is_empty(), "controlling 罗睺 heals for each expired hand star")
	var index: int = Luo.star_indices(foe.hand)[0]
	var fire: int = foe.energy
	check(not gs.can_play_card(1, index, "avatar-0").ok and gs.play_card(1, index), "enemy with no 罗睺 can use neutral star")
	check(foe.energy == fire - 1 and foe.avatarHp == 24 and Luo.star_indices(foe.hand).is_empty(), "paid star does nothing")
	give(gs, STAR, 1)
	turn(gs, 1)
	check(foe.avatarHp == 22 and Luo.star_indices(foe.hand).is_empty(), "unplayed enemy star deals two on expiry")

	gs = fixture()
	p = gs.player(0)
	foe = gs.player(1)
	p.deck = [Insight.instance(gs, 0, STAR), Insight.instance(gs, 0, STAR)]
	p.luohouDivinedTurn = gs.turn_counter
	var front: Dictionary = foe.units[0]
	front.front = 1
	front.hp = 3
	var back_hp: int = foe.units[1].hp
	for i in int(gs.rules.maxHandSize): give(gs, "c11301", 1)
	play(gs, TRANSIT)
	place_all(gs)
	var shots: Array = gs.rule_events.filter(func(e): return e.kind == "three-tail-projectile" and e.reason == "凶星凌日")
	check(shots.size() == 2 and shots[0].target == front.uid and shots[1].target == "avatar-1", "each failed placement resolves a true projectile and finds the current front")
	check(front.hp == 0 and foe.units[1].hp == back_hp and foe.avatarHp == 27, "projectile knockout exposes the player without targeting standby units")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		DisplayServer.window_set_size(viewport)
		var b := Battle.new()
		b.setup(TEAM, FOES, 93141)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		var p := gs.player(0)
		var foe := gs.player(1)
		var target: Dictionary = foe.units[0]
		gs._grow_unit(target, 0, 10)
		var hp: int = target.hp
		hand(b, [HIT, STAR])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(target.uid)))
		await settled(b)
		check(target.hp == hp - 6 and Luo.star_indices(p.hand).is_empty(), "mouse target resolves printed hit and real star")
		give(gs, "c11301", 1)
		hand(b, [DISCARD, STAR])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var option := choice_face(b, STAR)
		check(option != null, "mouse shows actual star in discard modal")
		if option != null: await click(option)
		await settled(b)
		var deck_choice := choice_face(b)
		check(deck_choice != null and gs.pending_choice.get("type") == "native-divination", "mouse discard continues to native divination")
		if deck_choice != null: await click(deck_choice)
		await settled(b)
		var top := choice_face(b, Divination.TOP)
		check(top != null, "mouse gets placement step")
		if top != null: await click(top)
		await settled(b)
		auto_choices(gs)
		check(foe.hand.is_empty(), "mouse path discards actual opponent card")
		hand(b, [OMEN])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var omen_choice := choice_face(b)
		check(omen_choice != null and gs.pending_choice.get("type") == "native-divination" and int(gs.pending_choice.count) == 3, "mouse path opens three-card divination from death omen")
		auto_choices(gs)
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	catalog_and_ai()
	augury_and_awaken()
	death_omen()
	discard_and_damage()
	realm_and_form()
	transit_and_token()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("LUOHOU checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
