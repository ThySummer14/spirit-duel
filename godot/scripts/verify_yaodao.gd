extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Yaodao := preload("res://scripts/yaodao_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YAODAO_FAIL ", message)

func fixture(seed_value: int = 10109) -> GS:
	var gs := GS.create(["yaodaoji", "yingcao", "basalt", "yaoginshi"], ["yaodaoji", "yingcao", "basalt", "yaoginshi"], seed_value)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs

func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId": "yaodao-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, id: String, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, owner, id)), "play " + id)

func events(gs: GS, kind: String) -> Array:
	return gs.rule_events.filter(func(event): return event.kind == kind)

func _initialize() -> void:
	_content()
	_flurry()
	_awaken()
	_kills_draw()
	_combat_cards()
	_extra_hits()
	_responses()
	_generation()
	_ai()
	check(checks >= 120, "all rule groups ran to completion")
	print("YAODAO checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("YAODAO_OK")
	quit(0 if failures == 0 else 1)

func _content() -> void:
	for id in ["c10101", "c10102", "c10103", "c10104", "c10105", "c10106", "c10107", "c10108", "skin-yaodaoji-93149", "yingdao-jianqie", "yingdao-zhanyi", "yingdao-yishan"]:
		var card := ContentLoader.card_def(id)
		check(card.get("verifiedRules", false), id + " uses reviewed executable rules")
		check(not "简化" in str(card.text), id + " has no approximate effect text")
	check(ContentLoader.card_def("c10107").type == "spell", "awakening is a spell")
	check(not ContentLoader.card_def("c10107").keywords.has("instant"), "awakening has no invented instant keyword")
	check(ContentLoader.card_def("c10105").value.setBase, "form replaces base body")
	check(not ContentLoader.card_def("c10105").get("verificationPending", []).is_empty() and not ContentLoader.card_def("skin-yaodaoji-93149").get("verificationPending", []).is_empty(), "double-myriad ordering remains explicitly pending")
	check(ContentLoader.card_def("c10101").combatOption.yaodaoKillDraw, "2020-12-24 kill draw supersedes stale avatar draw")

func _flurry() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	check(gs.basic_attack(0, 0), "ordinary attack starts flurry")
	check(gs.player(1).avatarHp == 27, "basic attack damages avatar once")
	var idx := give(gs, 0, "c10101")
	check(gs.hand_card_def(0, idx).keywords.has("instant"), "avatar hit grants dynamic instant")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0, "first dynamic instant is free")
	var deck: int = p.deck.size()
	check(gs.play_card(0, idx), "use first instant")
	check(p.energy == 39 and gs.kw_usage(0, "instant").used, "instant consumes shared allowance only")
	check(p.deck.size() == deck, "hitting avatar with modern ominous blade does not draw")
	play(gs, "c10102")
	check(p.energy == 38, "second instant costs one")
	check(not ContentLoader.card_def("c10102").keywords.has("instant"), "dynamic keyword never mutates catalog")
	gs = fixture()
	gs.player(1).avatarArmor = 20
	check(gs.basic_attack(0, 0), "attack fully armored avatar")
	check(not gs.hand_card_def(0, give(gs, 0, "c10103")).keywords.has("instant"), "zero actual avatar damage does not grant instant")
	gs = fixture()
	gs.player(1).units[2].front = 1
	check(gs.basic_attack(0, 0), "attack unit instead of avatar")
	check(not gs.hand_card_def(0, give(gs, 0, "c10103")).keywords.has("instant"), "unit combat alone is not the old beta flurry")
	gs = fixture()
	check(gs.basic_attack(0, 2), "teammate attacks avatar")
	check(not gs.hand_card_def(0, give(gs, 0, "c10103")).keywords.has("instant"), "teammate avatar hit cannot trigger yaodao")
	gs = fixture()
	play(gs, "c10702")
	check(gs.basic_attack(0, 0), "yaodao face hit after firefly form")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, give(gs, 0, "c10103"))) == 1, "firefly and yaodao share instant usage")
	gs = fixture()
	check(gs.basic_attack(0, 0), "face hit before natural zero card")
	play(gs, "c10104")
	check(gs.kw_usage(0, "instant").used, "original guide: zero-fire flash after face hit wastes instant")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, give(gs, 0, "c10103"))) == 1, "flash consumed first granted instant")
	gs = fixture()
	play(gs, "c10104")
	check(not gs.kw_usage(0, "instant").used and gs.player(0).energy == 40, "flash before face hit is naturally free without spending instant")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, give(gs, 0, "c10103"))) == 0, "flash's own face damage unlocks subsequent instant")

func _awaken() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	play(gs, "c10107")
	check(p.energy == 39 and not gs.kw_usage(0, "instant").used, "awakening costs one fire and does not consume instant")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5, "printed awakening one power one health")
	p.energy = 0
	check(gs.can_basic_attack(0, 0).ok and gs.basic_attack(0, 0), "permanent swift permits zero-fire basic attack")
	check(p.energy == 0 and p.attackUsed, "swift still consumes global basic-attack allowance")
	check(not gs.can_basic_attack(0, 2).ok, "swift cannot create a second team basic attack")
	play(gs, "c10103")
	play(gs, "c10102")
	check(p.energy == 0 and not gs.kw_usage(0, "instant").used, "awakened face hit makes all later combat cards free without manufacturing instant")
	check(gs.effective_card_cost(0, ContentLoader.card_def("c10106")) == 1, "kill intent spell is never made free by awakened flurry")
	check(gs.effective_card_cost(0, ContentLoader.card_def("c10105")) == 1, "form is never made free by awakened flurry")
	check(gs.end_turn(0) and gs.end_turn(1), "advance to another owner turn")
	p.levelUpUsed = true
	p.energy = 0
	check(gs.can_basic_attack(0, 0).ok, "permanent swift is available next turn")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, give(gs, 0, "c10103"))) == 1, "previous turn's free combat discount expires")
	gs._knockout_unit(p.units[0])
	check(Yaodao.permanent_swift(p.units[0]), "awakening persists through knockout")
	p.units[0].hp = p.units[0].maxHp
	p.units[0].knockout = 0
	check(gs.can_basic_attack(0, 0).ok, "revived awakened source retains permanent swift")
	gs = fixture()
	play(gs, "c10107")
	play(gs, "c10107")
	check(gs.player(0).units[0].attack == 5 and gs.player(0).units[0].maxHp == 6, "repeated awakening stacks printed body without extra attack allowances")
	gs.player(1).units[2].front = 1
	check(gs.basic_attack(0, 0), "awake attack into living guard")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, give(gs, 0, "c10103"))) == 1, "awake unit combat does not give free cards without avatar damage")

func _kills_draw() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	e.units[0].front = 1
	e.units[0].hp = 2
	var deck: int = p.deck.size()
	play(gs, "c10101")
	check(p.deck.size() == deck - 1 and p.hand.size() == 1, "ominous blade draws exactly once when killing enemy shikigami")
	check(p.units[0].get("yaodaoKills", 0) == 1, "kill history records actual source")
	check(p.units[0].attack == 3, "kill does not invent permanent attack growth")
	check(gs.hand_card_def(0, give(gs, 0, "c10108")).value == 2, "newly obtained imprisoned blade sees entire match kill history")
	check(events(gs, "yaodao-kill-draw").size() == 1, "one completed combat creates one conditional draw event")
	gs = fixture()
	e = gs.player(1)
	e.units[2].front = 1
	deck = gs.player(0).deck.size()
	play(gs, "c10101")
	check(gs.player(0).deck.size() == deck, "surviving target does not grant draw")
	check(gs.player(0).units[0].get("yaodaoKills", 0) == 0, "nonlethal hit does not enhance blade")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	p.units[0].hp = 1
	e.units[0].hp = 1
	e.units[0].front = 1
	deck = p.deck.size()
	play(gs, "c10101")
	check(p.units[0].hp == 0 and e.units[0].hp == 0, "ordinary combat can mutually knock out")
	check(p.deck.size() == deck - 1, "source death does not erase earned kill draw")
	check(p.units[0].get("yaodaoKills", 0) == 1 and e.units[0].get("yaodaoKills", 0) == 1, "both ordinary combat hits retain killer attribution through mutual knockout")
	check(gs.hand_card_def(0, give(gs, 0, "c10108")).value == 2, "knockout does not clear match kill history")
	gs = fixture()
	e = gs.player(1)
	e.units[0].hp = 1
	e.units[0].front = 1
	check(gs.basic_attack(0, 2), "teammate kills opposing source")
	check(gs.hand_card_def(0, give(gs, 0, "c10108")).value == 0, "teammate kill cannot enhance yaodao blade")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	e.units[0].front = 1
	e.units[0].hp = 2
	e.units[0].barrier = true
	deck = p.deck.size()
	play(gs, "c10101")
	check(p.deck.size() == deck and int(e.units[0].hp) == 2, "barrier prevents the kill and draw")

func _combat_cards() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	play(gs, "c10103")
	check(gs.player(1).avatarHp == 25 and p.units[0].attack == 3, "battle intent grants five attack only during its battle")
	check(p.units[0].shield == 2 and p.units[0].shieldExpires == 2, "unspent combat armor survives its battle")
	play(gs, "c10104")
	check(gs.player(1).avatarHp == 22, "later flash does not inherit battle intent attack")
	check(p.units[0].shield == 2, "later battle does not discard remaining armor")
	check(gs.end_turn(0) and p.units[0].shield == 2, "armor remains on enemy turn")
	check(gs.end_turn(1) and p.units[0].shield == 0, "armor clears at next owner turn start")
	gs = fixture()
	gs.player(1).units[2].front = 1
	play(gs, "c10102")
	check(gs.player(0).units[0].hp == 4 and gs.player(1).units[2].hp == 8, "active sight-cut deals four and prevents retaliation")
	play(gs, "c10104")
	check(gs.player(0).units[0].hp < 4, "sight-cut immunity does not leak into later combat")
	gs = fixture()
	play(gs, "yingdao-jianqie")
	check(gs.player(0).units[0].shield == 1 and gs.player(0).hand.is_empty(), "legacy ominous alias retains armor and conditional draw")
	gs = fixture()
	play(gs, "yingdao-zhanyi")
	check(gs.player(1).avatarHp == 25 and gs.player(0).units[0].shield == 2, "legacy battle intent token has full attack and armor")
	gs = fixture()
	gs.player(0).energy = 0
	play(gs, "yingdao-yishan")
	check(gs.player(1).avatarHp == 27, "legacy flash stays a genuine zero-fire combat card")

func _extra_hits() -> void:
	var gs := fixture()
	play(gs, "c10105")
	var source: Dictionary = gs.player(0).units[0]
	check(source.attack == 3 and source.maxHp == 8, "myriad form is exactly three/eight")
	check(gs.basic_attack(0, 0), "myriad attacks open front")
	check(gs.player(1).avatarHp == 24, "myriad hits avatar twice")
	check(events(gs, "combat-complete").size() == 1, "two avatar hits complete one battle")
	check(events(gs, "yaodao-flurry").size() == 2, "myriad face hits remain distinct source-owned damage events")
	gs = fixture()
	play(gs, "c10105")
	var e: Dictionary = gs.player(1)
	e.units[0].front = 1
	e.units[0].hp = 3
	check(gs.basic_attack(0, 0), "myriad attacks three-health guard")
	check(e.units[0].hp == 0 and gs.player(0).units[0].hp == 8, "extra first hit kills before retaliation")
	check(e.avatarHp == 30, "first-hit kill does not redirect second swing to avatar")
	check(events(gs, "combat-complete").size() == 1, "early kill completes exactly one battle")
	check(gs.player(0).units[0].get("yaodaoKills", 0) == 1, "extra first-hit kill counted once")
	gs = fixture()
	play(gs, "c10105")
	e = gs.player(1)
	e.units[2].front = 1
	check(gs.basic_attack(0, 0), "myriad attacks durable guard")
	check(e.units[2].hp == 6, "durable target receives first hit plus normal hit")
	check(events(gs, "combat-complete").size() == 1, "first hit plus ordinary hit still complete one battle")
	check(gs.player(0).units[0].hp == 7, "durable target retaliates exactly once")
	gs = fixture()
	play(gs, "c10105")
	e = gs.player(1)
	e.units[2].front = 1
	e.units[2].barrier = true
	check(gs.basic_attack(0, 0), "myriad attacks barrier")
	check(not e.units[2].barrier and e.units[2].hp == 9, "first hit breaks barrier and normal hit deals damage")
	gs = fixture()
	play(gs, "skin-yaodaoji-93149")
	check(gs.player(0).units[0].attack == 3 and gs.player(0).units[0].maxHp == 8, "skin has identical form body")
	check(gs.basic_attack(0, 0) and gs.player(1).avatarHp == 24, "skin shares full extra-first-hit behavior")
	gs._knockout_unit(gs.player(0).units[0])
	check(gs.player(0).units[0].form.is_empty() and gs.player(0).units[0].formRules.is_empty(), "knockout removes myriad extra-hit form")
	gs = fixture()
	gs.current_player = 1
	play(gs, "c10105", 1)
	gs.current_player = 0
	gs.player(1).units[0].front = 1
	gs.player(0).units[0].hp = 3
	check(gs.basic_attack(0, 0), "attack defending myriad")
	check(gs.player(0).units[0].hp == 0 and gs.player(1).units[0].hp == 8, "defending myriad first hit can kill attacker before ordinary damage")
	check(gs.player(1).units[0].get("yaodaoKills", 0) == 1, "defending first-hit kill enhances defender's own blade")

func _responses() -> void:
	var gs := fixture()
	var e: Dictionary = gs.player(1)
	e.units[0].front = 1
	e.energy = 1
	give(gs, 1, "c10102")
	gs.player(0).units[2].front = 1
	check(gs.basic_attack(0, 2), "attack source with ready sight-cut response")
	check(e.energy == 0 and e.hand.is_empty(), "auto response consumes exactly one fire and card")
	check(e.units[0].hp == 4 and gs.player(0).units[2].hp == 8, "response boosts defense hit and blocks incoming combat")
	check(events(gs, "response-card").size() == 1, "one response event")
	check(gs.resolution_stack.is_empty(), "responding sight-cut resumes and completes original combat")
	check(not e.attackUsed and e.units[0].attack == 3, "response does not issue separate basic attack or leave permanent attack")
	gs.player(0).attackUsed = false
	check(gs.basic_attack(0, 2), "second battle after response")
	check(e.units[0].hp == 3, "response immunity expires at the end of its single battle")
	for blocked in ["no-fire", "dead", "stunned", "level-zero", "other-defender"]:
		gs = fixture()
		e = gs.player(1)
		e.units[0].front = 1
		e.energy = 1
		give(gs, 1, "c10102")
		match blocked:
			"no-fire": e.energy = 0
			"dead": e.units[0].hp = 0; e.units[0].front = 0; e.units[2].front = 1
			"stunned": e.units[0].frozen = 1
			"level-zero": e.units[0].level = 0
			"other-defender": e.units[0].front = 0; e.units[2].front = 1
		check(gs.basic_attack(0, 2), "attack with blocked response " + blocked)
		check(e.hand.size() == 1 and events(gs, "response-card").is_empty(), "response respects " + blocked)

func _generation() -> void:
	var seen := {}
	var repeated := false
	for seed_value in range(20):
		var gs := fixture(seed_value + 900)
		var deck: int = gs.player(0).deck.size()
		play(gs, "c10106")
		var generated: Array = gs.player(0).hand
		check(generated.size() == 3 and gs.player(0).deck.size() == deck, "kill intent generates three without tutoring deck")
		var sample := {}
		for inst in generated:
			seen[inst.definitionId] = true
			if sample.has(inst.definitionId): repeated = true
			sample[inst.definitionId] = true
			check(inst.definitionId in ["c10101", "c10102", "c10103", "c10104", "c10108"], "generation uses five complete canonical combat definitions")
	check(seen.size() == 5, "generation pool can produce all five combat cards")
	check(repeated, "explicit pending sampling model permits duplicates")
	var gs := fixture()
	for i in range(11): give(gs, 0, "c10105")
	play(gs, "c10106")
	check(gs.player(0).hand.size() == 12, "generated overflow burns without exceeding hand cap")
	gs = fixture()
	gs.player(0).units[0].level = 1
	check(not gs.can_play_card(0, give(gs, 0, "c10106")).ok, "kill intent requires source level three")
	gs.player(0).units[0].level = 3
	gs.player(0).units[0].hp = 0
	check(not gs.can_play_card(0, 0).ok, "dead source cannot use kill intent")

func _ai() -> void:
	var gs := fixture()
	gs.player(1).avatarHp = 5
	var card := ContentLoader.card_def("c10103")
	check(Yaodao.score_card(gs, 0, card, null) >= 1000, "AI recognizes exact battle-intent lethal")
	gs.player(1).units[2].front = 1
	gs.player(1).units[2].attack = 20
	check(Yaodao.score_card(gs, 0, ContentLoader.card_def("c10102"), null) > Yaodao.score_card(gs, 0, card, null), "AI prefers immunity against fatal retaliation")
	gs = fixture()
	gs.player(0).energy = 0
	check(not gs.can_play_card(0, give(gs, 0, "c10103")).ok, "AI legality rejects paid combat at zero fire")
	check(gs.can_play_card(0, give(gs, 0, "c10104")).ok, "AI legality accepts natural free flash at zero fire")
	check(AI.take_action(gs, 0), "real AI chooses legal zero-fire flash")
	check(gs.player(1).avatarHp == 27 and gs.player(0).hand.size() == 1, "AI does not spend unavailable fire on paid battle intent first")
	check(AI.take_action(gs, 0), "real AI follows flash with newly instant combat card")
	check(gs.player(1).avatarHp == 22 and gs.player(0).energy == 0, "AI uses actual temporary cost and exact battle damage")
	gs = fixture()
	play(gs, "c10107")
	gs.player(0).energy = 0
	give(gs, 0, "c10103")
	check(AI.take_action(gs, 0), "real AI finds permanent-swift attack with no legal paid card")
	check(gs.player(0).attackUsed and gs.player(1).avatarHp == 26, "AI swift is an ordinary attack with real source-owned damage")
	check(AI.take_action(gs, 0) and gs.player(1).avatarHp == 20, "AI then uses awakened free-combat effect")
