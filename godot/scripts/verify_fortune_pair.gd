extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Fortune := preload("res://scripts/fortune_pair_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FORTUNE_PAIR_FAIL ", text)
func fixture() -> GS:
	var gs := GS.create(["qingwa-ciqi", "shantu", "zuofutongzi", "fenghuanghuo"], ["qingwa-ciqi", "shantu", "zuofutongzi", "fenghuanghuo"], 20261013)
	for p in gs.players:
		p.hand.clear()
		p.energy = 4
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "fortune-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func force_dice(gs, first: int, second: int = 0) -> void:
	for seed in 100000:
		var a := (seed * 1664525 + 1013904223) & 0xffffffff
		var b := (a * 1664525 + 1013904223) & 0xffffffff
		if 1 + int(floor(float(a) / 4294967296.0 * 6)) == first and (second == 0 or 1 + int(floor(float(b) / 4294967296.0 * 6)) == second):
			gs.rng_state = seed
			return
	check(false, "dice fixture exists")
func _initialize() -> void:
	_dice()
	_frog()
	_rabbit()
	_transform()
	_paper_cleanup()
	_paper_legality()
	_responses()
	_ai()
	print("FORTUNE_PAIR checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _dice() -> void:
	var gs := fixture()
	force_dice(gs, 1, 6)
	check(gs.VerifiedRules.Light.roll(gs, 0, 4), "base seat rerolls one")
	check(Fortune.sixes(gs, 0) == 1 and gs.player(0).fortuneNumbers == [1, 6], "actual first and reroll recorded")
	check(gs.player(0).fortuneSuccesses == 1, "one judgment success not two dice")
	check(gs.player(0).units[0].attack == 4, "frog gets success-turn bonus")
	gs.VerifiedRules.Light.roll(gs, 1, 1)
	check(Fortune.sixes(gs, 0) == 1, "enemy dice do not enhance cards")
	force_dice(gs, 2)
	check(not gs.VerifiedRules.Light.roll(gs, 0, 4), "two failure no base reroll")
	gs.player(0).units[2].awakened = true
	force_dice(gs, 2, 6)
	check(gs.VerifiedRules.Light.roll(gs, 0, 4), "awaken seat retries failed two")
	force_dice(gs, 2, 2)
	check(not gs.VerifiedRules.Light.roll(gs, 0, 4), "only one reroll")
	play(gs, "c12708")
	force_dice(gs, 2)
	check(gs.VerifiedRules.Light.roll(gs, 0, 6) and gs.kw_usage(0, "fortune").last.roll == 6, "justice applies to every allied die")
	check(not gs.kw_usage(0, "fortune").last.rerolled, "forced six never retries")
	gs._knockout_unit(gs.player(0).units[1])
	force_dice(gs, 2, 2)
	check(not gs.VerifiedRules.Light.roll(gs, 0, 6), "dead justice stops forced six")
func _frog() -> void:
	var gs := fixture()
	var frog: Dictionary = gs.player(0).units[0]
	force_dice(gs, 6)
	play(gs, "c12601")
	check(frog.attack == 4 and gs.player(1).avatarHp == 26, "cheat fortune resolves before attack")
	check(gs.player(0).hand.size() == 1 and gs.player(0).hand[0].definitionId == "c12601", "cheat creates same card")
	check(frog.shield == 1, "cheat printed armor applied")
	force_dice(gs, 6)
	gs.VerifiedRules.Light.roll(gs, 0, 4)
	check(frog.attack == 4, "base passive once per turn not per success")
	gs.turn_counter += 1
	Fortune.turn_boundary(gs)
	check(frog.attack == 2, "bonus expires on either turn boundary")
	gs = fixture()
	frog = gs.player(0).units[0]
	force_dice(gs, 2)
	play(gs, "c12601")
	check(gs.player(0).hand.is_empty() and frog.attack == 2 and gs.player(1).avatarHp == 28, "failure does not create or buff")
	gs = fixture()
	frog = gs.player(0).units[0]
	play(gs, "c12603")
	check(frog.attack == 2 and frog.hp == 7, "bloom exact printed body")
	force_dice(gs, 6)
	gs.VerifiedRules.Light.roll(gs, 0, 4)
	check(frog.attack == 5, "bloom permanent one plus passive two")
	gs.player(0).energy = 4
	play(gs, "c12606")
	force_dice(gs, 6)
	gs.VerifiedRules.Light.roll(gs, 0, 4)
	check(frog.attack == 9, "awakened success triggers bloom twice")
	check(gs.kw_usage(0, "fortune").last.effectRepeats == 2, "success snapshot repeats two")
	gs = fixture()
	gs.player(0).fortuneNumbers = [1, 2, 3, 4, 5, 6]
	play(gs, "c12608")
	check(gs.player(0).units[0].attack == 9 and gs.player(0).units[0].hp == 9, "nine lamps uses distinct dice exact body")
	gs = fixture()
	var idx := give(gs, "c12604")
	var targets: Array = gs.valid_targets(0, gs.hand_card_def(0, idx))
	check(targets.has("avatar-1") and not targets.has("avatar-0") and targets.size() == 5, "dice damage targets enemy avatar and living units")
	force_dice(gs, 6)
	check(gs.play_card(0, idx, "avatar-1"), "dice targets avatar")
	check(gs.player(1).avatarHp == 24 and gs.player(0).units[0].attack == 4, "dice value not constant damage")
	gs = fixture()
	gs.player(0).units[0].awakened = true
	force_dice(gs, 6)
	play(gs, "c12604", "avatar-1")
	check(gs.player(1).avatarHp == 18 and gs.player(0).fortuneSuccesses == 1, "awakened bomb duplicates six damage not die or success count")
	gs = fixture()
	play(gs, "c12602")
	force_dice(gs, 6)
	check(gs.basic_attack(0, 0), "door basic attack")
	check(gs.player(0).units[0].shield == 2 and gs.player(0).units[0].attack == 4, "modern door rolls on own attack")
	gs = fixture()
	force_dice(gs, 6)
	play(gs, "c12605")
	check(gs.player(1).avatarHp == 28 and gs.player(0).hand.is_empty(), "turnaround no repeat below two cards")
	gs = fixture()
	play(gs, "c12708")
	for id in ["c12702", "c12702", "c12608", "c12608"]: give(gs, id)
	gs.player(0).energy = 4
	play(gs, "c12605")
	check(gs.player(0).hand.is_empty() and gs.player(0).discard.size() >= 4, "turnaround discards two each repeat")
	check(gs.rule_events.filter(func(x): return x.kind == "fortune-random-discard").size() == 4, "discard events are actual hand instances")
	check(gs.player(1).avatarHp == 20, "three turnaround attacks no artificial attack bonus")
func _rabbit() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	force_dice(gs, 2)
	Fortune.turn_start(gs, 0, 1)
	check(p.units[2].attack == 2, "rabbit failed fortune no ally strength")
	force_dice(gs, 6)
	Fortune.turn_start(gs, 0, 1)
	check(p.units[1].attack == 3 and p.units[2].attack == 3, "rabbit only other allies receive one")
	check(p.units[0].attack == 5, "rabbit success activates frog and buffs it")
	gs = fixture()
	p = gs.player(0)
	p.units[1].awakened = true
	play(gs, "c12708")
	gs._knockout_unit(p.units[2])
	Fortune.turn_start(gs, 0, 1)
	check(p.units[2].hp > 0 and p.units[2].attack == 4, "two whole clauses revive then strengthen")
	check(Fortune.sixes(gs, 0) == 2 and p.fortuneSuccesses == 2, "awakened rabbit two separate judgments")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c12710")
	check(gs.hand_card_def(0, give(gs, "c12710")).level == 2, "win card modern second level")
	force_dice(gs, 2)
	gs.VerifiedRules.Light.roll(gs, 0, 1, 6, 0)
	check(p.units[1].get("nextFortuneSix", false), "frog die does not consume rabbit next die")
	force_dice(gs, 2)
	Fortune.turn_start(gs, 0, 1)
	check(Fortune.sixes(gs, 0) == 1 and not p.units[1].get("nextFortuneSix", false), "rabbit consumes one forced six")
	force_dice(gs, 2)
	Fortune.turn_start(gs, 0, 1)
	check(Fortune.sixes(gs, 0) == 1, "next roll returns to normal")
	gs = fixture()
	gs.player(0).fortuneSixes = 9
	play(gs, "c12710")
	check(gs.winner == -1 and gs.player(1).avatarHp == 30, "nine sixes no win no fake damage")
	gs = fixture()
	gs.player(0).fortuneSixes = 10
	play(gs, "c12710")
	check(gs.winner == 0 and gs.player(1).avatarHp == 30, "ten sixes wins without damage")
	for count in [2, 3]:
		gs = fixture()
		gs.player(0).fortuneSixes = count
		var gift := give(gs, "c12702")
		check(not gs.play_card(0, gift, gs.player(1).units[0].uid), "blessing rejects enemy after20210330")
		check(gs.player(0).energy == 4 and gs.player(0).hand.size() == 1, "illegal enemy no payment")
		check(gs.play_card(0, gift, gs.player(0).units[0].uid), "blessing ally threshold%d" % count)
		check(gs.player(0).units[0].attack == (3 if count == 2 else 5), "ally blessing enhancement threshold%d" % count)
		check(gs.player(0).units[0].get("swift", false) == (count >= 3), "three sixes grant swift")
		check(gs.player(0).hand.size() == 1, "20210629 blessing draws even below enhancement threshold")
		gs.player(0).energy = 0
		check(gs.basic_attack(0, 0) == (count >= 3), "swift zero fire basic attack at threshold")
		gs = fixture()
		gs.player(0).fortuneSixes = count
		play(gs, "c12706")
		check(gs.player(0).units[1].unyielding == (count >= 3), "protection unyielding threshold %d" % count)
	gs = fixture()
	gs.player(0).fortuneSixes = 4
	play(gs, "c12701")
	check(gs.player(1).avatarHp == 24, "projectile enhancement all sixes")
	gs = fixture()
	gs.player(0).fortuneSixes = 2
	var enemy: Dictionary = gs.player(1).units[3]
	gs.player(0).units[0].front = 1
	play(gs, "c12712", enemy.uid)
	check(enemy.front == 1 and gs.player(0).units[0].hp == 6, "forced enemy attack replaces front and temporary debuff prevents damage")
	check(gs.player(1).attackUsed == false, "forced attack does not spend enemy normal attack")
	var original := int(enemy.baseAttack) + int(enemy.attackBonus)
	gs.VerifiedRules.Fortune.end_turn(gs)
	check(enemy.attack == original, "forced attack power reduction expires at end of current turn")
func _transform() -> void:
	for count in [2, 3]:
		var gs := fixture()
		gs.player(0).fortuneSixes = count
		var enemy: Dictionary = gs.player(1).units[0]
		enemy.front = 1
		gs._install_form(1, 0, ContentLoader.card_def("c12603"))
		enemy.awakened = true
		enemy.shield = 10
		play(gs, "c12711")
		var body := 3 if count == 2 else 1
		check(enemy.hp == body and enemy.attack == body and enemy.shield == 0, "paper exact body and armor removed %d" % count)
		check(enemy.front == 1 and enemy.baseRulesSuppressed and enemy.passive_hooks.is_empty(), "paper remains front and suppresses ability")
		check(ContentLoader.runtime_unit_def(enemy).is_empty(), "runtime abilities cannot read original definition")
		force_dice(gs, 6)
		gs.VerifiedRules.Light.roll(gs, 1, 4)
		check(enemy.attack == body, "transformed awakened frog cannot buff or duplicate")
		check(gs.kw_usage(1, "fortune").last.effectRepeats == 1, "paper does not duplicate fortune")
		gs._knockout_unit(enemy)
		check(not enemy.get("baseRulesSuppressed", false) and enemy.form.is_empty(), "paper removed at knockout")
func _paper_cleanup() -> void:
	var gs := GS.create(["caitongzi", "yingcao", "taohuayao", "jutun-tongzi"], ["caitongzi", "yingcao", "taohuayao", "jutun-tongzi"], 261013)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	var p: Dictionary = gs.player(0)
	gs.VerifiedRules.DogDemon.turn_start(gs, 0, 0)
	gs._damage_unit(0, 3, 1, 1, 0)
	for idx in p.units.size(): gs._grow_unit(p.units[idx], 2, 2)
	gs._grow_unit(p.units[1], 0, 2)
	p.units[1].fireflyTemporaryHealth = 2
	gs._grow_unit(p.units[2], 1, 0)
	p.units[2].peachTemporaryAttack = 1
	for idx in p.units.size():
		Fortune.transform(gs, 0, idx, false)
		check(p.units[idx].attack == 3 and p.units[idx].maxHp == 3, "paper body hides original growth " + str(idx))
	gs.VerifiedRules.DogDemon.turn_start(gs, 0, 0)
	check(p.units[0].attack == 3, "paper demon cannot turn-start grow")
	for idx in p.units.size():
		gs._knockout_unit(p.units[idx])
		check(p.units[idx].attack == int(p.units[idx].baseAttack) + 2, "paper death cleans ordinary growth exactly once " + str(idx))
		check(p.units[idx].maxHp == int(p.units[idx].baseMaxHp) + 2, "paper death preserves permanent health but removes firefly temporary " + str(idx))
	check(not p.units[0].has("demonGrowth") and not p.units[3].has("shutenRageGrowth"), "restored role runs demon and rage cleanup")
func _responses() -> void:
	var gs := fixture()
	var frog: Dictionary = gs.player(1).units[0]
	frog.front = 1
	give(gs, "c12609", 1)
	force_dice(gs, 6)
	check(gs.basic_attack(0, 0), "attack response frog")
	check(frog.hp == 6 and gs.player(0).units[0].hp == 2, "straight response immunity and passive stronger counter")
	check(gs.player(1).energy == 3 and gs.player(1).hand.is_empty(), "straight actual response cost")
	gs = fixture()
	gs._install_form(1, 0, ContentLoader.card_def("c12603"))
	gs.player(1).units[0].front = 1
	give(gs, "c12609", 1)
	force_dice(gs, 2)
	check(gs.basic_attack(0, 0), "form straight response")
	check(gs.player(1).units[0].hp == 7, "attached form guarantees fortune success")
	gs = fixture()
	gs.player(1).units[1].front = 1
	give(gs, "c12711", 1)
	check(gs.basic_attack(0, 0), "rabbit lasso response")
	check(gs.rule_events.any(func(x): return x.kind == "paper-transformed" and x.uid == gs.player(0).units[0].uid), "lasso response transforms actual attacker")
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 3, "lasso response one payment")
	gs = fixture()
	gs.player(0).units[0].awakened = true
	play(gs, "c12708")
	gs.player(0).energy = 1
	play(gs, "c13004")
	check(gs.player(0).energy == 4, "seat fire duplicated: cost one and plus four")
	check(gs.player(0).fortuneSuccesses == 1, "effect doubling keeps one success")
func _paper_legality() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	Fortune.transform(gs, 0, 0, false)
	for id in ["c12601", "c12604", "c12603", "c12606"]:
		p.hand.clear()
		var idx := give(gs, id)
		var target = "avatar-1" if id == "c12604" else null
		check(not gs.can_play_card(0, idx, target).ok, "paper cannot use original " + id)
		check(not gs.play_card(0, idx, target) and p.hand.size() == 1 and p.energy == 4, "illegal paper play no spend " + id)
		check(not AI._best_card(gs, 0).ok, "AI excludes paper original " + id)
	check(gs.can_basic_attack(0, 0).ok and gs.basic_attack(0, 0), "paper normal basic attack legal")
	check(gs.player(1).avatarHp == 27, "paper uses transformed power in ordinary attack")
	gs = GS.create(["quanshen", "shantu", "zuofutongzi", "qingwa-ciqi"], ["quanshen", "shantu", "zuofutongzi", "qingwa-ciqi"], 261013)
	p = gs.player(0)
	p.hand.clear()
	p.energy = 4
	p.levelUpUsed = true
	for u in p.units: u.level = 3
	Fortune.transform(gs, 0, 0, false)
	gs._knockout_unit(p.units[0])
	var idx := give(gs, "c12103")
	check(gs.can_play_card(0, idx).ok and gs.play_card(0, idx), "original dog revival legal after paper knockout")
	check(p.units[0].hp > 0 and not p.units[0].get("baseRulesSuppressed", false), "revival returns original identity")
func _ai() -> void:
	for id in ["c12601", "c12602", "c12603", "c12604", "c12605", "c12606", "c12608", "c12609", "c12701", "c12702", "c12706", "c12707", "c12708", "c12710", "c12711", "c12712"]:
		var gs := fixture()
		gs.player(1).units[0].front = 1
		gs.player(0).fortuneSixes = 3
		give(gs, id)
		var choice: Dictionary = AI._best_card(gs, 0)
		if choice.get("ok", false):
			check(gs.can_play_card(0, int(choice.hand), choice.get("target")).ok, "AI legal " + id)
			check(gs.play_card(0, int(choice.hand), choice.get("target")), "AI candidate actually resolves " + id)
		else: check(false, "AI should use available source-backed card " + id)
