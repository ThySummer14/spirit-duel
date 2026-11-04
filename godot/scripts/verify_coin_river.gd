extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Coins := preload("res://scripts/iron_mouse_rules.gd")
const Divination := preload("res://scripts/native_divination_rules.gd")

func game(river: bool = false) -> GS:
	var gs := GS.create(["tieshu", "hetong", "yaodaoji", "huibishou"], ["bingyong", "hetong", "yingcao", "qingfangzhu"], 21221317)
	for p in gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
		p.units[1].level = 3 if river else 0
	return gs

func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"definitionId": id, "instanceId": "coin-river-%d" % gs.next_card_id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "actual play " + id)

func dice(gs, face: int) -> void:
	for seed in 100000:
		var value := (seed * 1664525 + 1013904223) & 0xffffffff
		if 1 + int(floor(float(value) / 4294967296.0 * 6)) == face:
			gs.rng_state = seed
			return
	check(false, "dice fixture exists")

func finish(gs) -> void:
	for i in 30:
		if gs.pending_choice.is_empty() and gs.response_window.is_empty(): return
		if not gs.pending_choice.is_empty(): check(AI._resolve_choice(gs, gs.action_player()), "AI resolves real choice")
		else: gs.pass_response(gs.action_player())
	check(false, "continuation finishes in bounded steps")

func arrange(gs, iid: String, placement: String) -> void:
	check(gs.resolve_divination_choice(0, iid), "choose actual divination instance " + iid)
	check(gs.resolve_divination_choice(0, placement), "choose divination destination")

func iron_rules() -> void:
	var initial := GS.create(["tieshu", "hetong", "yaodaoji", "huibishou"], ["bingyong", "yingcao", "yaodaoji", "qingfangzhu"], 21217)
	check(initial.player(0).hand.any(func(i): return i.definitionId == "xingyun-qianbi"), "initial activation grants real coin")
	var gs := game(); var p: Dictionary = gs.player(0)
	for u in p.units: u.level = 1
	p.levelUpUsed = false
	check(gs.level_up(0, 0) and p.hand.size() == 1 and p.hand[0].definitionId == "xingyun-qianbi", "normal upgrade generates coin")
	p.units[1].level = 0
	var iid := str(p.hand[0].instanceId); dice(gs, 6)
	check(gs.play_card(0, 0) and p.hand.size() == 1 and p.hand[0].instanceId == iid, "fortune success returns original instance")
	check(p.energy == 30 and gs.player(1).avatarHp == 30 and Coins.used(gs, 0) == 1, "coin has no invented damage/fire reward")
	dice(gs, 2); check(gs.play_card(0, 0) and p.hand.is_empty() and p.energy == 29, "failed later coin costs fire and does not return")
	gs = game(); p = gs.player(0)
	play(gs, "c21201")
	check(gs.player(1).avatarHp == 26 and p.hand.size() == 1 and p.units[0].shield == 1, "earn grants printed1/1 and generates only after avatar damage")
	gs = game(); p = gs.player(0); gs.player(1).units[0].front = 1
	play(gs, "c21201")
	check(p.hand.is_empty(), "earn does not generate coin for unit damage")
	gs = game(); p = gs.player(0); gs.player(1).units[0].front = 1
	play(gs, "c21202"); dice(gs, 2); play(gs, "xingyun-qianbi")
	check(gs.player(1).avatarHp == 27 and gs.player(1).units[0].hp == gs.player(1).units[0].maxHp and not p.attackUsed, "coin form launches real direct attack through occupied front")
	dice(gs, 2); play(gs, "xingyun-qianbi")
	check(gs.player(1).avatarHp == 27, "direct attack only once each actual turn")
	gs = game(); p = gs.player(0)
	var h := give(gs, "c21203")
	check(gs.hand_card_def(0, h).value == 0 and not gs.hand_card_def(0, h).combatOption.immuneCombat, "jingle unenhanced negative case")
	p.coinsUsed = 2; p.coinUsedTurn = gs.turn_counter
	check(gs.hand_card_def(0, h).value == 2 and gs.hand_card_def(0, h).combatOption.immuneCombat, "jingle reads real turn count")
	gs.player(1).units[0].front = 1
	check(gs.play_card(0, h) and p.units[0].hp == p.units[0].maxHp, "enhanced jingle prevents counterdamage")
	gs = game(); p = gs.player(0)
	h = give(gs, "c21205"); check(not gs.hand_card_def(0, h).combatOption.lethal, "fraud without coin is not lethal")
	p.coinsUsed = 1; p.coinUsedTurn = gs.turn_counter
	gs.player(1).units[0].front = 1; gs.player(1).units[0].maxHp = 20; gs.player(1).units[0].hp = 20
	check(gs.play_card(0, h) and gs.player(1).units[0].hp == 0, "fraud enhanced lethal destroys high-HP defender")
	gs = game(); p = gs.player(0)
	play(gs, "c21204"); give(gs, "xingyun-qianbi"); gs.current_player = 1; dice(gs, 2)
	var hit: Dictionary = gs._damage_unit(0, 0, 7, 1, 0)
	check(hit.damage == 0 and p.units[0].hp == 4 and p.hand.is_empty() and gs.kw_usage(0, "instant").used, "coin responds with real payment and prevents exactly current damage")
	check(gs._damage_unit(0, 0, 1, 1, 0).damage == 1, "coin response does not create lasting immunity")
	gs = game(); p = gs.player(0); play(gs, "c21204")
	dice(gs, 2); play(gs, "xingyun-qianbi"); gs.current_player = 1
	check(gs._damage_unit(0, 0, 1, 1, 0).damage == 1, "manual toss does not pre-arm a damage response")
	gs = game(); p = gs.player(0); play(gs, "c21204"); give(gs, "xingyun-qianbi")
	gs.current_player = 1; gs.kw_usage(0, "instant").used = true; p.energy = 0
	check(gs._damage_unit(0, 0, 1, 1, 0).damage == 1 and p.hand.size() == 1, "unpayable response cannot consume coin or prevent damage")
	gs = game(); p = gs.player(0); play(gs, "c21206"); dice(gs, 2); play(gs, "xingyun-qianbi")
	check(p.units[0].attack == 6 and p.units[0].maxHp == 6, "coin-use form grows real1/1")
	gs._knockout_unit(p.units[0]); check(p.units[0].attack == 3 and p.units[0].maxHp == 4, "coin growth and form clear on knockout")
	gs = game(); p = gs.player(0); play(gs, "c21208"); p.energy = 0
	var card: Dictionary = gs.hand_card_def(0, 0)
	check(card.coinFirstFree and gs.card_payment(0, card).cost == 0 and not gs.card_payment(0, card).usesInstant, "awakened first coin is independently free")
	p.units[2].formRules = {"alwaysSix": true}
	check(gs.play_card(0, 0) and not gs.kw_usage(0, "instant").used and p.units[0].attack == 5, "first coin preserves instant and grants temporary1 power")
	check(gs.play_card(0, 0) and gs.kw_usage(0, "instant").used, "second coin can use shared instant")
	check(not gs.can_play_card(0, 0).ok and gs.can_basic_attack(0, 0).ok, "later coin needs fire while awakened swift enables zero-fire attack")
	check(gs.basic_attack(0, 0) and not Coins.swift(gs, p.units[0]), "ordinary attack consumes coin-granted swift")
	gs.end_turn(0); check(p.units[0].attack == 4 and not p.units[0].has("coinTemporaryAttack"), "temporary awakened power expires at boundary")
	gs = game(); p = gs.player(0); p.units[2].formRules = {"alwaysSix": true}
	var original: Array = []
	for i in 4:
		give(gs, "xingyun-qianbi"); original.append(str(p.hand.back().instanceId))
	gs.player(1).units[0].front = 1; gs.player(1).units[0].hp = 3
	play(gs, "c21207")
	check(Coins.used(gs, 0) == 3 and p.hand.size() == 4 and p.hand.all(func(i): return str(i.instanceId) in original), "windfall uses up to three distinct original coins and preserves returned instances")
	check(p.energy == 29 and not gs.kw_usage(0, "instant").used and gs.player(1).units[0].hp == 0 and gs.player(1).avatarHp == 22, "windfall pays once and resolves three4-point projections against live front")
	check(gs.rule_events.filter(func(e): return e.kind == "coin-used").size() == 3, "forced uses trigger real coin-use events")

func river_rules() -> void:
	var gs := game(true); var p: Dictionary = gs.player(0)
	p.deck = [{"instanceId":"A","definitionId":"c21201"},{"instanceId":"B","definitionId":"c21306"},{"instanceId":"C","definitionId":"c21308"},{"instanceId":"D","definitionId":"c21301"}]
	play(gs, "c21301")
	check(gs.pending_choice.type == "native-divination" and p.hand.is_empty(), "peek pauses draw until full divination finishes")
	check(not gs.resolve_divination_choice(1, "B") and not gs.resolve_divination_choice(0, "A"), "divination rejects wrong player and cards outside inspected top")
	arrange(gs, "B", Divination.TOP); arrange(gs, "D", Divination.BOTTOM)
	gs.players = JSON.parse_string(JSON.stringify(gs.players)); gs.pending_choice = JSON.parse_string(JSON.stringify(gs.pending_choice)); gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack)); p = gs.player(0)
	arrange(gs, "C", Divination.TOP)
	check(gs.pending_choice.is_empty() and p.hand.size() == 1 and p.hand[0].instanceId == "B" and p.deck.map(func(i): return i.instanceId) == ["D","A","C"], "serialized choices preserve bottom/top order, original instances and draw-after order")
	gs = game(true); p = gs.player(0); play(gs, "c21303")
	gs.VerifiedRules.Divination.start(gs, 0, 1); arrange(gs, str(gs.pending_choice.instanceIds[0]), Divination.BOTTOM)
	check(gs.VerifiedRules.River.die_bonus(gs, 0) == 1, "carp form grants dice bonus only after completed divination")
	dice(gs, 3); check(gs.VerifiedRules.Light.roll(gs, 0, 4, 6, 1), "actual3 becomes4 and succeeds")
	gs._resolve_resolution_stack(); finish(gs)
	check(gs.VerifiedRules.River.die_bonus(gs, 0) == 2 and gs.VerifiedRules.River.total(gs, 0) == 4, "successful fortune triggers one divination and records modified die")
	dice(gs, 6); gs.VerifiedRules.Light.roll(gs, 0, 4, 6, 1); gs._resolve_resolution_stack()
	check(gs.kw_usage(0, "fortune").last.roll == 6 and gs.pending_choice.is_empty(), "dice cap6 and once-per-turn passive")
	gs.end_turn(0); check(gs.VerifiedRules.River.die_bonus(gs, 0) == 0, "carp bonus expires on turn boundary")
	gs = game(true); p = gs.player(0); dice(gs, 2)
	var target: Dictionary = gs.player(1).units[0]
	play(gs, "c21302", target.uid)
	check(target.armorBreak == 4 and target.hp == target.maxHp and gs.pending_choice.is_empty(), "failed water fortune leaves exactly4 armor break and no direct damage")
	gs = game(true); p = gs.player(0); dice(gs, 6); target = gs.player(1).units[0]
	play(gs, "c21302", target.uid); finish(gs)
	check(target.hp == target.maxHp - 5 and target.armorBreak == 0, "successful water deals1 and explodes4 break")
	gs = game(true); p = gs.player(0); play(gs, "c21305")
	var hand_size: int = p.hand.size(); dice(gs, 6); gs.VerifiedRules.Light.roll(gs, 0, 4, 6, 1); gs._resolve_resolution_stack()
	check(gs.pending_choice.type == "native-divination" and p.hand.size() == hand_size, "awakening waits for real divination before draw")
	finish(gs); check(p.hand.size() == hand_size + 1 and p.units[1].attack == 3 and p.units[1].maxHp == 7, "awakened reward draws once and printed1/1 applied")
	gs.current_player = 1; gs.turn_counter += 1; dice(gs, 6); gs.VerifiedRules.Light.roll(gs, 0, 4, 6, 1); gs._resolve_resolution_stack()
	check(gs.pending_choice.is_empty() and p.hand.size() == hand_size + 1, "enemy-turn fortune does not trigger own-turn river passive")
	gs = game(true); p = gs.player(0); p.deck = [{"instanceId":"song-top","definitionId":"c21308"}]
	play(gs, "c21306")
	check(p.deck.size() == 1 and p.deck[0].instanceId == "song-top" and gs.player(1).units.all(func(u): return int(u.hp) == int(u.maxHp)-3), "song reveals without drawing and uses actual top-card level for every enemy")
	check(gs.rule_events.any(func(e): return e.kind == "river-top-revealed" and e.card.id == "c21308"), "song exposes actual revealed card")
	gs = game(true); p = gs.player(0); play(gs, "c21304"); p.avatarHp = 20; gs.player(1).units[0].front = 1; dice(gs, 6)
	check(gs.basic_attack(0, 1) and not gs.pending_choice.is_empty() and gs.player(1).units[0].hp == gs.player(1).units[0].maxHp, "attack waits for fortune-triggered player choice before damage")
	finish(gs); check(p.avatarHp == 24, "summer successful attack lifesteals actual4 damage")
	gs = game(true); p = gs.player(0); gs.player(1).avatarHp = 20
	gs._install_form(1, 1, Content.card_def("c21304")); gs.player(1).units[1].front = 1; dice(gs, 6)
	gs.basic_attack(0, 0)
	check(gs.player(1).avatarHp == 24, "summer also grants lifesteal to defender counterdamage")
	gs = game(true); p = gs.player(0); var h := give(gs, "c21308")
	for count in [49, 50, 99, 100]:
		p.fortuneRollTotal = count
		var view: Dictionary = gs.hand_card_def(0, h)
		check(view.value.attack == (16 if count >= 100 else 12 if count >= 50 else 8) and ("pierce" in view.formRules.combatKeywords) == (count >= 100), "threshold body and pierce at " + str(count))
	check(gs.play_card(0, h) and p.units[1].attack == 16 and p.units[1].maxHp == 16, "threshold form sets exact body")
	gs._damage_unit(0, 1, 99, 1, 0)
	check(p.units[1].hp == 1 and not p.units[1].formRules.riverUnyielding, "threshold form unyielding consumes once")
	gs._damage_unit(0, 1, 2, 1, 0); check(p.units[1].hp == 0 and p.units[1].form.is_empty(), "next damage kills and removes threshold form")
	gs = game(true); p = gs.player(0); play(gs, "c21307"); dice(gs, 2)
	check(p.realms.size() == 1 and p.realms[0].hp == 5, "turbulence installs true5 durability realm")
	gs.basic_attack(0, 0); finish(gs)
	check(gs.rule_events.any(func(e): return e.kind == "river-redirect"), "failed turbulence judgment redirects real combat")
	var count_before := gs.VerifiedRules.River.total(gs, 0)
	gs.VerifiedRules.Huang.destroy(gs, 0, p.realms[0], "检查移除"); p.attackUsed = false
	gs.basic_attack(0, 0); finish(gs)
	check(gs.VerifiedRules.River.total(gs, 0) == count_before, "destroyed realm no longer rolls or redirects")
	gs = game(true); p = gs.player(0); give(gs, "c21302")
	var candidate: Dictionary = AI._best_card(gs, 0)
	check(candidate.ok and gs._unit_index_by_uid(1, candidate.target) >= 0 and gs.can_play_card(0, candidate.hand, candidate.target).ok, "AI chooses legal enemy water target")
	gs = game(); give(gs, "xingyun-qianbi")
	check(not AI._best_card(gs, 0).ok, "AI saves bare coins without a payoff")
	gs.player(0).units[0].awakened = true
	check(AI._best_card(gs, 0).ok, "AI uses awakened coin payoff")

func run() -> void:
	iron_rules(); river_rules()
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme(); root.size = Vector2i(1600, 740)
	var b := Battle.new()
	b.setup(["tieshu", "hetong", "yaodaoji", "huibishou"], ["bingyong", "hetong", "yingcao", "qingfangzhu"], 212213)
	b._ai_thinking = true
	for p in b.gs.players:
		p.hand.clear(); p.energy = 30; p.levelUpUsed = true
		for u in p.units: u.level = 3
		p.units[1].level = 0
	root.add_child(b); await create_timer(0.5).timeout
	hand(b, ["c21208"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.player(0).units[0].awakened and b.gs.player(0).hand[0].definitionId == "xingyun-qianbi", "real mouse awakens and receives coin")
	check(b._hand_row.get_child(0).data.payment.coinFirstFree and b._hand_row.get_child(0).data.text.contains("首枚钱币"), "free coin payment explanation shown on rendered card")
	b.gs.player(0).units[2].formRules = {"alwaysSix": true}
	await click(b._hand_row.get_child(0)); await settled(b)
	check(Coins.used(b.gs, 0) == 1 and b._hand_row.get_child(0).play_aura_kind() == "instant", "real toss returns original coin and next instant shows blue aura")
	await capture("01-coin-payment-and-return")
	b.gs.player(0).units[1].level = 3; hand(b, ["c21301"]); await settled(b)
	await click(b._hand_row.get_child(0)); await settled(b)
	check(b.gs.pending_choice.get("type") == "native-divination" and is_instance_valid(b._choice_layer), "real mouse opens full divination UI")
	var selected := str(b.gs.pending_choice.instanceIds[0])
	var face := choice_face(b)
	check(face != null, "actual top-deck cards are shown")
	if face != null: await click(face)
	await settled(b)
	check(choice_face(b, Divination.BOTTOM) != null and choice_face(b, Divination.TOP) != null and choice_face(b, Divination.BOTTOM).data.name == "置于牌库底" and choice_face(b, Divination.TOP).data.name == "置于牌库顶", "both top and bottom destinations visible as rendered card controls")
	await capture("02-divination-top-bottom")
	face = choice_face(b, Divination.BOTTOM)
	if face != null: await click(face)
	await settled(b)
	check(selected in b.gs.pending_choice.bottom and b.gs.pending_choice.remaining.size() == 2, "mouse bottom choice preserves remaining ordering decisions")
	finish(b.gs); b._refresh(); await settled(b)
	check(b.gs.pending_choice.is_empty() and b.gs.player(0).hand.size() == 1, "remaining choices resume original draw")
	b.queue_free(); Support.cleanup_audio(); await process_frame; Support.cleanup_stores(stores)
	print("COIN_RIVER checks=%d failures=%d" % [checks, failures]); quit(0 if failures == 0 else 1)
