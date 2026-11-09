extends "res://scripts/verify_insight.gd"

const Xuan := preload("res://scripts/xuan_rules.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")
const TEAM := ["xuan", "yaodaoji", "bailang", "hetong"]
const FOES := ["yaohu", "bingyong", "shantong", "xuenv"]
const DRAW := "w13-xuan-93125"
const FALL := "w13-xuan-93126"
const CHILD := "w13-xuan-93127"
const WISH := "w13-xuan-93128"
const REALM := "w13-xuan-93129"
const DOUBLE := "w13-xuan-93130"
const ECHO := "w13-xuan-93131"
const AWAKEN := "w13-xuan-93132"
const PIVOT := "xuan-star-pivot"
const LIGHT := "xuan-star-light"
const STEAL := "xuan-star-steal"
const LOCK := "xuan-star-lock"
const RETREAT := "xuan-star-retreat"
const MIGHT := "xuan-star-might"
const DOOM := "xuan-star-doom"

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("XUAN_FAIL ", detail)

func fixture() -> GS:
	var gs := GS.create(TEAM, FOES, 93125)
	prepare(gs)
	for owner in 2:
		var p := gs.player(owner)
		p.deck.clear()
		for i in 12: p.deck.append(Insight.instance(gs, owner, "c11301"))
		for u in p.units: u.front = 0
	return gs

func put_deck(gs: GS, ids: Array, owner: int = 0) -> void:
	for id in ids: gs.player(owner).deck.append(Insight.instance(gs, owner, id))

func defs(instances: Array) -> Array:
	return instances.map(func(i): return str(i.definitionId))

func settle_choices(gs: GS) -> void:
	for i in 12:
		if not gs.pending_choice.is_empty():
			check(AI.take_action(gs, gs.action_player()), "AI chooses " + str(gs.pending_choice.get("type", "")))
		elif not gs.response_window.is_empty(): gs.pass_response(gs.action_player())
		else: break
	check(gs.pending_choice.is_empty() and gs.response_window.is_empty(), "settlement completes")

func test_data() -> void:
	var gs := GS.create(TEAM, FOES, 93125)
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	check(int(u.attack) == 2 and int(u.maxHp) == 4, "base 2/4")
	check(gs.VerifiedRules.Factions.get_faction(u) == "苍叶", "printed faction")
	var deck_hand := defs(p.deck + p.hand)
	for id in Xuan.STAR_IDS:
		check(deck_hand.count(id) == 1 and Content.card_def(id).token and Content.card_def(id).deckLimit == 0, id + " original one injected, deck builder excluded")
	for id in [DRAW, FALL, CHILD, WISH, REALM, DOUBLE, ECHO, AWAKEN]:
		check(Content.card_def(id).get("verifiedRules", false), id + " native definition")
		check(ResourceLoader.exists("res://assets/official/cards/" + id + ".png"), id + " source artwork")
		gs = fixture()
		give(gs, id)
		if id == FALL: give(gs, MIGHT)
		var ai := AI._best_card(gs, 0)
		check(ai.ok and gs.can_play_card(0, int(ai.hand), ai.target).ok, id + " has a legal AI play")
		check(gs.can_play_card(0, 0).ok and gs.play_card(0, 0), id + " actual card legal")
		settle_choices(gs)

func test_draws() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var u: Dictionary = p.units[0]
	u.level = 1
	p.deck.clear()
	put_deck(gs, [DOOM, MIGHT, PIVOT, CHILD])
	gs._draw(0, 1)
	check(defs(p.hand) == [CHILD, PIVOT] and defs(p.deck) == [DOOM, MIGHT], "restricted draw ignores 2/3勾")
	put_deck(gs, [CHILD])
	gs._draw(0, 1)
	check(defs(p.hand) == [CHILD, PIVOT, CHILD] and gs.winner < 0, "no eligible star does not exhaust ordinary deck")
	u.level = 2
	play(gs, AWAKEN)
	check(gs.pending_choice.instanceIds.size() == 7 and not gs.resolve_divination_choice(1, DOOM), "specialization offers real seven and checks ownership")
	check(gs.resolve_divination_choice(0, DOOM) and u.awakened and int(u.attack) == 3 and int(u.maxHp) == 5, "chosen specialization and printed body")
	check(defs(p.deck).count(DOOM) == 3 and Xuan.card_level(gs, 0, DOOM) == 2, "all same-name instances specialize and exactly two copies added")
	play(gs, AWAKEN)
	check(DOOM not in gs.pending_choice.instanceIds and not gs.resolve_divination_choice(0, DOOM), "repeat awakening excludes known specialization")
	check(gs.resolve_divination_choice(0, PIVOT), "repeat awakening chooses different star")
	p.deck.clear()
	put_deck(gs, [DOOM, CHILD])
	u.level = 1
	gs._draw(0, 1)
	check(defs(p.hand).slice(-2) == [CHILD, DOOM], "awakened draw removes grade restriction")
	p.hand.clear()
	put_deck(gs, [PIVOT, MIGHT, "c11301"])
	play(gs, DRAW)
	check(defs(p.hand).size() == 2 and PIVOT in defs(p.hand) and MIGHT in defs(p.hand), "星渊 draws real two star instances")
	check(defs(p.deck).has(PIVOT) and defs(p.deck).has(MIGHT) and defs(p.deck).count("c11301") == 1, "星渊 reshuffles one copy of each drawn")
	p.hand.clear()
	p.deck.clear()
	play(gs, DRAW)
	check(p.hand.is_empty() and p.deck.is_empty() and gs.winner < 0, "star-only draw no-card case does not lose game")

func test_starfall_and_repeats() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	var u: Dictionary = p.units[0]
	u.level = 2
	play(gs, CHILD)
	play(gs, DOUBLE)
	play(gs, DOUBLE)
	give(gs, MIGHT)
	give(gs, MIGHT)
	give(gs, DOOM)
	var fire: int = p.energy
	play(gs, FALL)
	check(p.energy == fire - 1 and defs(p.hand) == [MIGHT, DOOM], "星坠 pays own fire, casts one distinct eligible instance")
	check(int(u.attack) == 8 and int(u.maxHp) == 10 and int(e.avatarHp) == 12 and u.front == 0 and not p.attackUsed, "one ordinary plus two repeated buffs and remote attacks without consuming basic attack")
	turn(gs, 0)
	check(int(u.attack) == 2 and int(u.maxHp) == 4, "temporary strengths clear at turn boundary")
	turn(gs, 1)
	p.energy = 40
	var foe: Dictionary = e.units[0]
	foe.level = 3
	var foe_power: int = foe.attack
	play(gs, STEAL, foe.uid)
	check(int(u.attack) == 3 and int(foe.attack) == foe_power - 1, "天玑 transfers real strength")
	turn(gs, 0)
	check(int(u.attack) == 2 and int(foe.attack) == foe_power, "stolen strength expires on both characters")

	gs = fixture()
	foe = gs.player(1).units[0]
	gs._grow_unit(foe, 0, 20 - int(foe.maxHp))
	play(gs, DOUBLE)
	play(gs, DOUBLE)
	play(gs, LIGHT, foe.uid)
	var hits: Array = gs.rule_events.filter(func(event): return event.kind == "damage-resolved" and event.card.id == LIGHT)
	check(int(foe.hp) == 8 and hits.size() == 3 and hits.all(func(hit): return hit.amount == 4 and hit.resolutionId == hits[0].resolutionId and hit.resolutionId >= 0), "重复天璇的三次伤害保留同一个实际用牌结算")

func test_star_branches() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	var target: Dictionary = e.units[0]
	var ally: Dictionary = p.units[1]
	target.level = 0
	var ordinary := give(gs, LIGHT)
	check(not gs.can_play_card(0, ordinary, ally.uid).ok and not gs.can_play_card(0, ordinary, "avatar-1").ok, "天璇 rejects friendly/avatar targets")
	target.movementVeil = true
	check(not gs.can_play_card(0, ordinary, target.uid).ok, "天璇 rejects enemy veil")
	target.movementVeil = false
	target.hp = 20
	check(gs.play_card(0, ordinary, target.uid) and target.hp == 16, "天璇 normal 4 damage")
	target.front = 1
	play(gs, RETREAT, target.uid)
	check(target.hp == 13 and target.front == 0, "玉衡 applies damage then moves selected target")
	p.xuanSpecialized = [LIGHT, LOCK, RETREAT, MIGHT, STEAL]
	target.front = 1
	for u in e.units: gs._grow_unit(u, 0, 20 - int(u.maxHp))
	play(gs, LIGHT)
	check(e.units[0].hp == 16 and e.units[1].hp == 16 and e.units[2].hp == 16 and e.units[3].hp == 20, "天璇 specialization hits front and two middle slots once")
	target.summoned = true
	play(gs, LIGHT)
	check(target.hp == 16 and e.units[1].hp == 12 and e.units[2].hp == 12, "专精天璇 only hits shikigami and skips a non-shikigami front summon")
	target.summoned = false
	give(gs, "c12001", 1)
	var dedicated: Array = Content.cards_for_unit(target.id).filter(func(card): return not card.token)
	give(gs, dedicated[0].id, 1)
	var before: int = e.hand.size()
	play(gs, LOCK, target.uid)
	check(int(target.frozen) > 0 and e.hand.size() == before - 1 and e.hand.all(func(c): return c.definitionId != dedicated[0].id), "专精天权 stuns and discards actual dedicated card")
	check("instant" in gs.hand_card_def(0, give(gs, RETREAT)).keywords and "instant" not in gs.hand_card_def(0, give(gs, STEAL)).keywords, "specialized instant eligibility updates")
	play(gs, MIGHT)
	check(int(p.units[0].attack) == 5 and gs.VerifiedRules.Combat.has(p.units[0], "pierce"), "开阳·武曲 +3/+3 and pierce")
	for i in range(1, e.units.size()): e.units[i].hp = 0
	play(gs, DOOM)
	check(target.hp == 0 and int(target.knockout) > 0, "摇光 destroys actual surviving target")

func test_wishes() -> void:
	for wish in Xuan.WISH_IDS:
		var gs := fixture()
		var p := gs.player(0)
		var u: Dictionary = p.units[0]
		var i := give(gs, WISH)
		var played: Dictionary = p.hand[i]
		check(gs.play_card(0, i) and gs.pending_choice.instanceIds == Xuan.WISH_IDS, "wish exposes three genuine forms")
		check(not gs.resolve_divination_choice(0, ECHO) and gs.resolve_divination_choice(0, wish), "wish rejects unknown, installs requested")
		check(u.form.cardId == wish and u.attack == 3 and u.maxHp == 5 and int(u.formCountdown.remaining) == 7, "wish uses real body and timer")
		p.avatarHp = 15
		gs._knockout_unit(p.units[1])
		gs._knockout_unit(p.units[2])
		var old_deck: int = p.deck.size()
		play(gs, MIGHT)
		check(int(u.formCountdown.remaining) == 6, "one star accelerates wish once")
		gs.VerifiedRules.reduce_countdown(gs, 0, 0, 6)
		gs._resolve_resolution_stack()
		check(u.form.is_empty() and p.hand.has(played), "same spent card returns and form ends")
		if wish == Xuan.WISH_IDS[0]: check(p.avatarHp == 27 and p.units[1].hp == 0, "healing wish restores exactly 12")
		if wish == Xuan.WISH_IDS[1]: check(p.units[1].hp > 0 and p.units[2].hp > 0 and p.avatarHp == 15, "revival wish restores all allied shikigami only")
		if wish == Xuan.WISH_IDS[2]: check(p.deck.size() == old_deck + 7 and Xuan.STAR_IDS.all(func(id): return id in defs(p.deck)), "star wish injects seven different instances")
	var gs := fixture()
	var p := gs.player(0)
	var disabled: Dictionary = p.units[1]
	disabled.catCannotRevive = true
	gs._knockout_unit(disabled)
	play(gs, WISH)
	check(AI.take_action(gs, 0) and p.units[0].form.cardId == Xuan.WISH_IDS[2], "仅有永久气绝时，AI 选择明星而非无法复活的愿望")

func test_fate_and_echo() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	p.deck.clear()
	put_deck(gs, [LIGHT, "c11301", STEAL])
	p.xuanSpecialized = [PIVOT]
	var old: Dictionary = p.deck.front()
	play(gs, PIVOT)
	check(gs.pending_choice.type == Fate.KIND and not gs.resolve_divination_choice(1, Fate.REVERSE), "命运抉择 pauses and rejects opponent")
	check(gs.resolve_divination_choice(0, Fate.REVERSE), "reverse target is legal")
	check(p.hand.has(old) and p.deck.front().definitionId == STEAL and int(p.destinyReversed) == 1, "specialized pivot swaps actual deck instances, reveals and draws")
	gs._grow_unit(e.units[0], 0, 30 - int(e.units[0].maxHp))
	for i in range(1, e.units.size()): e.units[i].hp = 0
	play(gs, ECHO)
	check(gs.resolve_divination_choice(0, LIGHT) and gs.pending_choice.type == "xuan-target", "echo prompts first targeted star")
	check(gs.resolve_divination_choice(0, e.units[0].uid) and e.units[0].hp == 26, "first echo executes actual manually chosen target")
	turn(gs, 0)
	check(e.units[0].hp == 26, "opponent turn never consumes echo")
	turn(gs, 1)
	check(e.units[0].hp == 22 and p.xuanEchoes[0].left == 1, "next own start automatic star: %s" % str([e.units[0].hp, p.xuanEchoes, gs.current_player, gs.phase]))
	turn(gs, 0)
	turn(gs, 1)
	check(e.units[0].hp == 18 and p.xuanEchoes.is_empty(), "second own start consumes last scheduled cast: %s" % str([e.units[0].hp, p.xuanEchoes, gs.current_player, gs.phase]))
	turn(gs, 0)
	turn(gs, 1)
	check(e.units[0].hp == 18, "third own start has no echo: %s" % str([e.units[0].hp, p.xuanEchoes, gs.current_player, gs.phase]))
	gs = fixture()
	p = gs.player(0)
	for enemy in gs.player(1).units: gs._knockout_unit(enemy)
	play(gs, ECHO)
	check(DOOM in gs.pending_choice.instanceIds, "无存活敌方时摇光仍可由玩家选择")
	check(AI.take_action(gs, 0) and p.xuanEchoes.size() == 1 and p.xuanEchoes[0].id == MIGHT, "AI 选择有效极星并为后续回合记录开阳")

func test_realm() -> void:
	var gs := fixture()
	var p := gs.player(0)
	var e := gs.player(1)
	for u in e.units: gs._grow_unit(u, 0, 20 - int(u.maxHp))
	play(gs, MIGHT)
	play(gs, MIGHT)
	play(gs, REALM)
	check(p.realms.size() == 1 and int(p.realms[0].hp) == 6 and p.xuanSpellCount == 2, "realm enters with 6 durability and remembers prior spells")
	var deck_before: int = p.deck.size()
	play(gs, MIGHT)
	check(p.deck.size() == deck_before - 1 and p.xuanSpellCount == 3, "third spell draws")
	play(gs, MIGHT)
	var fire_before: int = p.energy
	play(gs, MIGHT)
	check(p.energy == fire_before, "fifth spell restores one ghost fire")
	play(gs, MIGHT)
	play(gs, MIGHT)
	check(e.units.all(func(u): return int(u.hp) == 17) and e.avatarHp == 27, "seventh damages all enemies including player")
	play(gs, REALM)
	check(p.realms.size() == 1, "second space-time replaces existing instead of stacking")
	turn(gs, 0)
	turn(gs, 1)
	p.energy = 40
	play(gs, MIGHT)
	check(p.xuanSpellCount == 1 and e.avatarHp == 27, "spell count resets on next turn")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for viewport in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = viewport
		DisplayServer.window_set_size(viewport)
		var b := Battle.new()
		b.setup(TEAM, FOES, 93125)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		var u: Dictionary = gs.player(0).units[0]
		var foe: Dictionary = gs.player(1).units[0]
		foe.hp = 20
		foe.level = 0
		hand(b, [LIGHT])
		await settled(b)
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0 and gs.valid_targets(0, b._pending_target_card_def).has(foe.uid), "mouse highlights a legal zero-level enemy")
		await click(b._unit_widget(str(foe.uid)))
		await settled(b)
		check(foe.hp == 16, "mouse target routes 4 damage")
		hand(b, [WISH])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var heal_face := choice_face(b, Xuan.WISH_IDS[0])
		check(heal_face != null, "mouse sees actual wish choices")
		if heal_face != null: await click(heal_face)
		await settled(b)
		check(u.form.get("cardId") == Xuan.WISH_IDS[0], "mouse installs selected real wish")
		hand(b, [AWAKEN])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var first := choice_face(b, PIVOT)
		var last := choice_face(b, DOOM)
		check(first != null and last != null and first.get_global_rect().position.x >= 0 and last.get_global_rect().end.x <= viewport.x, "seven specialization choices fit")
		if last != null: await click(last)
		await settled(b)
		check(DOOM in gs.player(0).get("xuanSpecialized", []), "mouse specializes last displayed star")
		hand(b, [ECHO])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var light_face := choice_face(b, LIGHT)
		check(light_face != null, "mouse sees star selection for echo")
		if light_face != null: await click(light_face)
		await settled(b)
		var foe_face := choice_face(b, str(foe.uid))
		check(foe_face != null, "mouse sees actual target in nested choice")
		if foe_face != null: await click(foe_face)
		await settled(b)
		check(foe.hp == 12 and gs.pending_choice.is_empty(), "nested mouse target resolves actual initial echo")
		var deck: Array = gs.player(0).deck
		var old_bottom: Dictionary = deck.front()
		hand(b, [PIVOT])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		var reverse := choice_face(b)
		for face in faces(b._choice_layer):
			if str(face.data.name).begins_with("逆天"): reverse = face
		check(reverse != null and str(reverse.data.name).begins_with("逆天"), "mouse sees both actual deck choices")
		if reverse != null: await click(reverse)
		await settled(b)
		check(gs.pending_choice.is_empty() and deck.back() == old_bottom, "mouse reverses actual deck positions")
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	test_data()
	test_draws()
	test_starfall_and_repeats()
	test_star_branches()
	test_wishes()
	test_fate_and_echo()
	test_realm()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	await process_frame
	print("XUAN checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
