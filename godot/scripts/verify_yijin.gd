extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YIJIN_FAIL ", msg)
func fixture() -> GS:
	var gs := GS.create(["yijin-zhentian", "yaoginshi", "fenghuanghuo", "qingxingdeng"], ["yaodaoji", "xuenv", "bingyong", "taohuayao"], 1232026)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "feather-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, id), target), "play " + id)
func _initialize() -> void:
	_countdown()
	_feathers()
	_combat()
	_transform()
	_response()
	_random_form()
	_ai()
	print("YIJIN checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _countdown() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	check(u.abilityCountdown.remaining == 1, "opening turn decrements 2 but does not give feather")
	check(gs.end_turn(0) and gs.end_turn(1), "turn cycle")
	check(gs.player(0).hand.filter(func(i): return i.definitionId == "huangjinyu").size() == 1, "2 countdown gives exactly one feather")
	check(u.abilityCountdown.remaining == 2, "ability resets after trigger")
	gs.player(0).hand.clear()
	play(gs, "c12308")
	check(u.attack == 3 and u.maxHp == 6 and u.abilityCountdown.reset == 1 and gs.player(0).hand.is_empty(), "awakening adds stats and changes timer without fabricated immediate token")
	gs._knockout_unit(u)
	gs._begin_turn(0)
	check(gs.player(0).hand.filter(func(i): return i.definitionId == "huangjinyu").is_empty(), "dead countdown does not produce feathers")
	gs._begin_turn(0)
	check(u.hp == 6 and gs.player(0).hand.filter(func(i): return i.definitionId == "huangjinyu").size() == 1, "natural revival same turn ticks awakened ability")
func _feathers() -> void:
	var gs := fixture()
	play(gs, "c12302")
	check(gs.player(0).hand.size() == 2 and gs.player(0).energy == 39, "generate two independent feather instances")
	check(gs.hand_card_def(0, 0).target == "auto", "unawakened token attacks avatar without unit choice")
	check(not gs.play_card(0, 0, gs.player(1).units[0].uid), "unawakened unit target rejected")
	check(gs.play_card(0, 0), "first feather")
	check(gs.player(1).avatarHp == 28 and gs.player(0).energy == 39 and gs.kw_usage(0, "instant").used, "first feather instant is free")
	check(gs.play_card(0, 0), "second feather")
	check(gs.player(1).avatarHp == 26 and gs.player(0).energy == 38 and gs.player(0).feathersPlayed == 2, "second feather costs one and history counts uses")
	gs = fixture()
	var h := give(gs, "huangjinyu")
	play(gs, "c12308")
	check(gs.valid_targets(0, gs.hand_card_def(0, h)).size() == 5, "awakening affects previously created token targets")
	check(gs.play_card(0, h, gs.player(1).units[1].uid), "feather targets enemy reserve")
	check(gs.player(1).units[1].hp == 3 and gs.player(1).avatarHp == 30, "directed token only damages selected unit")
	check(not gs.valid_targets(0, gs.hand_card_def(0, give(gs, "huangjinyu"))).has(gs.player(0).units[0].uid), "no friendly targets")
func _combat() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	play(gs, "c12303")
	check(e.avatarHp == 28 and p.energy == 39, "goldwind has zero printed bonus and costs one before feather")
	play(gs, "huangjinyu")
	p.energy = 0
	play(gs, "c12303")
	check(e.avatarHp == 24 and p.energy == 0, "goldwind always free after feather even with instant spent")
	var i := give(gs, "c12309")
	check(gs.hand_card_def(0, i).value == 1 and gs.hand_card_def(0, i).combatOption.shield == 1, "dance printed zero bonus enhanced by real count")
	p.energy = 40
	check(gs.play_card(0, i), "enhanced dance")
	check(e.avatarHp == 21 and p.units[0].shield == 1, "enhanced combat damage and armor")
	for prior in [false, true]:
		gs = fixture()
		p = gs.player(0)
		e = gs.player(1)
		if prior: play(gs, "huangjinyu")
		play(gs, "c12304")
		e.units[0].front = 1
		e.units[0].hp = 20
		e.units[0].attack = 3
		gs.basic_attack(0, 0)
		check(p.units[0].hp == (6 if prior else 3), "immunity condition includes feather played before form")
	gs = fixture()
	play(gs, "c12304")
	play(gs, "huangjinyu")
	check(gs._damage_unit(0, 0, 2, 1, 0).damage == 2, "immunity does not block spell damage")
	gs.end_turn(0)
	check(not gs.VerifiedRules.Yijin.immune(gs, 0, gs.player(0).units[0]), "immunity expires at actual turn boundary")
func _transform() -> void:
	var gs := fixture()
	play(gs, "c12305")
	check(gs.pending_choice.is_empty() and gs.player(1).avatarHp == 25, "no previous feather gives plain 3/3 combat only")
	gs = fixture()
	play(gs, "huangjinyu")
	give(gs, "huangjinyu")
	give(gs, "huangjinyu")
	var second: String = gs.player(0).hand[1].instanceId
	play(gs, "c12305")
	check(gs.phase == "choice" and gs.pending_choice.instanceIds.size() == 2 and gs.player(1).avatarHp == 28, "transformation pauses before combat")
	check(not gs.resolve_divination_choice(1, second) and not gs.resolve_divination_choice(0, "bad"), "choice enforces owner and displayed instances")
	var saved = JSON.parse_string(JSON.stringify({"players": gs.players, "choice": gs.pending_choice, "stack": gs.resolution_stack}))
	gs.players = saved.players
	gs.pending_choice = saved.choice
	gs.resolution_stack = saved.stack
	check(gs.resolve_divination_choice(0, second), "choice survives JSON roundtrip")
	check(gs.player(0).hand[0].definitionId == "huangjinyu" and gs.player(0).hand[1].definitionId == "c12303", "only selected feather transforms without creating third card")
	check(gs.player(1).avatarHp == 23 and gs.player(0).units[0].shield == 3, "combat resumes once with printed 3/3")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, 1)) == 0, "transformed goldwind gets same turn free cost")
func _response() -> void:
	var gs := fixture()
	give(gs, "huangjinyu")
	give(gs, "c12309")
	give(gs, "c12801")
	play(gs, "c12307")
	check(gs.player(0).hand.size() == 3 and gs.player(0).hand[0].definitionId == "c12801", "replace exactly own exclusive cards, retaining teammate card")
	for lethal in [false, true]:
		gs = fixture()
		gs.current_player = 1
		var u: Dictionary = gs.player(0).units[0]
		give(gs, "c12307")
		give(gs, "huangjinyu")
		gs.player(0).energy = 0
		gs._damage_unit(0, 0, 5 if lethal else 4, 1, 0)
		check(gs.player(0).hand.any(func(i): return i.definitionId == "c12307") == not lethal, "response triggers only when lethal")
		check((u.hp == 0) == lethal, "response draws rather than preventing death")
		if lethal: check(gs.kw_usage(0, "instant").used and gs.player(0).hand.size() == 1, "automatic response uses instant and draws discarded count excluding itself")
	gs = fixture()
	gs.current_player = 1
	give(gs, "c12307")
	give(gs, "huangjinyu")
	gs._knockout_unit(gs.player(0).units[0], 1, 0)
	check(gs.player(0).hand.size() == 1 and gs.player(0).units[0].hp == 0, "direct destruction triggers predeath response")
func _random_form() -> void:
	for skin in ["c12306", "skin-yijin-zhentian-93151"]:
		var gs := fixture()
		play(gs, skin)
		for u in gs.player(1).units: u.hp = 20
		play(gs, "huangjinyu")
		var total := 0
		for u in gs.player(1).units: total += 20 - int(u.hp)
		check(total == 4 and gs.player(1).avatarHp == 28, "modern wander hits twice not every enemy including skin")
		check(gs.rule_events.filter(func(ev): return ev.kind == "feather-random-hit").size() == 2, "two discrete random hit events")
	var gs := fixture()
	play(gs, "c12306")
	for i in 3: gs._knockout_unit(gs.player(1).units[i])
	gs.player(1).units[3].hp = 8
	play(gs, "huangjinyu")
	check(gs.player(1).units[3].hp == 4, "random hits may repeat surviving enemy")
func _ai() -> void:
	for seed in 4:
		var gs := GS.create(["yijin-zhentian", "xuenv", "xuetongzi", "qingxingdeng"], ["yaodaoji", "quanshen", "qingfangzhu", "caitongzi"], 7500 + seed)
		for i in 160:
			if gs.winner >= 0: break
			var before := gs.command_log.size()
			AI.take_turn(gs, gs.action_player())
			check(gs.winner >= 0 or gs.command_log.size() > before, "AI advances legal commands")
		check(gs.winner >= 0 and gs.pending_choice.is_empty(), "AI match completes without stuck choice")
