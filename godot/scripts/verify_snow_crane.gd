extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SNOW_CRANE_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["xuetongzi", "guniao", "yaodaoji", "taohuayao"], ["xuetongzi", "guniao", "yaodaoji", "bingyong"], 112109)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "snow-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func _initialize() -> void:
	_reproducer()
	_snow_rules()
	_spread()
	_crane_rules()
	_stun_and_payment()
	_ai_and_save()
	print("SNOW_CRANE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _reproducer() -> void:
	var gs := fixture()
	play(gs, "c11207")
	check(gs.player(1).get("avatarFrozen", 0) == 1 and gs.player(1).avatarHp == 26, "frost wind stuns avatar before real 4 power combat")
	check(gs.player(0).units[0].shield == 2, "frost wind grants printed two armor")
	gs = fixture()
	gs.player(1).units[2].frozen = 1
	play(gs, "c11203")
	check(gs.player(0).units[0].attack == 7 and gs.player(0).units[0].maxHp == 7, "snow country is a conditional 7/7 form")
	gs = fixture()
	gs.player(1).units[2].front = 1
	gs.player(0).units[1].attack = 10
	play(gs, "c10903")
	check(gs.player(1).avatarHp == 18 and gs.player(1).units[2].hp == 4, "cloud crane directly attacks with actual power plus two")
	gs = fixture()
	var idx := give(gs, "c10905")
	gs.player(1).units[0].front = 1
	check(gs.valid_targets(0, gs.hand_card_def(0, idx)).size() == 3, "sky slash picks only enemy reserve")
	gs = fixture()
	gs.player(1).units[2].front = 1
	gs.player(1).units[2].frozen = 1
	gs.player(0).units[1].hp = 10
	gs.player(0).units[1].maxHp = 10
	gs.basic_attack(0, 1)
	check(gs.player(0).units[1].hp == 7, "stunned defenders still counterattack")
	gs = fixture()
	gs.player(1).energy = 0
	give(gs, "c10907", 1)
	gs.end_turn(0)
	check(gs.player(1).hand.is_empty() or not gs.player(1).hand.any(func(c): return c.definitionId == "c10907"), "end-turn ambush works with instant at zero fire")

func _snow_rules() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	e.units[2].front = 1
	e.units[2].hp = 1
	play(gs, "c11207")
	check(int(e.get("avatarFrozen", 0)) == 0 and e.avatarHp == 30, "frost wind tests empty front before the kill")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	e.units[2].front = 1
	e.units[2].hp = 20
	e.units[2].maxHp = 20
	e.units[2].attack = 12
	play(gs, "c11201")
	check(e.units[2].frozen == 1 and e.units[2].hp == 17 and p.units[0].hp == 4, "snow walk freezes before zero-bonus attack and grants conditional immunity")
	check(p.get("enemyStuns", 0) == 1, "snow walk uses match stun ledger")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	e.units[0].front = 1
	give(gs, "c11201", 1)
	gs.basic_attack(0, 2)
	check(e.hand.is_empty() and e.energy == 39, "snow walk responds only to its source being attacked")
	check(p.units[2].hp == 1 and p.units[2].frozen == 2 and e.units[0].hp == 4, "snow walk response modifies one combat and stuns attacker through next turn")
	check(gs.rule_events.filter(func(ev): return ev.kind == "combat-hit").size() == 1, "response does not create a second attack")
	gs = fixture()
	gs.player(1).units[2].front = 1
	give(gs, "c11201", 1)
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.size() == 1, "snow walk ignores another ally attacked")
	for frozen in [false, true]:
		for awake in [false, true]:
			gs = fixture()
			p = gs.player(0)
			e = gs.player(1)
			if awake: play(gs, "c11208")
			e.units[2].front = 1
			e.units[2].hp = 30
			e.units[2].maxHp = 30
			e.units[2].attack = 1
			e.units[2].frozen = 1 if frozen else 0
			var hp := int(p.units[0].hp)
			gs.basic_attack(0, 0)
			check(e.units[2].hp == 30 - (4 if awake else 3) * (2 if awake and frozen else 1), "snow extra hit condition awake=%s frozen=%s" % [awake, frozen])
			check(p.units[0].hp == hp - (0 if frozen else 1), "snow combat immunity condition")
	gs = fixture()
	play(gs, "c11208")
	play(gs, "c11207")
	check(gs.player(1).avatarHp == 20, "frost wind stuns first then awakened snow hits avatar twice for five")
	gs = fixture()
	play(gs, "c11208")
	gs.player(0).units[0].keywords = ["combo"]
	gs.player(1).units[2].front = 1
	gs.player(1).units[2].hp = 30
	gs.player(1).units[2].maxHp = 30
	gs.player(1).units[2].frozen = 1
	gs.basic_attack(0, 0)
	check(gs.player(1).units[2].hp == 18, "snow extra first hit stacks with two-hit combat rather than replacing it")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	var idx := give(gs, "c11202")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 1, "dance normally costs one")
	gs.VerifiedRules.Stun.apply(gs, 1, -1)
	check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0, "stunned avatar enables dance instant")
	gs.VerifiedRules.Stun.apply(gs, 1, 2)
	gs.VerifiedRules.Stun.apply(gs, 1, 3)
	idx = give(gs, "c11205")
	check(gs.hand_card_def(0, idx).value == 5 and ContentLoader.card_def("c11205").value == 2, "weave counts avatar and two units without mutating definition")
	idx = give(gs, "c11206")
	check(gs.hand_card_def(0, idx).value.attack == 8, "thaw sees all historical enemy stuns")
	check(gs.play_card(0, idx), "play enhanced thaw")
	check(p.units[0].attack == 8 and p.units[0].maxHp == 7, "thaw body uses hand enhancement")
	gs.VerifiedRules.Stun.apply(gs, 1, 1)
	check(p.units[0].attack == 8, "deployed thaw does not acquire future hand enhancement")
	p.units[0].shield = 4
	gs._damage_unit(0, 0, 6, 1, 1)
	check(p.units[0].shield == 0 and p.units[0].hp == 5, "thaw consumes armor before capping health damage")
	gs._damage_unit(0, 0, 20, 1, 1)
	check(p.units[0].hp == 2, "thaw limits each separate damage to three")
	gs._damage_unit(0, 0, 2, 1, 1)
	check(p.units[0].hp == 0 and p.get("enemyStuns", 0) == 4, "small lethal damage kills thaw and ledger survives")
	check(p.units[0].get("formRules", {}).is_empty(), "thaw ability ends on knockout")
	gs = fixture()
	play(gs, "c11203")
	check(gs.player(0).units[0].attack == 5 and gs.player(0).units[0].maxHp == 5, "country without stun is five five")

func _spread() -> void:
	for protection in ["none", "armor", "barrier", "overkill"]:
		var gs := fixture()
		var e: Dictionary = gs.player(1)
		e.units[2].front = 1
		e.units[2].hp = 2 if protection == "overkill" else 20
		e.units[2].maxHp = 20
		e.units[2].attack = 0
		e.units[2].shield = 2 if protection == "armor" else 0
		e.units[2].barrier = protection == "barrier"
		e.units[1].hp = 20
		e.units[1].maxHp = 20
		e.units[1].frozen = 1
		e.avatarFrozen = 1
		var before := gs.snapshot()
		play(gs, "c11204")
		var amount := 0 if protection == "barrier" else (3 if protection == "armor" else 5)
		check(e.units[1].hp == 20 - amount and e.avatarHp == 30 - amount, "spread uses actual unshielded damage including overkill " + protection)
		check(e.units[0].hp == 4 and e.units[3].hp == 6, "spread excludes unstunned units " + protection)
		check(gs.rule_events.filter(func(ev): return ev.kind == "snow-spread").size() == (0 if amount == 0 else 2), "spread does not recurse " + protection)
		var cues := preload("res://scripts/ui/battle_effect_cues.gd").damage_cues(before, gs.snapshot())
		check(cues.size() >= (0 if amount == 0 else 2), "spread emits source-aware damage visuals")
	var gs := fixture()
	gs.player(1).units[2].frozen = 1
	gs.player(1).units[2].hp = 20
	gs.player(1).units[2].maxHp = 20
	play(gs, "c11204")
	check(gs.player(1).avatarHp == 25 and gs.player(1).units[2].hp == 15, "avatar combat spreads to stunned reserve")

func _crane_rules() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	play(gs, "c10902")
	check(p.units[1].attack == 4 and p.units[1].maxHp == 4, "shadow form sets four four")
	play(gs, "c10903")
	check(e.avatarHp == 23 and p.units[1].attack == 5 and p.units[1].front == 0, "shadow grows before direct combat and retreats")
	play(gs, "c10904")
	check(p.units[1].attack == 7 and p.units[1].maxHp == 4, "shadow earned growth survives form replacement")
	gs._knockout_unit(p.units[1])
	check(p.units[1].attack == 3 and p.units[1].maxHp == 4 and not p.units[1].has("cranePower"), "nonpermanent crane growth ends on knockout")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	e.units[0].front = 1
	e.units[0].attack = 0
	var hand := give(gs, "c10905")
	var before := JSON.stringify(gs.players)
	check(not gs.play_card(0, hand, e.units[0].uid), "sky slash rejects front target")
	check(JSON.stringify(gs.players) == before, "invalid sky slash does not pay or alter board")
	check(not gs.play_card(0, hand, p.units[0].uid), "sky slash rejects ally")
	check(not gs.play_card(0, hand, "avatar-1"), "sky slash rejects avatar even if printed pierce")
	e.units[2].hp = 2
	e.units[2].attack = 1
	check(gs.play_card(0, hand, e.units[2].uid), "sky slash accepts reserve")
	check(e.units[2].hp == 0 and e.avatarHp == 26 and e.units[0].hp == 4, "reserve attack with real overflow leaves front intact")
	check(p.units[1].hp == 3 and p.units[1].front == 0, "reserve target counters before crane retreats")
	gs = fixture()
	p = gs.player(0)
	for id in ["c10901", "c10904", "c10908"]: give(gs, id)
	gs.basic_attack(0, 0)
	for idx in p.hand.size(): check(gs.effective_card_cost(0, gs.hand_card_def(0, idx)) == 0, "ally attack grants held crane card instant")
	hand = give(gs, "c10901")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, hand)) == 1, "crane card drawn after attack does not retroactively trigger")
	check(gs.play_card(0, 0), "held parasol uses instant")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 1, "crane cards share same instant allowance")
	gs.end_turn(0)
	gs.end_turn(1)
	check(not gs.card_payment(0, gs.hand_card_def(0, 0)).instant, "per-card ally instant expires next turn")
	gs = fixture()
	p = gs.player(0)
	give(gs, "c10901")
	gs.basic_attack(0, 1)
	check(not gs.card_payment(0, gs.hand_card_def(0, 0)).instant, "crane's own attack cannot trigger other-ally condition")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c10906")
	play(gs, "c10104")
	check(p.units[1].swift and not p.attackUsed, "ally combat grants swift without spending normal attack")
	p.energy = 0
	check(gs.basic_attack(0, 1) and not p.units[1].swift and p.attackUsed, "swift pays one normal attack only")
	check(not gs.can_basic_attack(0, 0).ok, "swift does not grant another team attack")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	play(gs, "c10908")
	check(gs.VerifiedRules.Combat.has(p.units[1], "remote") and p.units[1].attack == 5, "awakening grants persistent remote and printed power")
	p.units[0].front = 1
	e.units[2].front = 1
	e.units[2].hp = 20
	e.units[2].maxHp = 20
	e.units[2].attack = 20
	gs.basic_attack(0, 1)
	check(p.units[1].hp == 4 and p.units[0].front == 1 and p.units[1].front == 0, "remote crane preserves guardian and avoids counter")
	gs._knockout_unit(p.units[1])
	p.units[1].hp = p.units[1].maxHp
	p.units[1].knockout = 0
	check(gs.VerifiedRules.Combat.has(p.units[1], "remote"), "remote awakening survives knockout")

func _stun_and_payment() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	gs.VerifiedRules.Stun.apply(gs, 0, -1)
	check(not gs.can_basic_attack(0, 1).ok, "stunned avatar blocks all basic attacks")
	play(gs, "c10903")
	check(gs.player(1).avatarHp == 25, "stunned avatar still permits combat cards")
	gs.VerifiedRules.Stun.apply(gs, 0, 1)
	var idx := give(gs, "c10904")
	check(not gs.can_play_card(0, idx).ok, "stunned source cannot use noncombat cards")
	gs.end_turn(0)
	check(p.avatarFrozen == 1 and p.units[1].frozen == 1, "own-turn stun lasts past current end")
	gs.end_turn(1)
	gs.end_turn(0)
	check(p.avatarFrozen == 0 and p.units[1].frozen == 0, "stun ends at next own turn end")
	for mode in ["empty", "front", "stunned", "used", "two", "dead"]:
		gs = fixture()
		p = gs.player(1)
		p.energy = 0
		give(gs, "c10907", 1)
		if mode == "front": gs.player(0).units[0].front = 1
		if mode == "stunned": p.units[1].frozen = 1
		if mode == "dead": gs._knockout_unit(p.units[1])
		if mode == "used": gs.kw_usage(1, "instant").used = true
		if mode == "two": give(gs, "c10907", 1)
		gs.end_turn(0)
		var responses := gs.rule_events.filter(func(ev): return ev.kind == "response-card")
		var expected := 1 if mode in ["empty", "two"] else 0
		check(responses.size() == expected, "ambush end-turn condition " + mode)
		check(gs.player(0).avatarHp == 30 - expected * 6, "ambush real combat damage " + mode)
		if expected > 0: check(responses[0].payment.cost == 0 and responses[0].payment.usesInstant, "ambush spends opponent-turn instant")
	gs = fixture()
	gs.player(1).energy = 1
	give(gs, "c10907", 1)
	give(gs, "c10907", 1)
	gs.end_turn(0)
	var ev := gs.rule_events.filter(func(item): return item.kind == "response-card")
	check(ev.size() == 2 and ev[0].payment.cost == 0 and ev[1].payment.cost == 1, "two ambushes share instant then pay printed fire")
	check(gs.player(0).avatarHp == 18, "two ambushes execute two attacks")
	gs = fixture()
	give(gs, "c10907", 1)
	gs.player(0).units[2].front = 1
	gs._knockout_unit(gs.player(0).units[2])
	check(gs.player(1).hand.size() == 1, "modern ambush no longer responds immediately to death")

func _ai_and_save() -> void:
	var gs := fixture()
	gs.player(1).units[0].front = 1
	give(gs, "c10905")
	var best := AI._best_card(gs, 0)
	check(best.ok and best.target != gs.player(1).units[0].uid and gs.can_play_card(0, best.hand, best.target).ok, "AI selects legal reserve target")
	check(AI.take_action(gs, 0), "AI executes reserve targeting")
	gs = fixture()
	gs.VerifiedRules.Stun.apply(gs, 1, -1)
	gs.player(0).energy = 0
	give(gs, "c11202")
	check(AI._best_card(gs, 0).ok and AI.take_action(gs, 0), "AI uses conditional instant at zero fire")
	var saved = JSON.parse_string(JSON.stringify(gs.players))
	check(saved[0].enemyStuns == 1 and saved[1].avatarFrozen == 1, "stun ledger and avatar state survive JSON")
	for seed_value in range(12):
		gs = GS.create(["xuetongzi", "guniao", "yaodaoji", "taohuayao"], ["xuetongzi", "guniao", "bailang", "shantong"], 112109 + seed_value)
		for turn in 160:
			if gs.winner >= 0: break
			AI.take_turn(gs, gs.action_player())
		check(gs.winner >= 0, "targeted AI match ends seed %d" % seed_value)
