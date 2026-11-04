extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARCHER_MOUNTAIN_FAIL ", msg)
func fixture() -> GS:
	var gs := GS.create(["bailang", "shantong", "yaodaoji", "taohuayao"], ["bailang", "shantong", "yaodaoji", "taohuayao"], 110113)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "archer-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func _initialize() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[0]
	enemy.hp = 2
	enemy.front = 1
	check(gs.basic_attack(0, 1), "mountain attack")
	check(gs.player(1).avatarHp == 29, "real mountain overflow is one")
	gs = fixture()
	enemy = gs.player(1).units[0]
	enemy.hp = 2
	enemy.front = 1
	enemy.barrier = true
	gs.basic_attack(0, 1)
	check(enemy.hp == 2 and gs.player(1).avatarHp == 29, "barrier prevents unit hit but not overflow")
	gs = fixture()
	play(gs, "c11001")
	check(gs.player(0).units[0].attack == 5, "2022 bow grants two power")
	play(gs, "c11004")
	check(ContentLoader.card_def("c11004").level == 1 and gs.player(0).units[0].attack == 5 and gs.player(0).units[0].maxHp == 5, "modern zanshin replaces body and preserves spell buff")
	gs = fixture()
	play(gs, "c11304")
	gs.end_turn(0)
	check(gs.player(0).units[1].attack == 0, "clumsy has zero power on opposing turn")
	gs = fixture()
	play(gs, "c11307")
	var hp: int = gs.player(0).units[1].hp
	gs._damage_unit(0, 1, 3, 1, 0)
	check(gs.player(0).units[1].hp == hp, "awakened mountain rejects enemy noncombat damage")
	gs = fixture()
	check(ContentLoader.card_def("c11007").target == "enemy-unit", "kai selects an enemy unit instead of hitting avatar")
	_content()
	_mountain()
	_archer()
	_delayed_and_ai()
	_shared_keywords()
	print("ARCHER_MOUNTAIN checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _content() -> void:
	for prefix in ["c110", "c113"]:
		for n in range(1, 9):
			var id: String = prefix + "%02d" % n
			var c := ContentLoader.card_def(id)
			check(c.get("verifiedRules", false), id + " native rules")
			check(not "简化" in c.text and not "简化" in str(c.get("formAbility", "")), id + " no numeric substitutes")
	check(ContentLoader.card_def("c11005").type == "spell" and ContentLoader.card_def("c11307").type == "spell", "both awakenings are spells")
	check(ContentLoader.unit_def("bailang").passive.hooks.is_empty() and ContentLoader.unit_def("shantong").passive.hooks.is_empty(), "fake after-combat avatar damage hooks removed")

func _mountain() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[1]
	play(gs, "c11302")
	check(u.attack == 4 and gs.player(1).avatarHp == 26, "permanent power precedes real attack")
	check(not gs.player(0).attackUsed and gs.player(0).energy == 39, "combat card uses no basic attack allowance")
	play(gs, "c11304")
	check(u.attack == 6 and u.maxHp == 9, "form body replaces instead of adding and retains permanent power")
	gs._knockout_unit(u)
	check(u.attack == 4 and u.maxHp == 4 and u.form.is_empty(), "knockout removes form but keeps permanent growth")
	gs._begin_turn(0)
	gs._begin_turn(0)
	check(u.hp == 4 and u.attack == 4, "permanent growth survives natural revival")
	gs = fixture()
	u = gs.player(0).units[1]
	play(gs, "c11303")
	check(gs.player(0).units[0].attack == 4 and u.attack == 4, "roar buffs living party")
	gs._knockout_unit(u)
	check(u.attack == 3, "ordinary roar is not permanent growth")
	gs = fixture()
	u = gs.player(0).units[1]
	play(gs, "c11301")
	check(u.attack == 3 and u.maxHp == 5, "reckless corrected 3/5")
	check(gs.end_turn(0) and gs.end_turn(1), "reach auto attack turn")
	check(gs.player(1).avatarHp == 27 and gs.player(0).energy == 2 and not gs.player(0).attackUsed, "reckless really attacks without resources")
	check(u.attack == 3, "reckless does not invent growth")
	gs = fixture()
	play(gs, "c11301")
	gs.player(0).units[1].frozen = 2
	gs.end_turn(0)
	gs.end_turn(1)
	check(gs.player(1).avatarHp == 30, "stunned reckless cannot attack")
	gs = fixture()
	u = gs.player(0).units[1]
	play(gs, "c11304")
	gs.end_turn(0)
	check(u.attack == 0, "clumsy updates visible attack")
	u.front = 1
	give(gs, "c11308", 0)
	var before_hp: int = gs.player(1).units[1].hp
	gs.player(1).levelUpUsed = true
	gs.basic_attack(1, 1)
	check(gs.player(1).units[1].hp == before_hp, "clumsy negates response bonus as well")
	gs.end_turn(1)
	check(u.attack == 5, "clumsy power restored on owner turn")
	gs = fixture()
	var enemy: Dictionary = gs.player(1).units[0]
	enemy.front = 1
	enemy.shield = 30
	enemy.shieldExpires = 30
	play(gs, "c11305")
	check(enemy.hp == 0 and enemy.shield == 0 and gs.player(1).avatarHp == 29, "rockbreaker strips armor before damage and pierce")
	check(gs.player(0).units[1].hp == 3, "rockbreaker printed two armor mitigates three counter damage")
	gs = fixture()
	gs.player(1).avatarArmor = 20
	play(gs, "c11305")
	check(gs.player(1).avatarHp == 25 and gs.player(1).avatarArmor == 0, "rockbreaker also strips avatar armor")
	gs = fixture()
	gs.player(0).units[1].permanentAttack = 2
	gs._recalc(gs.player(0).units[1])
	gs.player(1).units[0].front = 1
	var card := gs.hand_card_def(0, give(gs, "c11306"))
	check(card.value.front == 6 and card.value.reserve == 3, "collapse visible dynamic enhancement")
	gs.play_card(0, 0)
	check(gs.player(1).units[0].hp == 0 and gs.player(1).units[1].hp == 1, "collapse differentiates front and reserve")
	check(gs.player(1).avatarHp == 30, "mountain passive does not grant spell pierce")
	gs = fixture()
	play(gs, "c11307")
	u = gs.player(0).units[1]
	u.barrier = true
	u.shield = 2
	gs._damage_unit(0, 1, 10, 1, 0)
	check(not u.barrier and u.shield == 2 and u.hp == 4, "barrier consumed before noncombat immunity")
	gs._damage_unit(0, 1, 10, 1, 0)
	check(u.shield == 2 and u.hp == 4, "immunity preserves armor")
	gs._damage_unit(0, 1, 3, 0, 0)
	check(u.hp == 3, "friendly noncombat damage remains legal")
	gs._damage_unit(0, 1, 2, 1, 0, true)
	check(u.hp == 1, "enemy combat damage not immune")
	gs._knockout_unit(u)
	check(u.hp == 0, "direct destroy is not damage")
	gs = fixture()
	gs.player(1).units[1].front = 1
	give(gs, "c11308", 1)
	gs.basic_attack(0, 0)
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 39, "opportunity auto response consumes card and fire")
	check(gs.player(0).units[0].hp == 0 and gs.player(0).avatarHp == 27, "response adds four power and defensive pierce")
	gs = fixture()
	gs.player(1).units[1].front = 1
	gs.player(0).units[0].hp = 1
	gs.basic_attack(0, 0)
	check(gs.player(0).avatarHp == 30, "innate pierce does not apply to ordinary counterattack")

func _archer() -> void:
	var gs := fixture()
	var unit: Dictionary = gs.player(0).units[0]
	var enemy: Dictionary = gs.player(1).units[1]
	enemy.front = 1
	enemy.attack = 0
	play(gs, "c11003")
	check(enemy.hp == 2 and gs.player(1).avatarHp == 26, "bunsha two separate hits each trigger passive")
	check(unit.shield == 2 and unit.hp == 4, "bunsha supplies printed armor")
	gs = fixture()
	enemy = gs.player(1).units[1]
	enemy.front = 1
	enemy.hp = 1
	play(gs, "c11003")
	check(gs.player(1).avatarHp == 28 and gs.player(0).units[0].hp == 4, "early lethal stops normal hit and counter without phantom face damage")
	gs = fixture()
	enemy = gs.player(1).units[1]
	enemy.front = 1
	enemy.shield = 2
	enemy.barrier = true
	play(gs, "c11003")
	check(gs.player(1).avatarHp == 30 and enemy.hp == 4, "barrier and armor-only hits do not trigger archer ability")
	gs = fixture()
	unit = gs.player(0).units[0]
	play(gs, "c11001")
	check(unit.attack == 5 and gs.player(0).energy == 40, "new bow instant two power")
	gs.player(1).units[1].front = 1
	gs.player(1).units[1].barrier = true
	gs.player(1).units[1].shield = 20
	gs.basic_attack(0, 0)
	check(gs.player(1).units[1].hp == 0 and not gs.player(1).units[1].barrier, "penetration removes barrier and armor before damage")
	check(unit.attack == 3 and not unit.has("untilAttack"), "temporary bow ends after attack")
	gs = fixture()
	unit = gs.player(0).units[0]
	play(gs, "c11002")
	gs.end_turn(0)
	gs.end_turn(1)
	check(unit.attack == 6, "spell enhancement persists until actual attack across turns")
	gs = fixture()
	unit = gs.player(0).units[0]
	play(gs, "c11004")
	play(gs, "c11001")
	gs.player(0).units[1].front = 1
	gs.player(1).units[1].front = 1
	gs.player(1).units[1].hp = 10
	gs.player(1).units[1].maxHp = 10
	var hp: int = unit.hp
	gs.basic_attack(0, 0)
	check(unit.front == 0 and gs.player(0).units[1].front == 1 and unit.hp == hp, "remote attacks from reserve without replacing ally or taking counter")
	check(unit.attack == 5 and unit.has("untilAttack"), "zanshin preserves spells after attack")
	gs.VerifiedRules.move_unit(gs, 0, unit)
	check(unit.front == 0, "remote cannot be moved into front")
	gs._knockout_unit(unit)
	check(unit.attack == 3 and unit.form.is_empty() and not unit.has("untilAttack"), "death clears remote form and spell enhancements")
	gs = fixture()
	unit = gs.player(0).units[0]
	play(gs, "c11006")
	gs.player(0).energy = 0
	check(gs.can_basic_attack(0, 0).ok, "no-self swift permits zero fire attack")
	gs.player(1).units[1].front = 1
	gs.player(1).units[1].attack = 10
	gs.basic_attack(0, 0)
	check(unit.hp == 1 and gs.player(1).avatarHp == 26, "no-self combines one-shot unyielding and real overflow plus passive")
	check(gs.player(0).attackUsed and unit.attack == 3 and not unit.has("untilAttack"), "buff ends after attack and swift grants no extra attack count")
	gs = fixture()
	play(gs, "c11006")
	gs.player(0).units[0].hp = 1
	gs._damage_unit(0, 0, 1, 1, 1)
	check(gs.player(0).units[0].hp == 0, "unyielding cannot save one hp")
	gs = fixture()
	gs.player(1).units[1].front = 1
	play(gs, "c11008")
	check(gs.player(1).units[1].hp == 1 and gs.player(1).avatarHp == 30, "cover uses real three power and is noncombat")
	gs = fixture()
	play(gs, "c11005")
	gs.player(1).units[1].front = 1
	play(gs, "c11008")
	check(gs.player(1).avatarHp == 26, "awakened passive includes actual noncombat damage")
	gs = fixture()
	gs.player(1).units[1].front = 1
	give(gs, "c11008", 1)
	gs.basic_attack(0, 1)
	check(gs.player(0).units[1].hp == 0 and gs.player(1).hand.is_empty(), "other ally attacked triggers cover before combat")
	check(gs.player(0).avatarHp == 30, "cover in opposing turn does not trigger white wolf passive")
	gs = fixture()
	gs.player(1).units[0].front = 1
	give(gs, "c11008", 1)
	gs.basic_attack(0, 1)
	check(gs.player(1).hand.size() == 1, "cover does not respond to white wolf herself")
	gs = fixture()
	unit = gs.player(0).units[0]
	play(gs, "c11002")
	gs.player(1).units[1].front = 1
	play(gs, "c11008")
	check(unit.attack == 6 and unit.has("untilAttack"), "cover is a spell and does not consume attack enhancement")

func _delayed_and_ai() -> void:
	var gs := fixture()
	var target: Dictionary = gs.player(1).units[1]
	var idx := give(gs, "c11007")
	var before := JSON.stringify(gs.snapshot())
	check(not gs.play_card(0, idx, "avatar-1"), "kai cannot choose avatar")
	check(gs.player(0).hand.size() == 1 and gs.player(0).energy == 40, "invalid target spends nothing")
	check(gs.play_card(0, idx, target.uid), "kai selects actual enemy")
	check(target.hp == 4 and gs.player(1).avatarHp == 30, "kai causes no immediate damage")
	check(gs.player(0).delayedShots.size() == 1, "one queued shot")
	var private_view: Dictionary = gs.VerifiedRules.Bailang.unit_view(gs, 0, 0, 0)
	var enemy_view: Dictionary = gs.VerifiedRules.Bailang.unit_view(gs, 0, 0, 1)
	check(private_view.has("privateShotHints") and "山童" in str(private_view.privateShotHints), "owner can inspect chosen target")
	check(not enemy_view.has("privateShotHints"), "enemy cannot inspect chosen target")
	var command: Dictionary = gs.command_log.back()
	check(gs.VerifiedRules.Bailang.public_command(command, 1).a.target == null and gs.VerifiedRules.Bailang.public_command(command, 0).a.target == target.uid, "presentation command conceals target only from opponent")
	gs.player(0).delayedShots = JSON.parse_string(JSON.stringify(gs.player(0).delayedShots))
	gs.end_turn(0)
	check(target.hp == 4, "does not resolve on enemy start")
	gs.end_turn(1)
	check(target.hp == 0 and gs.player(0).delayedShots.is_empty(), "serialized shot resolves once on next owner start")
	gs = fixture()
	target = gs.player(1).units[1]
	play(gs, "c11007", target.uid)
	gs._knockout_unit(target)
	gs.end_turn(0)
	gs.end_turn(1)
	check(gs.player(1).units[0].hp == 4 and gs.player(0).delayedShots.is_empty(), "dead target fizzles without retargeting")
	gs = fixture()
	play(gs, "c11005")
	target = gs.player(1).units[1]
	play(gs, "c11007", target.uid)
	gs.end_turn(0)
	gs.end_turn(1)
	check(gs.player(1).avatarHp == 26, "delayed own-turn damage triggers awakened ability")
	gs = fixture()
	give(gs, "c11007")
	var decision := AI._best_card(gs, 0)
	check(decision.ok and gs.valid_targets(0, gs.hand_card_def(0, 0)).has(decision.target), "AI chooses legal delayed-shot target")
	check(AI.take_action(gs, 0) and gs.player(0).delayedShots.size() == 1, "AI really casts targeted shot")
	gs = fixture()
	give(gs, "c11008")
	check(not AI._best_card(gs, 0).ok, "AI saves cover when enemy front empty")
	gs = fixture()
	give(gs, "c11305")
	gs.player(1).avatarArmor = 15
	check(AI.take_action(gs, 0) and gs.player(1).avatarHp == 25, "AI executes armor removal combat")

func _shared_keywords() -> void:
	# Neutral bodies isolate phase ordering from character-specific abilities.
	for defender_first in [false, true]:
		var gs := fixture()
		var a: Dictionary = gs.player(0).units[2]
		var d: Dictionary = gs.player(1).units[2]
		d.front = 1
		d.hp = 2
		d.attack = 9
		a.keywords = ["combo"]
		if defender_first: d.keywords = ["first-strike"]
		gs.basic_attack(0, 2)
		check(a.hp == 4 and d.hp == 0, "combo early lethal precedes defender first strike=%s" % defender_first)
	var gs := fixture()
	var a: Dictionary = gs.player(0).units[2]
	var d: Dictionary = gs.player(1).units[2]
	d.front = 1
	d.keywords = ["first-strike"]
	a.hp = 2
	gs.basic_attack(0, 2)
	check(a.hp == 0 and d.hp == 4, "defender first strike kills attacker before its damage")
	gs = fixture()
	a = gs.player(0).units[2]
	d = gs.player(1).units[2]
	d.front = 1
	d.hp = 2
	a.keywords = ["combo", "pierce"]
	gs.basic_attack(0, 2)
	check(gs.player(1).avatarHp == 26 and a.hp == 4, "combo pierce spills first hit and redirects second to avatar")
	gs = fixture()
	a = gs.player(0).units[2]
	d = gs.player(1).units[2]
	d.front = 1
	a.hp = 3
	d.hp = 3
	a.keywords = ["combo"]
	d.keywords = ["combo"]
	gs.basic_attack(0, 2)
	check(a.hp == 0 and d.hp == 0, "both combo first hits are simultaneous")
	gs = fixture()
	gs.player(0).units[2].keywords = ["combo"]
	gs.basic_attack(0, 2)
	check(gs.player(1).avatarHp == 24, "combo hits unguarded avatar twice")
	var hits: Array = gs.rule_events.filter(func(e): return e.kind == "combat-damage-resolved" and e.target == "")
	check(hits.size() == 2 and hits[0].step != hits[1].step, "avatar combo exposes separate damage beats to UI")
