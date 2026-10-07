extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Firefly := preload("res://scripts/firefly_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FIREFLY_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["yingcao", "yimulian", "basalt", "yaodaoji"], ["yingcao", "yimulian", "basalt", "yaodaoji"], 10709)
	for owner in 2:
		var p := gs.player(owner)
		p.hand.clear()
		p.deck.clear()
		for i in 90: p.deck.append({"instanceId": "deck-%d-%d" % [owner, i], "definitionId": "c10701"})
		p.energy = 20
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs

func give(gs: GS, owner: int, id: String, enhanced: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "firefly-%d" % gs.next_card_id, "definitionId": id, "enhanceCount": enhanced})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, owner: int, id: String, target = null, enhanced: int = 0) -> void:
	check(gs.play_card(owner, give(gs, owner, id, enhanced), target), "legal play " + id)

func light(gs: GS, owner: int, id: String) -> void:
	var c := ContentLoader.card_def(id)
	gs._install_form(owner, 0, c, c.value)

func _initialize() -> void:
	var gs := fixture()
	for i in range(10701,10709): check(ContentLoader.card_def("c%d" % i).get("verifiedRules", false), "verified card %d" % i)
	check(gs.player(0).units[0].attack == 2 and gs.player(0).units[0].maxHp == 5, "printed base 2/5")
	var h := give(gs, 0, "c10702")
	check(gs._kw(gs.hand_card_def(0,h), "instant"), "base ability grants form instant")
	check(not gs._kw(ContentLoader.card_def("c10702"), "instant"), "aura never mutates catalogue")
	gs.player(0).energy = 0
	check(gs.can_play_card(0,h).ok, "first instant legal with zero fire")
	check(gs.play_card(0,h), "zero-fire heal form play")
	check(gs.player(0).hand.size() == 1 and gs.player(0).deck.size() == 89, "own form draws exactly once")
	check(gs.player(0).units[0].attack == 2 and gs.player(0).units[0].maxHp == 5, "heal form sets printed stats")
	h = give(gs,0,"c10703")
	check(gs.effective_card_cost(0,gs.hand_card_def(0,h)) == 1 and not gs.can_play_card(0,h).ok, "instant quota shared across forms")
	gs.player(0).energy = 4
	play(gs,0,"c10701",gs.player(1).units[2].uid)
	check(gs.player(0).deck.size() == 89, "non-form never triggers aura draw")
	check(int(int(gs.kw_usage(0,"encourage").get("shield",0))) == 2, "absorb queues armor encouragement")
	check(gs.player(0).units[0].shield == 0, "encourage is not source armor")

	gs = fixture()
	var p := gs.player(0)
	p.units[2].hp = 4
	p.units[3].hp = 0
	p.avatarHp = 18
	play(gs,0,"c10702")
	check(p.units[2].hp == 6 and p.units[3].hp == 0 and p.avatarHp == 18, "entry heal only living allied units")
	gs._begin_turn(0)
	check(p.units[2].hp == 8 and p.avatarHp == 18, "turn heal remains installed")
	p.levelUpUsed = true
	play(gs,0,"c10703")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 5, "courage printed stats no fake attack gain")
	check(int(gs.kw_usage(0,"encourage").get("attack",0)) == 2, "courage entry encouragement")
	gs._begin_turn(0)
	gs._begin_turn(0)
	check(int(gs.kw_usage(0,"encourage").get("attack",0)) == 6, "courage stacks without any expiry")
	p.levelUpUsed = true
	p.energy = 20
	gs.kw_usage(0,"instant").used = true
	play(gs,0,"c10705")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5, "soul form printed stats")
	check(p.energy == 20, "energy form refunds cost above legacy cap")
	gs._begin_turn(0)
	check(p.energy == 3 and int(gs.kw_usage(0,"encourage").get("attack",0)) == 6, "new form replaces old start ability")
	p.levelUpUsed = true
	p.units[2].attack = 1
	var hp: int = gs.player(1).avatarHp
	check(gs.basic_attack(0,2), "team member may consume encouragement")
	check(gs.player(1).avatarHp == hp - 7 and int(gs.kw_usage(0,"encourage").get("attack",0)) == 0, "next ordinary attack consumes stack once")

	gs = fixture()
	p = gs.player(0)
	play(gs,0,"c10703")
	play(gs,0,"c10101")
	check(int(gs.kw_usage(0,"encourage").get("attack",0)) == 2, "combat card does not consume ordinary-attack encouragement")
	gs = fixture()
	p = gs.player(0)
	play(gs,0,"c10707")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 7 and p.units[0].awakened, "awakening gains 2/2 and changes aura")
	check(p.energy == 20 and gs.kw_usage(0,"instant").used, "awakening printed instant consumes quota")
	h = give(gs,0,"c11801")
	check(gs._kw(gs.hand_card_def(0,h),"instant"), "awakened aura grants teammate form instant")
	var deck: int = p.deck.size()
	check(gs.play_card(0,h), "teammate form legal")
	check(p.deck.size() == deck - 1, "teammate form draws exactly one")
	play(gs,0,"c10707")
	check(p.units[0].attack == 6 and p.units[0].maxHp == 9, "second awakening grants printed stats again")
	gs._knockout_unit(p.units[0])
	h = give(gs,0,"c11801")
	check(not gs._kw(gs.hand_card_def(0,h),"instant"), "knocked-out aura absent from teammate")
	deck = p.deck.size()
	check(gs.play_card(0,h), "teammate may play without aura")
	check(p.deck.size() == deck, "knocked-out aura cannot draw")
	p.units[0].hp = p.units[0].maxHp
	p.units[0].knockout = 0
	h = give(gs,0,"c11801")
	check(gs._kw(gs.hand_card_def(0,h),"instant"), "revived awakening aura resumes")

	gs = fixture()
	p = gs.player(0)
	play(gs,0,"c10706")
	check(p.hand.map(func(c): return c.definitionId) == ["c10702","c10703","c10705"], "rainbow creates actual three forms")
	check(p.deck.size() == 90 and p.energy == 20, "rainbow generates without drawing and is instant")
	for id in ["yingcao-zhiyu","yingcao-yongqi","yingcao-anhun"]:
		var c := ContentLoader.card_def(id)
		check(c.get("formRules",{}).has("fireflyLight") and c.effects.size() == 2, "legacy token retains full ability " + id)
		var legacy := fixture()
		legacy.player(0).units[2].hp = 4
		play(legacy,0,id)
		check(legacy.player(0).deck.size() == 89, "legacy generated form uses aura " + id)
		if id == "yingcao-zhiyu": check(legacy.player(0).units[2].hp == 6, "legacy heal token executes entry recovery")
		elif id == "yingcao-yongqi": check(int(legacy.kw_usage(0,"encourage").get("attack",0)) == 2, "legacy courage token executes team encouragement")
		else: check(legacy.player(0).energy == 21, "legacy soul token executes entry fire")
	gs = fixture()
	for i in 10: give(gs,0,"c10701")
	play(gs,0,"c10706")
	check(gs.player(0).hand.size() == 12 and gs.player(0).deck.size() == 90, "rainbow respects hand cap without taking from deck")
	check(gs.player(0).hand.back().definitionId == "c10703", "rainbow overflow burns only later excess form")

	gs = fixture()
	p = gs.player(0)
	light(gs,0,"c10702")
	give(gs,0,"c10708")
	give(gs,0,"c10708",3)
	p.deck.back().definitionId = "c10708"
	gs._begin_turn(0)
	check(gs.hand_card_def(0,0).value == 2 and gs.hand_card_def(0,1).value == 5, "independent hand instances grow once")
	check(gs.hand_card_def(0,2).value == 1, "new turn draw does not retroactively enhance")
	check("已增强1次" in gs.hand_card_def(0,0).text, "hand description shows actual counter")
	gs._begin_turn(1)
	check(gs.hand_card_def(0,0).value == 2, "opponent start does not enhance own hand")
	p.units[0].form = {}
	gs._begin_turn(0)
	check(gs.hand_card_def(0,0).value == 2, "no form no enhancement")
	p.levelUpUsed = true
	p.energy = 20
	var own: Dictionary = p.units[2]
	own.hp = 4
	var maximum: int = own.maxHp
	check(gs.play_card(0,0,own.uid), "point ally branch legal")
	check(own.hp == 6 and own.maxHp == maximum + 2, "point increases maximum and current HP exactly once")
	var foe: Dictionary = gs.player(1).units[2]
	var enemyhp: int = foe.hp
	check(gs.play_card(0,0,foe.uid), "point enemy branch legal")
	check(foe.hp == enemyhp - 5, "point enemy branch deals enhanced damage")
	check(p.deck.size() == 88, "point never draws replacement card")
	h = give(gs,0,"c10708")
	check(not gs.can_play_card(0,h,"avatar-1").ok and not gs.can_play_card(0,h,"avatar-0").ok, "point excludes both avatars")
	foe.hp = 0
	check(not gs.can_play_card(0,h,foe.uid).ok, "point excludes knocked-out units")
	p.units[3].level = 0
	check(gs.can_play_card(0,h,p.units[3].uid).ok, "point may target living zero-level unit")
	gs._knockout_unit(own)
	check(own.maxHp == maximum and not own.has("fireflyTemporaryHealth"), "point plain health bonus ends on knockout")
	gs = fixture()
	p = gs.player(0)
	play(gs,0,"c10707")
	play(gs,0,"c10708",p.units[0].uid,3)
	check(p.units[0].maxHp == 11, "point health stacks separately from awakening")
	gs._knockout_unit(p.units[0])
	check(p.units[0].maxHp == 7 and p.units[0].awakened, "knockout preserves awakening but removes point health")

	gs = fixture()
	p = gs.player(0)
	play(gs,0,"c10701","avatar-0")
	check(p.avatarHp == 28 and int(gs.kw_usage(0,"encourage").get("shield",0)) == 2, "absorb can choose own avatar and still encourage")
	play(gs,0,"c10701","avatar-1")
	check(gs.player(1).avatarHp == 28, "absorb may target enemy avatar")
	p.nullifyNextCardTurn = gs.turn_counter
	var encouragement: int = int(gs.kw_usage(0,"encourage").get("shield",0))
	play(gs,0,"c10701",gs.player(1).units[2].uid)
	check(int(gs.kw_usage(0,"encourage").get("shield",0)) == encouragement, "nullified absorb grants no encourage")

	gs = fixture()
	p = gs.player(0)
	foe = gs.player(1).units[2]
	foe.front = 1
	h = give(gs,0,"c10704")
	check(gs.valid_targets(0,gs.hand_card_def(0,h)) == [foe.uid], "flash only targets opposing battle unit")
	check(not gs.can_play_card(0,h,gs.player(1).units[1].uid).ok, "flash rejects reserve")
	var atk: int = foe.attack
	check(gs.play_card(0,h,foe.uid), "flash manual play")
	check(foe.attack == 0 and foe.maxHp == 12, "flash changes attack without collateral stats")
	gs._grow_unit(foe,2,0)
	check(foe.attack == 2, "later attack gain is retained separately")
	check(gs.end_turn(0), "flash expiry reaches end of actual turn")
	check(foe.attack == atk + 2 and not foe.has("flashAppliedTurn"), "flash expiration restores underlying stats plus subsequent gain")

	for variant in ["normal","no-fire","frozen","low-level","source-ko","already-front"]:
		gs = fixture()
		p = gs.player(0)
		p.energy = 1
		give(gs,0,"c10704")
		gs.current_player = 1
		foe = gs.player(1).units[2]
		if variant == "no-fire": p.energy = 0
		if variant == "frozen": p.units[0].frozen = 1
		if variant == "low-level": p.units[0].level = 1
		if variant == "source-ko": gs._knockout_unit(p.units[0])
		if variant == "already-front": foe.front = 1
		check(gs.basic_attack(1,2), "incoming attack " + variant)
		if variant == "normal":
			check(p.avatarHp == 30 and p.hand.is_empty() and p.energy == 0, "flash stops original avatar attack and pays once")
			check(gs.command_log.filter(func(c): return c.c == "basic_attack").size() == 1, "response never creates second attack")
		else: check(p.avatarHp == 29 and p.hand.size() == 1, "illegal or absent trigger does not respond " + variant)

	gs = fixture()
	p = gs.player(0)
	p.units[2].front = 1
	give(gs,0,"c10704")
	gs.current_player = 1
	play(gs,1,"c10101")
	check(p.units[2].hp == 12, "flash response suppresses original combat-card bonus")
	check(gs.player(1).units[3].front == 1, "original attacker remains front after response")

	gs = fixture()
	p = gs.player(0)
	p.nullifyNextCardTurn = gs.turn_counter
	p.units[2].hp = 4
	play(gs,0,"c10702")
	check(p.hand.size() == 1 and p.deck.size() == 89, "form use aura draws before nullification")
	check(p.units[0].form.is_empty() and p.units[2].hp == 4, "nullified form neither enters nor heals")
	check(gs.kw_usage(0,"instant").used, "nullified instant still consumes free allowance")

	gs = fixture()
	p = gs.player(0)
	foe = gs.player(1).units[2]
	foe.front = 1
	atk = int(foe.attack)
	play(gs,0,"c10704",foe.uid)
	gs._knockout_unit(foe)
	check(foe.attack == atk and not foe.has("flashAppliedTurn"), "knockout removes flash without retaining subtraction")
	foe.hp = foe.maxHp
	foe.knockout = 0
	check(gs.end_turn(0), "turn ends after flashed unit revival")
	check(foe.attack == atk, "revival and expiry never restore flash twice")

	gs = fixture()
	p = gs.player(0)
	gs.current_player = 1
	give(gs,0,"c10704")
	foe = gs.player(1).units[2]
	gs.VerifiedRules.move_unit(gs,1,foe)
	gs._resolve_resolution_stack()
	check(foe.front == 1 and foe.attack == 0 and p.hand.is_empty(), "non-attack move into battle also triggers flash")
	check(p.avatarHp == 30 and gs.player(1).avatarHp == 30, "movement response invents no battle damage")

	gs = fixture()
	give(gs,0,"c10701")
	var absorb_choice := AI._best_card(gs,0)
	check(absorb_choice.ok and gs._unit_index_by_uid(0,absorb_choice.target) < 0 and str(absorb_choice.target) != "avatar-0", "AI avoids own side for absorb")

	gs = fixture()
	give(gs,0,"c10708",5)
	for unit in gs.player(1).units:
		unit.hp = 10
		unit.maxHp = 10
	gs.player(1).units[2].hp = 6
	var best := AI._best_card(gs,0)
	check(best.ok and best.target == gs.player(1).units[2].uid, "AI chooses lethal enemy branch")
	check(gs.can_play_card(0,best.hand,best.target).ok, "AI enhanced target is legal")
	print("FIREFLY checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("FIREFLY_OK")
	quit(0 if failures == 0 else 1)
