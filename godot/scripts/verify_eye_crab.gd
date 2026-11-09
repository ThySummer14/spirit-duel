extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")
const Eye := preload("res://scripts/eye_rules.gd")
const Crab := preload("res://scripts/crab_rules.gd")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("EYE_CRAB_FAIL ", detail)

func game(enemy_lineup: Array = []) -> GS:
	var gs := GS.create(["baimugui", "xieji", "hetong", "banruo"], ["bingyong", "yaodaoji", "shanfeng", "longyechaji"] if enemy_lineup.is_empty() else enemy_lineup, 196210)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "eye-crab-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "actual play " + id)

func finish(gs) -> void:
	for i in 120:
		if gs.pending_choice.is_empty() and gs.response_window.is_empty(): return
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs, gs.action_player()), "AI completes actual choice")
		else: gs.pass_response(gs.action_player())
	check(false, "choice continuation terminates")

func place(gs, id: String, where: String) -> void:
	var owner: int = gs.action_player()
	check(gs.resolve_divination_choice(owner, id), "select actual top-deck instance " + id)
	check(gs.resolve_divination_choice(owner, where), "place original top/bottom")

func total_hp(gs, owner: int) -> int:
	var hp := int(gs.player(owner).avatarHp)
	for unit in gs.player(owner).units: hp += int(unit.hp)
	return hp

func eye_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	var size_before: int = p.hand.size()
	play(gs, "c19603")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 6 and p.hand.size() == size_before, "insight is3/6 and does not invent turn draw")
	play(gs, "c19601")
	check(gs.pending_choice.originalIds.size() == 2 and p.hand.is_empty() and foe.avatarHp == 30, "insight increases native divination before drawing")
	finish(gs)
	check(p.hand.size() == 2 and foe.avatarHp == 29, "completed divination projects once then draws2")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c19605"); check(p.units[0].awakened and p.units[0].attack == 3 and p.units[0].maxHp == 6, "awakening gains exact1/1 before its divination")
	finish(gs); check(foe.avatarHp == 28, "awakening divination2 uses awakened projectile2")
	play(gs, "c19603"); play(gs, "c19601"); check(gs.pending_choice.originalIds.size() == 2, "insight adds1 to later divination")
	finish(gs); check(foe.avatarHp == 26, "awakened damage equals actual inspected count")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	gs._knockout_unit(p.units[0]); Divination.start(gs, 0, 2); finish(gs)
	check(foe.avatarHp == 30, "knocked eye cannot project from ally divination")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.units[0].hp = 1
	var h := give(gs, "c19602"); var iid := str(p.hand[h].instanceId); var deck_size: int = p.deck.size()
	check(gs.play_card(0, h, foe.units[0].uid), "flame real selected enemy")
	check(foe.units[0].hp == 0 and foe.avatarHp == 29 and p.deck.size() == deck_size + 1 and p.hand.is_empty(), "flame pierces excess and shuffles original without fake draw")
	check(p.deck.any(func(i): return str(i.instanceId) == iid) and int(p.eyeFlameGrowth) == 2, "original flame instance returns and global same-name damage grows")
	check(gs.hand_card_def(0, give(gs, "c19602")).value == 4, "different same-name flame inherits permanent damage")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	p.deck = [{"instanceId":"gaze-three", "definitionId":"c19607"}]
	play(gs, "c19606", "avatar-1")
	check(foe.avatarHp == 24 and p.hand[0].instanceId == "gaze-three", "gaze chooses avatar and uses actual drawn level3")
	p.deck = [{"instanceId":"gaze-one", "definitionId":"c19602"}]
	play(gs, "c19606", p.units[1].uid)
	check(p.units[1].hp == 4, "gaze legally targets own character with actual drawn level1")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c19604", foe.units[1].uid)
	check(foe.units[1].front == 1 and foe.units[1].hp == foe.units[1].maxHp and p.energy == 29, "mind strike actually moves enemy without invented projectile or free cost")
	play(gs, "c19604", p.units[1].uid); check(p.units[1].front == 1, "mind strike can move own ally")
	foe.units[2].formRules = {"combatKeywords":["remote"]}
	h = give(gs, "c19604")
	check(not gs.can_play_card(0, h, foe.units[2].uid).ok, "move rejects remote entering front before spending fire")
	p.units[1].formRules = {"lockEnemyFrontReplacement":true}
	check(not gs.can_play_card(0, h, foe.units[3].uid).ok, "enemy movement respects target side's front replacement lock")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.units[1].formRules = {"combatKeywords":["veil"]}
	foe.deck = [{"instanceId":"foe-wind", "definitionId":"c17502"},{"instanceId":"foe-blade", "definitionId":"c10101"}]
	play(gs, "c19607")
	check(gs.pending_choice.zoneOwner == 1 and gs.pending_choice.playerIndex == 0 and not gs.resolve_divination_choice(1, "foe-blade"), "enemy divination is controlled by caster and rejects other side")
	place(gs, "foe-blade", Divination.TOP); place(gs, "foe-wind", Divination.BOTTOM)
	check(foe.units[1].hp == 0 and foe.deck.back().instanceId == "foe-blade" and foe.deck.size() == 2, "all-knowing reveals preserved top card and destroys source through veil without drawing")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c19608")
	var attached := 0
	for inst in foe.deck: attached += int(inst.get("eyeCurses", 0))
	check(attached == 4 and p.units[0].attack == 4 and p.units[0].maxHp == 8, "curse form attaches actual four cards and sets4/8")
	gs._knockout_unit(p.units[0]); gs.current_player = 1
	foe.hand.clear()
	for i in 3: give(gs, "c10101", 1)
	foe.deck = [{"instanceId":"cursed-one", "definitionId":"c17502", "eyeCurses":1}]
	gs._draw(1, 1); gs._resolve_resolution_stack()
	check(gs.pending_choice.get("type") == "eye-curse" and gs.pending_choice.instanceIds.size() == 4, "drawing true cursed instance opens4 choices even with source knocked")
	check(not gs.resolve_divination_choice(0, "eye-curse-hand"), "curse rejects wrong controller")
	check(gs.resolve_divination_choice(1, "eye-curse-hand") and foe.hand.size() == 2, "curse randomly discards exact half of actual4 hand")
	for selection in ["eye-curse-life", "eye-curse-units", "eye-curse-lose"]:
		foe.deck.append({"instanceId":"cursed-" + selection, "definitionId":"c17502", "eyeCurses":1})
		gs._draw(1, 1); gs._resolve_resolution_stack()
		check("eye-curse-hand" not in gs.pending_choice.instanceIds, "used curse never offered again")
		check(gs.resolve_divination_choice(1, selection), "actual curse choice " + selection)
		if selection == "eye-curse-life": check(foe.maxAvatarHp == 8 and foe.avatarHp == 8, "life curse changes maximum and clamps current hp")
		if selection == "eye-curse-units": check(foe.units.filter(func(u): return int(u.hp) == 0).size() == 2, "unit curse randomly knocks exactly2 living units")
	check(gs.winner == 0 and foe.eyeCursesChosen.size() == 4, "fourth curse is actual game loss")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	foe.deck.append({"instanceId":"outside-turn-curse", "definitionId":"c17502", "eyeCurses":1})
	gs._draw(1, 1); gs._resolve_resolution_stack()
	check(gs.pending_choice.is_empty() and foe.get("eyeCursesChosen", []).is_empty(), "curse draw outside own turn does not activate")
	gs.current_player = 1; foe.hand.clear()
	for i in int(gs.rules.maxHandSize): give(gs, "c10101", 1)
	foe.deck.append({"instanceId":"burned-curse", "definitionId":"c17502", "eyeCurses":2})
	gs._draw(1, 1); gs._resolve_resolution_stack()
	check(gs.pending_choice.get("type") == "eye-curse" and foe.hand.size() == int(gs.rules.maxHandSize), "burned cursed draw still opens curse without replacing held cards")
	check(gs.resolve_divination_choice(1, "eye-curse-life") and gs.pending_choice.get("type") == "eye-curse", "two stacked curses trigger two independent choices")
	check(gs.resolve_divination_choice(1, "eye-curse-hand") and foe.hand.size() == 6, "second stacked curse excludes first and discards half actual held hand")
	gs = game(); foe = gs.player(1)
	for idx in [1, 2, 3]: gs._knockout_unit(foe.units[idx])
	var decoy: Dictionary = gs.VerifiedRules.NativeSummons.summon(gs, 1, 0, "eye-curse-decoy", "普通召唤物", 0, 9, {"countsAsShikigami": false})
	gs.current_player = 1
	foe.deck = [{"instanceId":"cursed-shikigami-only", "definitionId":"c17502", "eyeCurses":1}]
	gs._draw(1, 1); gs._resolve_resolution_stack()
	check(gs.resolve_divination_choice(1, "eye-curse-units"), "actual curse can be selected with fewer than two living shikigami")
	check(foe.units[0].hp == 0 and decoy.hp == 9 and gs.front_unit(1).uid == decoy.uid, "random destruction can only choose living shikigami; an ordinary summon never fills the second slot")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c19608"); p.units[1].front = 1
	var count_before: int = p.deck.size()
	gs._begin_turn(0)
	check(gs.pending_choice.get("type") == "native-divination" and gs.pending_choice.zoneOwner == 1 and p.units[1].front == 1 and p.deck.size() == count_before, "turn-start enemy divination pauses before retreat and normal draw")
	finish(gs)
	check(p.units[1].front == 0 and p.deck.size() == count_before - 1, "completing turn-start choice resumes retreat then actual normal draw")

func crab_rules() -> void:
	var gs := game(); var p: Dictionary = gs.player(0); var foe: Dictionary = gs.player(1)
	var h := give(gs, "c21001")
	check(not gs.can_play_card(0, h).ok, "sleep rejects hand with no other crab card")
	var selected := give(gs, "c21005"); var iid := str(p.hand[selected].instanceId); p.hand[selected].testMarker = "preserved"
	var deck_size: int = p.deck.size()
	check(gs.play_card(0, h), "sleep opens actual held crab choice")
	check(gs.pending_choice.get("type") == "crab-sleep" and gs.pending_choice.instanceIds == [iid], "sleep only offers remaining actual crab hand")
	check(not gs.resolve_divination_choice(0, "missing"), "copy choice rejects foreign instance")
	check(gs.resolve_divination_choice(0, iid) and p.deck.size() == deck_size + 2, "copies3 then draws1 from shuffled real deck")
	var copies: Array = p.deck.filter(func(i): return i.get("testMarker") == "preserved") + p.hand.filter(func(i): return i.get("testMarker") == "preserved")
	var unique := {}
	for inst in copies: unique[str(inst.instanceId)] = true
	check(copies.size() == 4 and unique.size() == 4 and p.hand.any(func(i): return str(i.instanceId) == iid), "copy preserves original and metadata, creates3 independent identities")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	h = give(gs, "c21002"); check(gs.hand_card_def(0, h).value == 1 and not gs._kw(gs.hand_card_def(0, h), "instant"), "first claw uses printed1/1 and no false instant")
	check(gs.play_card(0, h) and foe.avatarHp == 27 and p.units[1].shield == 1, "first actual claw grants armor before attack")
	h = give(gs, "c21002"); var enhanced: Dictionary = gs.hand_card_def(0, h)
	check(enhanced.value == 3 and enhanced.combatOption.shield == 2 and gs._kw(enhanced, "instant"), "next claw grows exact2/1 and same-name instant")
	check(gs.play_card(0, h) and foe.avatarHp == 22 and p.energy == 29 and gs.kw_usage(0, "instant").used, "second claw uses shared instant without extra fire")
	gs = game(); p = gs.player(0)
	deck_size = p.deck.size(); play(gs, "c21003")
	check(p.deck.size() == deck_size - 1 and p.energy == 29, "first feast draws1 and costs normal fire")
	play(gs, "c21003"); check(p.deck.size() == deck_size - 3 and p.energy == 29, "second feast draws2 with shared instant")
	gs = game(); p = gs.player(0)
	play(gs, "c21004"); check(p.units[1].attack == 6 and p.units[1].maxHp == 6 and gs.VerifiedRules.Combat.has(p.units[1], "veil"), "growing form sets6/6 with real veil")
	play(gs, "c21004"); check(p.units[1].attack == 8 and p.units[1].maxHp == 8, "same-name body grows2/2 before installation")
	h = give(gs, "c21004")
	check(gs.hand_card_def(0, h).currentCardStats == "当前面板 10/10", "original form face receives live next-use body preview")
	check(AI._best_card(gs, 0).ok, "AI can reuse growing form for a strictly stronger body")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c21005", "avatar-1"); var hp_before := total_hp(gs, 1)
	play(gs, "c21005", "avatar-1")
	check(hp_before - total_hp(gs, 1) == 6, "second hammer deals chosen4 then one random2, no invented draw")
	gs = game(); p = gs.player(0)
	play(gs, "c19604", p.units[1].uid); give(gs, "c19604"); give(gs, "c21005")
	var held: int = p.hand.size(); var deck_before: int = p.deck.size()
	play(gs, "c21007")
	check(p.units[1].awakened and p.units[1].attack == 4 and p.units[1].maxHp == 8 and p.hand.size() == held + 1 and p.deck.size() == deck_before, "awakening copies actual random hand instead of drawing")
	var other: int = p.hand.find_custom(func(i): return i.definitionId == "c19604")
	check(gs._kw(gs.hand_card_def(0, other), "instant"), "awakened crab grants same-name instant to ally cards used earlier")
	gs._knockout_unit(p.units[1]); check(not gs._kw(gs.hand_card_def(0, other), "instant"), "knocked crab cannot provide allied instant aura")
	gs = game(); p = gs.player(0); give(gs, "c21005")
	play(gs, "c21006"); held = p.hand.size(); deck_before = p.deck.size()
	gs._trigger_realms(0); check(p.hand.size() == held and p.deck.size() == deck_before, "dream realm does not draw at owner start")
	check(gs.end_turn(0) and p.hand.size() == held + 1 and p.hand[0].definitionId == p.hand[1].definitionId and p.hand[0].instanceId != p.hand[1].instanceId, "end-turn realm produces distinct true hand copy")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c21008")
	h = give(gs, "c21005"); iid = str(p.hand[h].instanceId)
	check(gs.play_card(0, h, "avatar-1") and p.hand.size() == 1 and p.hand[0].instanceId == iid and p.hand[0].crabBounceSpent, "lord grants one bounce to newly held spell and returns original identity")
	check(not gs.hand_card_def(0, 0).crabReturn and p.units[1].get("crabAttackTurn", -1) != gs.turn_counter, "bounced instance loses ability and first use does not autoattack")
	hp_before = total_hp(gs, 1)
	check(gs.play_card(0, 0, "avatar-1"), "replay bounced hammer")
	check(p.hand.is_empty() and hp_before - total_hp(gs, 1) == 10 and p.units[1].crabAttackTurn == gs.turn_counter and not p.units[1].get("crabCombatImmune", false), "repeated use does4+random2+real4 attack once and clears immunity")
	hp_before = total_hp(gs, 1); play(gs, "c21005", "avatar-1")
	check(hp_before - total_hp(gs, 1) == 8, "third hammer adds2 random hits but no second lord attack same turn")
	var stamp := JSON.stringify(gs.snapshot())
	gs.hand_card_def(0, 0); gs.hand_card_def(0, 0)
	check(JSON.stringify(gs.snapshot()) == stamp, "dynamic instant and bounce queries never mutate game state")
	gs = game(); p = gs.player(0)
	h = give(gs, "c21005"); iid = str(p.hand[h].instanceId); play(gs, "c21008"); play(gs, "c21004")
	check(gs.play_card(0, 0, "avatar-1") and p.hand.any(func(i): return str(i.instanceId) == iid), "already-granted bounce survives leaving lord form")
	gs = game(); p = gs.player(0); foe = gs.player(1)
	play(gs, "c21008"); foe.units[1].front = 1; give(gs, "c10102", 1)
	gs._resolve_combat(0, 1, 0, false, false, false, false, null, false, {"immuneCombat":true,"crabImmuneAll":true})
	check(p.units[1].get("crabCombatImmune", false) and not gs.resolution_stack.is_empty(), "lord immunity persists while actual enemy response is pending")
	var health := int(p.units[1].hp)
	check(gs._damage_unit(0, 1, 3, 1, 1).damage == 0 and p.units[1].hp == health, "lord combat immunity also prevents noncombat damage during that combat")
	gs._resolve_resolution_stack(); finish(gs)
	check(not p.units[1].get("crabCombatImmune", false) and gs._damage_unit(0, 1, 1, 1, 1).damage == 1, "all-damage immunity ends after combat without leaking into later spells")
	gs = game(["yingcao", "yaodaoji", "shanfeng", "longyechaji"]); p = gs.player(0)
	play(gs, "c21008"); give(gs, "c10704", 1); health = int(p.units[1].hp)
	gs._resolve_combat(0, 1, 0, false, false, false, false, null, false, {"immuneCombat":true,"crabImmuneAll":true})
	check(p.units[1].get("crabCombatImmune", false) and gs._damage_unit(0, 1, 3, 1, 0).damage == 0, "immunity is already active before entering-front response resolves")
	gs._resolve_resolution_stack(); finish(gs)
	check(p.units[1].hp == health and gs.player(1).hand.is_empty(), "lord immunity covers enemy entering-front spell response from the start of attack hp=%d/%d held=%d" % [int(p.units[1].hp), health, gs.player(1).hand.size()])
	gs = game(); p = gs.player(0)
	for id in ["c19602", "c21005"]:
		gs = game(); give(gs, id)
		var chosen: Dictionary = AI._best_card(gs, 0)
		check(chosen.ok and gs.can_play_card(0, chosen.hand, chosen.target).ok and gs.play_card(0, chosen.hand, chosen.target), "AI legally chooses native damage " + id)
		finish(gs)

func run() -> void:
	eye_rules(); crab_rules()
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty(): out = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for size in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = size
		if not out.is_empty(): DisplayServer.window_set_size(size)
		await _ui_case(size.x)
	Support.cleanup_audio(); await process_frame; Support.cleanup_stores(stores)
	print("EYE_CRAB checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)

func _ui_case(width: int) -> void:
	var b := Battle.new()
	b.setup(["baimugui", "xieji", "hetong", "banruo"], ["bingyong", "yaodaoji", "shanfeng", "longyechaji"], 196210)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	root.add_child(b); await create_timer(0.5).timeout
	b.gs.player(1).deck = [{"instanceId":"ui-enemy-wind", "definitionId":"c17502"},{"instanceId":"ui-enemy-blade", "definitionId":"c10101"}]
	hand(b, ["c19607"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.pending_choice.zoneOwner == 1 and choice_face(b, "c10101") != null, "mouse all-knowing displays actual enemy deck")
	await capture("%d-01-enemy-deck-divination" % width)
	await click(choice_face(b, "c10101")); await settled(b)
	await click(choice_face(b, Divination.TOP)); await settled(b)
	await click(choice_face(b, "c17502")); await settled(b)
	await click(choice_face(b, Divination.BOTTOM)); await settled(b)
	check(b.gs.pending_choice.is_empty() and b.gs.player(1).units[1].hp == 0, "mouse top/bottom choices resume real destruction")
	hand(b, ["c21001", "c21005"]); await settled(b); await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.pending_choice.get("type") == "crab-sleep" and choice_face(b, "c21005") != null and choice_face(b, "c21005")._original_card != null, "mouse sleep offers original full face of true hand instance")
	await capture("%d-02-crab-copy-choice" % width)
	await click(choice_face(b, "c21005")); await settled(b)
	check(b.gs.pending_choice.is_empty() and b.gs.player(0).hand.size() == 2, "mouse copy choice shuffles copies and draws real card")
	b.gs.player(0).deck.append({"instanceId":"ui-cursed", "definitionId":"c19602", "eyeCurses":1})
	b.gs._draw(0, 1); b.gs._resolve_resolution_stack(); b._refresh(); await settled(b)
	check(choice_face(b, "eye-curse-life") != null and choice_face(b, "eye-curse-lose") != null, "mouse curse presents four different real consequences")
	await capture("%d-03-four-curse-choices" % width)
	await click(choice_face(b, "eye-curse-life")); await settled(b)
	check(b.gs.player(0).maxAvatarHp == 8 and b.gs.pending_choice.is_empty(), "mouse curse choice changes real max hp and resumes")
	var p: Dictionary = b.gs.player(0)
	for idx in [1, 2, 3]: b.gs._knockout_unit(p.units[idx])
	var decoy: Dictionary = b.gs.VerifiedRules.NativeSummons.summon(b.gs,0,0,"eye-ui-front","普通召唤物",0,9,{"countsAsShikigami":false})
	p.deck.append({"instanceId":"ui-unit-curse","definitionId":"c19602","eyeCurses":1})
	b.gs._draw(0, 1); b.gs._resolve_resolution_stack(); b._refresh(); await settled(b)
	await click(choice_face(b, "eye-curse-units")); await settled(b)
	check(b.gs.pending_choice.is_empty() and p.units[0].hp == 0 and decoy.hp == 9 and b._unit_widget(str(decoy.uid)) != null, "mouse curse destroys the living shikigami but leaves the ordinary summon on the board")
	b.queue_free(); await process_frame
