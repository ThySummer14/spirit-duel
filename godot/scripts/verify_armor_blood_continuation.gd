extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARMOR_BLOOD_CONTINUATION_FAIL ", detail)
func fixture() -> GS:
	var gs := GS.create(["qingxingdeng","zuofutongzi","xixueji","jiuciliang"],["yaodaoji","bingyong","yingcao","shantong"],20261015)
	for p in gs.players:
		p.hand.clear(); p.energy = 40; p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	return gs
func give(gs: GS, id: String) -> int:
	gs.player(0).hand.append({"instanceId":"armor-blood-more-%d" % gs.next_card_id,"definitionId":id})
	gs.next_card_id += 1
	return gs.player(0).hand.size()-1
func play(gs: GS, id: String, target: Variant = null) -> bool:
	return gs.play_card(0,give(gs,id),target)
func dice(gs: GS, first: int, second: int) -> void:
	for seed in 100000:
		var a := (seed * 1664525 + 1013904223) & 0xffffffff
		var b := (a * 1664525 + 1013904223) & 0xffffffff
		if 1 + int(floor(float(a) / 4294967296.0 * 6)) == first and 1 + int(floor(float(b) / 4294967296.0 * 6)) == second:
			gs.rng_state = seed
			return
	check(false,"dice fixture exists")
func _initialize() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	check(play(gs,"c12905"),"2022 lantern form")
	e.units[0].front = 1; e.units[0].shield = 100
	gs.basic_attack(0,0)
	check(p.hand.size() == 1 and p.hand[0].definitionId == "mingdeng" and e.avatarHp == 30,"lantern now triggers on attack against unit even when fully armored")
	check(gs.rule_events.filter(func(x):return x.kind == "lantern-created").size() == 1,"attack creates one token, combat damage does not duplicate it")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.energy = 3
	check(play(gs,"c12907"),"2022 drain")
	check(e.avatarHp == 15 and p.energy == 0,"three projections each deal official5 and then clear ghost fire")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	dice(gs,6,6)
	check(play(gs,"c13001"),"2022 gold entry")
	check(p.hand.size() == 1 and e.hand.size() == 1,"gold entry makes both independent successful draws")
	check(gs.VerifiedRules.Light.fortune_total(gs) == 2,"entry judgments count toward real fortune history")
	dice(gs,6,6)
	gs.VerifiedRules.Light.form_turn_start(gs,0,1)
	check(p.hand.size() == 2 and e.hand.size() == 2,"gold turn start retains same effect in addition to entry")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	dice(gs,2,2)
	check(play(gs,"c13001"),"gold failing entry")
	check(p.hand.is_empty() and e.hand.is_empty(),"failed entry cannot invent unconditional draw")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 20; e.avatarHp = 20
	give(gs,"c17303")
	dice(gs,6,6)
	check(play(gs,"c13002"),"2022 harvest entry")
	check(p.avatarHp == 23 and e.avatarHp == 23,"harvest entry restores3 to each avatar on success")
	check(p.units[2].attack == 4 and p.units[2].shield == 1,"harvest triggers one friendly vampire growth rather than team heal")
	check(gs.hand_card_def(0,0).value == 3,"two avatar healing events enhance held blood rage twice")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 20; e.avatarHp = 20
	dice(gs,2,2)
	check(play(gs,"c13002"),"harvest failing entry")
	check(p.avatarHp == 20 and e.avatarHp == 20,"failed harvest causes no healing or growth")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 4; p.fortuneSuccesses = 11
	check(play(gs,"c13008") and p.avatarHp == 4,"fortune reset inactive at11")
	p.fortuneSuccesses = 12
	p.avatarHealingBlocked = true
	check(AI._score_card(gs,0,Content.card_def("c13008"),null) > 0,"AI recognizes current12 threshold")
	check(play(gs,"c13008") and p.avatarHp == 30 and p.hand.size() == 10,"fortune reset active at12 and follows20230629 removal of poison healing block")
	check(p.units[2].attack == 3 and p.units[2].shield == 0,"setting life never fabricates a recovery event")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	p.avatarHp = 10
	var i := give(gs,"c17303")
	p.hand[i].bloodRage = 5
	e.units[0].hp = 1
	check(gs.play_card(0,i,e.units[0].uid),"enhanced rage lethal unit")
	check(p.avatarHp == 16 and e.units[0].hp == 0,"spell lifesteal uses full6 damage including overkill, not capped health loss")
	gs = fixture(); p = gs.player(0)
	p.avatarHp = 20
	play(gs,"c17305")
	check(play(gs,"c17301"),"life-steal form plus life-steal combat card")
	check(p.avatarHp == 23 and p.units[2].attack == 4,"same lifesteal keyword never stacks with itself")
	gs = fixture(); p = gs.player(0)
	play(gs,"c17307")
	p.avatarHp = 10
	gs._heal_avatar(0,3)
	check(p.units[2].attack == 7,"awake recovery growth before stat reset")
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,p.units[2],p.units[2].uid)
	check(p.units[2].attack == 4 and p.units[2].maxHp == 5 and not p.units[2].has("bloodGainedPower"),"sun reset clears ordinary recovery ledger and retains permanent awakening")
	gs._knockout_unit(p.units[2],1,0)
	check(p.units[2].attack == 4,"later knockout cannot subtract cleared recovery ledger twice")
	gs = fixture(); p = gs.player(0); e = gs.player(1)
	gs.kw_usage(0,"encourage").shield = 1
	gs.basic_attack(0,3)
	check(e.avatarHp == 27 and p.units[3].shield == 1,"encourage armor precedes whale's derived attack power")
	gs = fixture(); p = gs.player(0)
	check(play(gs,"c17308"),"moon before healer spell")
	p.avatarHp = 20
	check(play(gs,"c12907"),"allied multi-packet spell inherits moon lifesteal")
	check(p.avatarHp == 30,"multi-packet spell heals per damage and caps actual recovery")
	gs = fixture(); p = gs.player(0)
	play(gs,"c17908")
	p.deck.clear()
	gs._draw(0,1)
	check(gs.winner == 1,"treasure does not replace direct empty-deck defeat")
	for lineup in [["qingfangzhu","xixueji","jiuciliang","qingxingdeng"],["xixueji","qingfangzhu","jiuciliang","qingxingdeng"]]:
		gs = GS.create(lineup,["yaodaoji","bingyong","yingcao","shantong"],30)
		for unit in gs.player(0).units: unit.level = 3
		gs.player(0).avatarHp = 20
		gs.rule_events.clear()
		gs._heal_avatar(0,1)
		var events: Array = gs.rule_events.filter(func(event):return event.kind in ["monk-heal-trigger","blood-growth"]).map(func(event):return event.kind)
		check(events == (["monk-heal-trigger","blood-growth"] if lineup[0] == "qingfangzhu" else ["blood-growth","monk-heal-trigger"]),"healing abilities retain actual left-to-right source order")
	print("ARMOR_BLOOD_CONTINUATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
