extends "res://scripts/verify_insight.gd"

const TEAM := ["yuyuan-banruo", "bailang", "shantong", "hetong"]
const OTHER := ["yaohu", "yijin-zhentian", "tiaotiaodidi", "yaodaoji"]
const TOKEN := "fate-banruo-avenge"
const Status := preload("res://scripts/ui/battle_status.gd")
const Fate := preload("res://scripts/destiny_choice_rules.gd")

func id(n: int) -> String:
	return "w13-yuyuan-banruo-%d" % (93132 + n)

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GRUDGE_FAIL ", detail)

func fixture(owner: int = 0) -> GS:
	var gs := GS.create(TEAM if owner == 0 else OTHER, OTHER if owner == 0 else TEAM, 93133)
	prepare(gs)
	gs.phase = "main"
	gs.current_player = owner
	gs.turn_counter = 13
	for side in gs.players:
		side.realms.clear()
		side.deck.clear()
		for n in 8: side.deck.append({"definitionId": "c10301", "instanceId": "%s-grudge-deck-%d" % [side.id, n]})
		for u in side.units: u.front = 0
	return gs

func amount(u: Dictionary) -> int:
	return int(u.get("grudge", 0))

func has_token(p: Dictionary) -> bool:
	return p.hand.any(func(c): return c.definitionId == TOKEN)

func play_for(gs: GS, owner: int, n: int, target = null) -> bool:
	return gs.play_card(owner, give(gs, id(n), owner), target)

func catalog() -> void:
	var gs := fixture()
	var unit := Content.unit_def("yuyuan-banruo")
	check(unit.attack == 2 and unit.maxHp == 5 and gs.VerifiedRules.Factions.get_faction(gs.player(0).units[0]) == "青岚", "2/5 青岚")
	check(Content.cards_for_unit(unit.id).filter(func(c): return not c.token).size() == 8, "eight existing collectible IDs")
	check(Content.card_def(TOKEN).token and TOKEN not in Content.default_deck(TEAM).cardIds, "token stays outside deck")
	for n in range(1, 9):
		var card := Content.card_def(id(n))
		check(card.get("verifiedRules", false) and not card.get("verificationPending", []).is_empty(), "source-backed rules and limits " + id(n))
		check(FileAccess.file_exists("res://assets/official/cards/%s.png" % id(n)), "linked source artwork " + id(n))

func grudge_and_avenging() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = own.units[0]
	gs._damage_unit(0, 0, 1, 0, 1)
	check(amount(u) == 0, "friendly damage does not attach")
	gs._grant_unit_armor(u, 1)
	gs._damage_unit(0, 0, 1, 1, 0)
	check(amount(u) == 0, "fully absorbed damage does not attach")
	gs._damage_unit(0, 0, 1, 1, 0)
	check(amount(u) == 1, "nonlethal enemy damage attaches once")
	gs._damage_unit(0, 0, 20, 1, 0)
	check(u.hp == 0 and amount(u) == 1, "lethal damage adds none and knockout retains existing Grudge")
	check(gs.VerifiedRules.Peach.revive(gs, 0, 1, u, false, false), "native revival preserves retained stacks")
	gs.VerifiedRules.Grudge.attach(gs, 0, 0, 4)
	check(amount(u) == 1 and has_token(own), "crossing four grants exactly one token and keeps leftover")
	var target: Dictionary = foe.units[0]
	target.front = 1
	target.attack = 3
	check(gs.play_card(0, 0) and foe.avatarHp == 27 and u.hp == 2 and amount(u) == 2, "active avenging reflects actual counterstrike damage")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	u.front = 1
	own.energy = 0
	gs.current_player = 1
	foe.units[0].attack = 2
	var hand_idx := give(gs, TOKEN)
	check(gs.effective_card_cost(0, gs.hand_card_def(0, hand_idx)) == 0, "defender token gets opponent-turn Instant")
	check(gs.basic_attack(1, 0) and not has_token(own) and foe.avatarHp == 28 and u.hp == 3, "ordinary opponent attack consumes token and reflects")
	check(gs.kw_usage(0, "instant").used and own.energy == 0, "automatic response uses shared instant allowance")
	give(gs, TOKEN)
	foe.attackUsed = false
	check(gs.basic_attack(1, 0) and has_token(own) and foe.avatarHp == 28, "no second free response after allowance was spent")

func basic_cards() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = own.units[0]
	var enemy: Dictionary = foe.units[0]
	enemy.front = 1
	enemy.attack = 3
	check(play_for(gs, 0, 1) and u.attack == 3 and u.hp == 3 and amount(u) == 2, "copy greater front power permanently, add armor and Grudge")
	gs = fixture()
	u = gs.player(0).units[0]
	check(play_for(gs, 0, 1) and amount(u) == 0 and u.attack == 2 and u.shield == 1, "empty enemy front cannot copy power")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	give(gs, "c10301", 1)
	var deck_size: int = own.deck.size()
	check(play_for(gs, 0, 2) and own.hand.size() == 2 and own.deck.size() == deck_size-2 and amount(own.units[0]) == 2, "fewer hand cards draw exactly two")
	check(play_for(gs, 0, 2) and own.hand.size() == 3 and has_token(own), "not fewer cards: no draw but four-stack token generated")
	gs = fixture()
	own = gs.player(0)
	give(gs, "c10301")
	var grudge_index := give(gs, id(2))
	give(gs, "c10301", 1)
	give(gs, "c10301", 1)
	own.deck[0] = Insight.instance(gs, 0, id(2))
	Fate.offer(gs, 0, 0)
	check(gs.hand_card_def(0, grudge_index).enhanced and not Fate.choice_card(gs, 0, Fate.REVERSE).enhanced, "命运抉择预览牌库底的仇鬼时不扣手牌")
	check(gs.resolve_divination_choice(0, Fate.FOLLOW), "顺应天命保留两端实体")
	own.units[0].grudge = 2
	deck_size = own.deck.size()
	check(not gs.hand_card_def(0, grudge_index).enhanced, "仇鬼预览先算生成予愿必还，再比较双方手牌")
	check(gs.play_card(0, grudge_index) and own.deck.size() == deck_size and own.hand.size() == 2 and has_token(own), "实际结算生成予愿必还后手牌相等，不抽牌")
	gs = fixture(1)
	var card_idx := give(gs, id(3), 1)
	check(gs.effective_card_cost(1, gs.hand_card_def(1, card_idx)) == 0, "second side has Instant on its own turn")
	check(gs.play_card(1, card_idx) and gs.player(0).avatarHp == 26 and gs.player(1).units[0].shield == 2 and amount(gs.player(1).units[0]) == 1, "second side +2 power, +2 armor, attaches once")
	gs = fixture()
	check(play_for(gs, 0, 3) and gs.player(1).avatarHp == 28 and amount(gs.player(0).units[0]) == 0, "first side has normal combat")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	own.avatarHp = 19
	foe.avatarHp = 20
	foe.units[0].front = 1
	check(play_for(gs, 0, 5) and own.avatarHp == 23 and foe.avatarHp == 16 and int(foe.units[0].hp) == int(foe.units[0].maxHp), "lower health direct hits avatar and lifesteals")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	foe.avatarHp = 20
	foe.units[0].front = 1
	check(play_for(gs, 0, 5) and foe.avatarHp == 20 and int(foe.units[0].hp) < int(foe.units[0].maxHp) and amount(own.units[0]) >= 1, "higher health has no direct or lifesteal and still attaches Grudge")

func realm_and_last_wish() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = own.units[0]
	own.avatarHp = 22
	var bottom: String = foe.deck[0].instanceId
	var reserve: int = foe.deck.size()
	check(play_for(gs, 0, 6) and own.realms.size() == 1 and own.realms[0].hp == 6 and own.avatarHp == 25 and foe.deck.size() == reserve - 1, "realm equal-deck entry mills and heals")
	check(foe.removedCards[0].instance.instanceId == bottom and amount(u) == 1, "removal takes the exact bottom instance and adds one Grudge")
	gs._knockout_unit(u)
	gs._trigger_realms(0)
	check(amount(u) == 2 and own.avatarHp == 25 and foe.deck.size() == reserve-1, "realm keeps ticking while source knocked; larger deck skips mill and heal")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	check(play_for(gs, 0, 4) and u.attack == 2 and u.hp == 8 and amount(u) == 2, "form sets printed stats and attaches 2")
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	check(foe.avatarHp == 30, "reserve death does not trigger Last Wish")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	check(play_for(gs, 0, 4), "install Last Wish form")
	u.front = 1
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	check(foe.avatarHp == 27 and foe.units.filter(func(e): return e.hp <= 0).size() == 1, "front death projects then destroys a random enemy when behind")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	check(play_for(gs, 0, 4), "install form for negative case")
	u.front = 1
	gs._knockout_unit(foe.units[1])
	gs._knockout_unit(u)
	gs._resolve_resolution_stack()
	check(foe.avatarHp == 27 and foe.units.filter(func(e): return e.hp <= 0).size() == 1, "equal knocked count stops extra destruction")

func oath_and_awakening() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = own.units[0]
	var target: Dictionary = foe.units[0]
	u.front = 1
	target.baseAttack = 1
	gs._recalc(target)
	var idx := give(gs, id(7))
	check(not gs.can_play_card(0, idx, u.uid).ok and not gs.can_play_card(0, idx, "avatar-1").ok, "oath targets only enemy shikigami")
	target.keywords = ["veil"]
	check(not gs.can_play_card(0, idx, target.uid).ok, "veiled target is illegal")
	target.keywords = []
	var attack_before: int = target.attack
	check(gs.play_card(0, idx, target.uid) and int(target.attack) == attack_before+3 and u.hp == u.maxHp and amount(u) == 1, "oath gives permanent power, forces combat and heals damaged living Banruo")
	check(own.hand.size() == 1 and Content.card_def(own.hand[0].definitionId).type != "awakening", "actual non-awakening random gain")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	target = foe.units[0]
	check(play_for(gs, 0, 7, target.uid) and own.hand.is_empty() and amount(u) == 0 and own.avatarHp < 30, "an empty front can cause avatar damage and never heals/generates")
	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	idx = give(gs, id(8))
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 1, "awakening costs fire if nobody opposite awakened")
	foe.units[1].awakened = true
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0 and gs.play_card(0, idx), "enemy awakening grants actual instant payment")
	check(u.awakened and u.attack == 3 and u.maxHp == 8, "awakening applies printed +1/+3")
	gs._damage_unit(0,0,1,1,0)
	check(amount(u) == 2, "awakened enemy damage attaches two")
	foe.units[0].front = 1
	foe.units[0].hp = 10
	foe.units[0].attack = 0
	var token := give(gs, TOKEN)
	check("instant" in gs.hand_card_def(0, token).keywords and gs.play_card(0, token), "awakened active derivative gains permanent Instant")
	check(foe.units[0].hp == 0 and foe.avatarHp == 30, "awakened active derivative destroys, even without receiving damage")
	foe.units[2].front = 1
	foe.units[2].hp = 10
	foe.units[2].attack = 0
	check(gs.basic_attack(0, 0) and foe.units[2].hp == 0, "active vow affects a second combat this turn")
	gs.turn_counter += 1
	own.attackUsed = false
	foe.units[3].front = 1
	foe.units[3].hp = 10
	foe.units[3].attack = 0
	check(gs.basic_attack(0, 0) and foe.units[3].hp > 0, "vow expires at the turn boundary")

	gs = fixture()
	own = gs.player(0)
	foe = gs.player(1)
	u = own.units[0]
	check(play_for(gs, 0, 8), "awaken to test opponent turn separately")
	u.front = 1
	gs.current_player = 1
	foe.units[0].attack = 2
	foe.units[0].hp = 10
	own.energy = 0
	give(gs, TOKEN)
	check(gs.basic_attack(1, 0) and foe.avatarHp == 28 and foe.units[0].hp > 0 and not has_token(own), "awakened automatic response retains reflection and does not destroy")

func ai_targets() -> void:
	var gs := fixture()
	var own := gs.player(0)
	var foe := gs.player(1)
	var u: Dictionary = own.units[0]
	u.front = 1
	for e in foe.units:
		e.baseAttack = 6
		gs._recalc(e)
	foe.units[2].baseAttack = 1
	gs._recalc(foe.units[2])
	var idx := give(gs, id(7))
	check(gs.can_play_card(0, idx, foe.units[2].uid).ok, "safe target is legal for AI")
	check(AI.take_action(gs, 0) and foe.units[2].attack == 4 and u.hp == u.maxHp and amount(u) == 1, "AI selects the viable oath target and gains payoff")
	idx = give(gs, id(8))
	u.awakened = true
	check(not gs.can_play_card(0, idx).ok, "already awakened unit cannot pay for another copy")

func ui_checks() -> void:
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		DisplayServer.window_set_size(physical)
		var b := Battle.new()
		b.setup(TEAM, OTHER, 93139)
		b._ai_thinking = true
		root.add_child(b)
		await create_timer(0.4).timeout
		var gs := b.gs
		prepare(gs)
		gs.phase = "main"
		var own := gs.player(0)
		var foe := gs.player(1)
		own.units[0].front = 1
		foe.units[0].baseAttack = 1
		gs._recalc(foe.units[0])
		foe.units[1].keywords = ["veil"]
		hand(b, [id(7)])
		await settled(b)
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.valid_targets(0, gs.hand_card_def(0,0)).has(foe.units[0].uid) and not gs.valid_targets(0, gs.hand_card_def(0,0)).has(foe.units[1].uid), "valid targets exposed on board " + str(physical))
		await click(b._unit_widget(str(foe.units[0].uid)))
		await settled(b)
		check(amount(own.units[0]) == 1 and int(own.units[0].hp) == int(own.units[0].maxHp), "mouse settles oath, damage, recovery and Grudge " + str(physical))
		check(own.hand.size() == 1 and own.hand[0].definitionId != id(7), "mouse settlement generates new card " + str(physical))
		b.queue_free()
		await process_frame

func run() -> void:
	var stores := Support.isolate_stores()
	catalog()
	grudge_and_avenging()
	basic_cards()
	realm_and_last_wish()
	oath_and_awakening()
	ai_targets()
	if "--ui" in OS.get_cmdline_user_args(): await ui_checks()
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("GRUDGE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
