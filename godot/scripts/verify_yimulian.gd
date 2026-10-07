extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Rules := preload("res://scripts/verified_card_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YIMULIAN_FAIL ", message)

func fixture(seed_value := 11809) -> GS:
	var gs := GS.create(["yimulian", "yaoginshi", "datiangou-gangfeng", "basalt"], ["yimulian", "yaoginshi", "datiangou", "basalt"], seed_value)
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs

func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId": "test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, 0, id), target), "play " + id)

func tick(gs: GS, amount: int) -> void:
	Rules.reduce_countdown(gs, 0, 0, amount)
	gs._resolve_resolution_stack()

func _initialize() -> void:
	_forms()
	_armor()
	_encourage()
	_destruction()
	_dragon()
	_response()
	_interactions()
	print("YIMULIAN checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("YIMULIAN_OK")
	quit(0 if failures == 0 else 1)

func _forms() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	check(Rules.Countdown.timer(u).is_empty(), "no timer without form")
	play(gs, "c11801")
	check(u.attack == 3 and u.maxHp == 6 and u.hp == 6, "printed form body replaces base")
	check(gs.player(1).avatarHp == 30 and u.formCountdown.remaining == 2, "unawakened entry does not trigger")
	tick(gs, 1)
	check(gs.player(1).avatarHp == 30 and u.formCountdown.remaining == 1, "one countdown tick waits")
	u.frozen = 1
	tick(gs, 9)
	check(gs.player(1).avatarHp == 27 and u.formCountdown.remaining == 2, "stun does not stop timer; overflow triggers only once")
	u.frozen = 0
	u.hp = 1
	play(gs, "c11802")
	check(gs.player(1).avatarHp == 24 and u.hp == 7 and u.attack == 2, "replacement triggers old effect then installs full new form")
	check(int(gs.player(0).get("avatarArmor", 0)) == 0, "new protection form waits before awakening")
	var deck: int = gs.player(0).deck.size()
	var energy: int = gs.player(0).energy
	play(gs, "c11803")
	check(u.form.is_empty() and Rules.Countdown.timer(u).is_empty() and u.hp == 6, "gale removes form, returns underlying full health")
	check(gs.player(0).avatarArmor == 5 and gs.player(0).deck.size() == deck - 2, "departing form triggers then gale draws two")
	check(gs.player(0).energy == energy, "first gale is instant")
	play(gs, "c11803")
	check(gs.player(0).deck.size() == deck - 4 and gs.player(0).energy == energy - 1, "no form still draws; second instant costs fire")
	play(gs, "c11801")
	play(gs, "c11806")
	check(gs.player(1).avatarHp == 24 and u.attack == 5, "awakening adds +2/0, does not retroactively enter existing form")
	play(gs, "c11802")
	check(gs.player(1).avatarHp == 21 and gs.player(0).avatarArmor == 10, "awakened replacement fires departure then entry")
	var triggers: Array = gs.rule_events.filter(func(e): return e.kind == "form-trigger")
	check(triggers[-2].card.id == "c11801" and triggers[-1].card.id == "c11802" and triggers[-1].reason == "进场", "lifecycle order is preserved")
	check(u.formCountdown.remaining == 2, "entry trigger leaves the form timer at two")
	play(gs, "c11806")
	check(u.attack == 6 and gs.player(0).avatarArmor == 10, "repeat awakening keeps capability, applies printed bonus again")
	gs._damage_unit(0, 0, 99, 1)
	gs._resolve_resolution_stack()
	check(u.hp == 0 and u.form.is_empty() and u.awakened and u.attack == 6, "death loses form but retains awakening and printed bonus")
	check(gs.player(0).avatarArmor == 15, "departing ability resolves while source is knocked out")

func _armor() -> void:
	var gs := fixture()
	play(gs, "c11802")
	tick(gs, 2)
	check(gs.player(0).avatarArmor == 5 and gs.player(0).units.all(func(u): return u.shield == 0), "protection belongs to avatar, not front or whole team")
	gs.player(0).realms.append({"name": "test", "hp": 10, "avatarLinked": true})
	gs._damage_avatar(0, 3, 1)
	check(gs.player(0).avatarArmor == 2 and gs.player(0).avatarHp == 30 and gs.player(0).realms[0].hp == 10, "armor absorbs before health and linked durability")
	gs._damage_avatar(0, 4, 1)
	check(gs.player(0).avatarArmor == 0 and gs.player(0).avatarHp == 28 and gs.player(0).realms[0].hp == 8, "only residual damage reduces health and durability")
	tick(gs, 2)
	gs._begin_turn(1)
	check(gs.player(0).avatarArmor == 5, "opponent start preserves armor")
	gs._begin_turn(0)
	check(gs.player(0).avatarArmor == 0 and gs.player(0).units[0].formCountdown.remaining == 1, "owner start clears armor before timer")
	gs._begin_turn(0)
	check(gs.player(0).avatarArmor == 5, "timer grants new armor after cleanup")

func _encourage() -> void:
	var gs := fixture()
	play(gs, "c11804")
	var source: Dictionary = gs.player(0).units[0]
	tick(gs, 2)
	tick(gs, 2)
	check(source.attack == 3 and source.shield == 0 and gs.kw_usage(0, "encourage").attack == 6, "two triggers bank encouragement without buffing caster")
	gs._resolve_combat(0, 3, 0, false, false, false, false)
	check(gs.kw_usage(0, "encourage").attack == 6, "ordinary combat does not consume encouragement")
	var attacker: Dictionary = gs.player(0).units[3]
	var hp: int = gs.player(1).avatarHp
	var power: int = attacker.attack
	check(gs.basic_attack(0, 3), "basic attack uses banked encouragement")
	check(gs.player(1).avatarHp == hp - power - 6 and attacker.attack == power and attacker.shield == 6, "next attacker gets temporary power and real armor")
	check(gs.kw_usage(0, "encourage").attack == 0 and gs.kw_usage(0, "encourage").shield == 0, "entire bank is consumed once")
	gs._begin_turn(1)
	check(attacker.shield == 6, "encourage armor protects through opposing turn")
	gs._begin_turn(0)
	check(attacker.shield == 0, "encourage armor expires at owner start")

func _destruction() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[3]
	enemy.hp = 80
	enemy.shield = 100
	enemy.unyielding = true
	enemy.barrier = true
	enemy.front = 1
	play(gs, "c11805")
	check(enemy.hp == 80, "unawakened annihilation waits")
	tick(gs, 2)
	check(enemy.hp == 0 and enemy.knockout > 0, "annihilation destroys despite armor barrier and unyielding")
	check(gs.rule_events.any(func(e): return e.kind == "unit-destroyed" and e.target == enemy.uid), "destruction is reported as destruction")
	tick(gs, 2)
	check(gs.player(1).avatarHp == 30, "empty battle zone never redirects destruction to avatar")
	gs = fixture()
	play(gs, "c11801")
	var yimu: Dictionary = gs.player(0).units[0]
	yimu.hp = 2
	yimu.front = 1
	enemy = gs.player(1).units[3]
	enemy.hp = 5
	enemy.attack = 4
	gs.current_player = 1
	check(gs.basic_attack(1, 3), "opposing combat begins")
	check(yimu.hp == 0 and enemy.hp == 0, "retaliation happens before departing projectile finishes surviving attacker")
	check(gs.player(1).avatarHp == 30, "projectile finds attacker after combat, not avatar")

func _dragon() -> void:
	var gs := fixture()
	for unit in gs.player(1).units: gs._grow_unit(unit, 0, 100)
	gs.player(1).avatarHp = 100
	play(gs, "c11806")
	play(gs, "c11807")
	check(gs.player(0).units[0].formCountdown.triggers == 1, "entry counts as first dragon trigger")
	var hits: Array = gs.rule_events.filter(func(e): return e.kind == "random-hit")
	check(hits.size() == 1, "first dragon wave has one target")
	var total := 0
	for unit in gs.player(1).units: total += int(unit.maxHp) - int(unit.hp)
	total += 100 - int(gs.player(1).avatarHp)
	check(total == 6, "updated dragon deals six, not stale five")
	for expected in [2, 3, 4, 5, 5]:
		gs.rule_events.clear()
		tick(gs, 2)
		hits = gs.rule_events.filter(func(e): return e.kind == "random-hit")
		check(hits.size() == expected, "dragon grows target count up to live population")
		var targets: Array = []
		for hit in hits:
			check(not targets.has(hit.target), "wave picks distinct targets")
			targets.append(hit.target)
	gs.rule_events.clear()
	play(gs, "c11803")
	check(gs.rule_events.filter(func(e): return e.kind == "random-hit").size() == 5, "gale death trigger uses departing dragon history")
	check(not ContentLoader.card_def("c11807").get("verificationPending", []).is_empty(), "uncertain cross-card and sampling boundaries stay visible in audit")
	# A replacement is a different physical form: its entry is wave one,
	# while the departing form retains its already accumulated count.
	gs = fixture()
	for unit in gs.player(1).units: gs._grow_unit(unit, 0, 100)
	gs.player(1).avatarHp = 100
	play(gs, "c11806")
	play(gs, "c11807")
	tick(gs, 2)
	gs.rule_events.clear()
	play(gs, "c11807")
	var waves: Array = gs.rule_events.filter(func(e): return e.kind == "form-trigger")
	check(waves.size() == 2 and waves[0].count == 3 and waves[1].count == 1, "different dragon copies do not share trigger counts")
	check(gs.rule_events.filter(func(e): return e.kind == "random-hit").size() == 4, "old three-target wave finishes before new one-target wave")
	var solo := fixture()
	for unit in solo.player(1).units: unit.hp = 0
	play(solo, "c11807")
	tick(solo, 2)
	tick(solo, 2)
	check(solo.player(1).avatarHp == 18, "single survivor receives one hit per wave, not repeated damage")

func _response() -> void:
	for condition in ["self", "ally", "reserve", "stun", "level", "fire", "owner-turn"]:
		var gs := fixture()
		var yimu: Dictionary = gs.player(0).units[0]
		yimu.front = 1
		yimu.hp = 2
		if condition == "ally":
			yimu.front = 0
			gs.player(0).units[3].front = 1
		if condition == "reserve": yimu.front = 0
		if condition == "stun": yimu.frozen = 1
		if condition == "level": yimu.level = 1
		if condition == "fire": gs.player(0).energy = 0
		give(gs, 0, "c11808")
		gs.current_player = 0 if condition == "owner-turn" else 1
		gs._resolve_combat(1, 3, 0, false, false, false, false, yimu.uid, false, {"pursuit": condition == "reserve"})
		gs._resolve_resolution_stack()
		var response: Array = gs.rule_events.filter(func(e): return e.kind == "response-card")
		var should: bool = condition in ["self", "reserve"]
		check((response.size() == 1) == should, "response eligibility " + condition)
		if should:
			check(yimu.form.cardId == "c11808" and yimu.hp == 9 - int(gs.player(1).units[3].attack), "response installs printed 6/9 before damage")
			check(gs.player(1).units[3].hp == 6 and gs.player(0).hand.is_empty() and gs.player(0).energy == 19, "new six power retaliates and response pays one fire")
			check(Rules.Countdown.timer(yimu).is_empty(), "instant form has no invented countdown")
			Rules.end_turn(gs, 1)
			check(yimu.form.is_empty() and yimu.hp == 6 and yimu.attack == 2, "opponent end destroys temporary form, refills base health")
	var gs := fixture()
	play(gs, "c11808")
	gs.player(0).units[0].hp = 1
	Rules.end_turn(gs, 0)
	check(gs.player(0).units[0].form.is_empty() and gs.player(0).units[0].hp == 6, "manual instant form expires at current own turn end")
	play(gs, "c11808")
	play(gs, "c11802")
	Rules.end_turn(gs, 0)
	check(gs.player(0).units[0].form.cardId == "c11802", "replacing instant form removes its scheduled expiry")

func _interactions() -> void:
	var gs := fixture()
	play(gs, "c11801")
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	play(gs, "c11802")
	check(gs.player(0).units[0].form.cardId == "c11801" and gs.player(1).avatarHp == 30, "countered replacement keeps old form and does not fire it")
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	tick(gs, 2)
	check(gs.player(1).avatarHp == 27 and gs.player(0).has("nullifyNextCardTurn"), "form ability is not a hand card for seal")
	gs.player(0).erase("nullifyNextCardTurn")
	var u: Dictionary = gs.player(0).units[0]
	u.formCountdown.remaining = 1
	play(gs, "c12804", u.uid)
	check(gs.player(1).avatarHp == 24, "qin countdown manipulation triggers real form ability")
	var left := fixture(992)
	var right := fixture(992)
	for state in [left, right]:
		play(state, "c11806")
		play(state, "c11807")
		tick(state, 2)
	check(left.snapshot() == right.snapshot(), "seeded dragon choices replay deterministically")
	gs = fixture()
	give(gs, 0, "c11808")
	check(not AI._best_card(gs, 0).ok, "AI holds conditional response")
	give(gs, 0, "c11806")
	check(AI._best_card(gs, 0).card_id == "c11806", "AI can legally awaken")
	for id in ["c11801", "c11802", "c11803", "c11804", "c11805", "c11807"]:
		gs = fixture()
		give(gs, 0, id)
		var move := AI._best_card(gs, 0)
		check(move.ok and gs.can_play_card(0, move.hand, move.target).ok, "AI legal use " + id)
