extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("JUDGE_TIDE_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["panguan", "haifangzhu", "yaodaoji", "taohuayao"], ["panguan", "haifangzhu", "yaodaoji", "bingyong"], 122117)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "judge-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func _initialize() -> void:
	_reproducer()
	_judge()
	_lethal()
	_tide()
	_ai_and_save()
	_attribution_and_lifecycle()
	_self_damage_source()
	print("JUDGE_TIDE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _reproducer() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[2]
	var idx := give(gs, "c12202")
	check(not gs.valid_targets(0, gs.hand_card_def(0, idx)).has(enemy.uid), "goujue rejects power greater than two")
	gs = fixture()
	enemy = gs.player(1).units[0]
	enemy.hp = 40
	enemy.maxHp = 40
	enemy.shield = 80
	enemy.barrier = true
	enemy.unyielding = true
	gs.player(0).avatarHp = 20
	play(gs, "c12202", enemy.uid)
	check(enemy.hp == 0 and gs.player(1).avatarHp == 29 and gs.player(0).avatarHp == 21, "true destruction bypasses protection and triggers judge once")
	gs = fixture()
	play(gs, "c12204")
	gs._damage_unit(1, 2, 20, 0, 2)
	check(gs.player(1).units[2].knockout == int(gs.rules.knockoutCountdown) + 1, "ruthless adds one to new enemy knockout")
	gs = fixture()
	var ally: Dictionary = gs.player(0).units[2]
	play(gs, "c11701", ally.uid)
	check(ally.shield == 3, "full health tide healing converts all three to armor")
	gs = fixture()
	play(gs, "c11703", gs.player(1).units[2].uid)
	check(gs.player(0).units[1].shield == 3, "modern water cyclone actually grants armor")

func _judge() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	var hand := give(gs, "c12202")
	check(not gs.play_card(0, hand, e.units[2].uid) and p.energy == 40 and p.hand.size() == 1, "invalid goujue preserves card and energy")
	check(not gs.valid_targets(0, gs.hand_card_def(0, hand)).has(p.units[0].uid), "goujue forbids friendly target")
	play(gs, "c12201", e.units[2].uid)
	check(e.units[2].attack == 1 and e.units[2].maxHp == 3 and e.units[2].hp == 3, "ink reduces current health, maximum and power")
	check(gs.valid_targets(0, gs.hand_card_def(0, hand)).has(e.units[2].uid), "ink brings high power target into goujue range")
	check(gs.play_card(0, hand, e.units[2].uid), "ink then goujue legal")
	check(e.units[2].attack == 3 and e.units[2].maxHp == 4 and not e.units[2].has("judgeInkAttack"), "ink ends at knockout")
	check(p.destroyedUnits == 1, "destruction counted once")
	gs._damage_unit(1, 2, 40, 0, 0)
	check(p.destroyedUnits == 1, "dead target not counted twice")
	gs = fixture()
	e = gs.player(1)
	e.units[2].hp = 1
	e.units[2].shield = 50
	e.units[2].barrier = true
	play(gs, "c12201", e.units[2].uid)
	check(e.units[2].hp == 0 and gs.player(0).destroyedUnits == 1, "ink health reduction is not absorbable damage")
	gs = fixture()
	p = gs.player(0)
	p.avatarHp = 20
	gs._damage_unit(1, 2, 30, 0, 1)
	check(p.destroyedUnits == 1 and p.avatarHp == 20 and gs.player(1).avatarHp == 30, "unawakened judge ignores teammate kill")
	play(gs, "c12207")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 5, "judge awakening body")
	gs._damage_unit(1, 3, 30, 0, 1)
	check(p.avatarHp == 21 and gs.player(1).avatarHp == 29 and p.destroyedUnits == 2, "awakening teammate kill triggers exactly one")
	play(gs, "c12205", p.units[2].uid)
	check(p.units[2].hp == 0 and p.destroyedUnits == 3 and p.avatarHp == 22, "death declaration can destroy friendly and attributes kill to judge")
	play(gs, "c12205", p.units[0].uid)
	check(p.destroyedUnits == 4 and p.avatarHp == 22, "dead judge does not trigger its own passive")
	var face := int(gs.player(1).avatarHp)
	gs._damage_avatar(1, 1, 0, 1)
	check(p.destroyedUnits == 4 and gs.player(1).avatarHp == face - 1, "avatar damage is not an extra destruction")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	play(gs, "c12204")
	check(p.units[0].attack == 4 and p.units[0].maxHp == 5, "ruthless replaces form body")
	gs._damage_unit(1, 2, 30, 0, 1)
	check(e.units[2].knockout == 3, "ruthless applies to friendly teammate kills")
	gs._knockout_unit(p.units[0])
	gs._damage_unit(1, 3, 30, 0, 1)
	check(e.units[2].knockout == 3 and e.units[3].knockout == 2, "aura removal affects future deaths only")
	gs = fixture()
	p = gs.player(0)
	var idx := give(gs, "c12203")
	check(not gs.can_play_card(0, idx).ok, "exchange cannot cast with empty fronts")
	p.units[2].front = 1
	check(not gs.can_play_card(0, idx).ok, "exchange cannot cast with one empty front")
	gs.player(1).units[2].front = 1
	p.avatarHp = 20
	check(gs.play_card(0, idx), "exchange both fronts legal")
	check(p.units[2].hp == 0 and gs.player(1).units[2].hp == 0 and p.destroyedUnits == 2, "exchange destroys both fronts")
	check(p.avatarHp == 22 and gs.player(1).avatarHp == 28, "reserve judge triggers twice for exchange")
	gs = fixture()
	play(gs, "c12204")
	gs.player(0).units[0].front = 1
	gs.player(1).units[2].front = 1
	play(gs, "c12203")
	check(gs.player(1).units[2].knockout == 3 and gs.player(1).avatarHp == 30, "exchange preserves departing aura but not dead passive")
	gs = fixture()
	gs.player(1).units[2].front = 1
	give(gs, "c12203", 1)
	check(gs.basic_attack(0, 2), "attack into exchange response")
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 39, "exchange response pays one fire")
	check(gs.player(0).units[2].hp == 0 and gs.player(1).units[2].hp == 0 and gs.player(1).destroyedUnits == 2, "response cancels interrupted combat after both die")
	gs = fixture()
	gs.player(0).units[2].keywords = ["remote"]
	gs.player(1).units[2].front = 1
	give(gs, "c12203", 1)
	gs.basic_attack(0, 2)
	check(gs.player(1).hand.size() == 1 and gs.player(0).units[2].hp == 4, "remote with no opposing front cannot trigger exchange")
	gs = fixture()
	gs.player(0).destroyedUnits = 6
	idx = give(gs, "c12206")
	check(gs.hand_card_def(0, idx).value.attack == 10 and "6个" in gs.hand_card_def(0, idx).text, "sentence live hand enhancement counts all kills")
	check(gs.play_card(0, idx) and gs.player(0).units[0].attack == 10 and gs.player(0).units[0].maxHp == 8, "sentence installs enhanced body")
	check(ContentLoader.card_def("c12206").value.attack == 4, "enhancement never mutates shared content")
	gs._knockout_unit(gs.player(0).units[0])
	check(gs.player(0).destroyedUnits == 6 and gs.player(0).units[0].attack == 2, "enhancement counter survives knockout while form does not")

func _lethal() -> void:
	for mode in ["normal", "armor", "barrier", "zero", "unyielding", "floor"]:
		var gs := fixture()
		var u: Dictionary = gs.player(0).units[0]
		var e: Dictionary = gs.player(1).units[1]
		e.hp = 30
		e.maxHp = 30
		e.attack = 0
		e.front = 1
		if mode == "armor": e.shield = 20
		if mode == "barrier": e.barrier = true
		if mode == "zero": u.attack = 0
		if mode == "unyielding": e.unyielding = true
		if mode == "floor":
			e.hp = 1
			e.shutenHowlTurn = gs.turn_counter
		play(gs, "c12208")
		check((e.hp == 0) == (mode in ["normal", "unyielding", "floor"]), "lethal condition " + mode)
		check(u.attack == (0 if mode == "zero" else 2), "lethal has no invented power bonus " + mode)
	for count in [12, 13]:
		for armored in [false, true]:
			var gs := fixture()
			gs.player(0).destroyedUnits = count
			if armored: gs.player(1).avatarArmor = 20
			var idx := give(gs, "c12208")
			check(gs.hand_card_def(0, idx).combatOption.lethalAvatar == (count >= 13), "lethal live progress threshold")
			gs.play_card(0, idx)
			check((gs.winner == 0) == (count >= 13 and not armored), "lethal avatar needs enhancement and actual damage")
	var gs := fixture()
	gs.player(1).units[1].front = 1
	gs.player(1).units[1].attack = 10
	play(gs, "c12208")
	check(gs.player(1).units[1].hp == 0 and gs.player(0).units[0].hp == 0, "lethal does not cancel simultaneous counterstrike")

func _tide() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var ally: Dictionary = p.units[2]
	ally.hp = 2
	play(gs, "c11701", ally.uid)
	check(ally.hp == 4 and ally.shield == 1 and p.energy == 40, "healing separates actual two and excess one; instant is free")
	p.units[1].shield = 5
	play(gs, "c11701", "avatar-0")
	check(p.avatarArmor == 5 and p.energy == 39, "armor scaling floors half and shared instant used")
	check(gs.valid_targets(0, ContentLoader.card_def("c11701")).size() == 10, "healing includes both avatars and all living units")
	gs.player(1).units[2].hp = 1
	play(gs, "c11701", gs.player(1).units[2].uid)
	check(gs.player(1).units[2].hp == 4 and gs.player(1).units[2].shield == 0, "enemy can heal but cannot get friendly overheal armor")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c11708")
	check(p.units[1].attack == 3 and p.units[1].maxHp == 9 and p.units[1].awakened, "tide awaken plus one plus three")
	p.units[2].armorBreak = 2
	play(gs, "c11704")
	check(p.units[2].shield == 1 and p.units[2].armorBreak == 0 and p.units[2].attack == 6, "overheal converts full excess to power independently of armor cancellation")
	check(p.avatarArmor == 3 and p.units[0].shield == 3 and p.units[1].attack == 6, "blessing affects avatar and every living ally")
	gs.end_turn(0)
	gs.end_turn(1)
	check(p.units[2].shield == 0 and p.units[2].attack == 6, "armor naturally expires while ordinary gained power persists")
	gs._knockout_unit(p.units[2])
	check(p.units[2].attack == 3, "ordinary overheal power ends at knockout")
	var armor := int(p.units[0].shield)
	gs.VerifiedRules.Tide.heal(gs, 0, 3, 0, 0, 10)
	check(p.units[0].shield == armor, "other healer cannot borrow Hai passive")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c11702")
	p.avatarHp = 29
	p.units[1].hp = 3
	play(gs, "c11701", "avatar-0")
	check(p.avatarHp == 30 and p.avatarArmor == 2 and p.units[1].hp == 4, "spirit mirrors actual avatar recovery once")
	play(gs, "c11701", "avatar-0")
	check(p.units[1].hp == 4, "no mirror for fully armored excess (pending original edge)")
	gs = fixture()
	p = gs.player(0)
	p.units[1].armorBreak = 2
	var idx := give(gs, "c11703")
	check("预计1" in gs.hand_card_def(0, idx).text, "cyclone preview includes armor cancellation")
	check(gs.play_card(0, idx, gs.player(1).units[2].uid), "cyclone legal target")
	check(p.units[1].shield == 1 and gs.player(1).units[2].hp == 3, "cyclone grants armor before calculating damage")
	gs = fixture()
	p = gs.player(0)
	p.units[1].hp = 2
	gs.player(1).units[0].barrier = true
	gs.player(1).units[1].shield = 2
	gs.player(1).units[2].hp = 1
	play(gs, "c11706")
	check(p.units[1].hp == 6 and p.units[1].shield == 0, "wave adds two unblocked hits including overkill then heals")
	check(gs.player(1).units[0].hp == 4 and gs.player(1).units[1].hp == 6 and gs.player(1).units[2].hp == 0, "wave respects barrier and armor on each target")
	gs = fixture()
	p = gs.player(0)
	play(gs, "c11705")
	p.avatarHp = 20
	p.units[1].hp = 5
	p.units[2].hp = 2
	gs.basic_attack(0, 1)
	check(p.avatarHp == 24 and p.units[2].hp == 4 and p.units[2].shield == 2 and p.units[1].hp == 5, "daohai heals avatar and others by damage, excludes self")
	gs = fixture()
	play(gs, "c11705")
	gs.player(1).avatarArmor = 40
	gs.basic_attack(0, 1)
	check(gs.player(0).units[0].shield == 0, "daohai ignores armor-only hits")
	gs = fixture()
	p = gs.player(0)
	p.avatarHp = 20
	play(gs, "c11707", p.units[2].uid)
	check(p.units[2].shield == 2, "shield armor applies immediately")
	gs.basic_attack(0, 2)
	check(p.avatarHp == 22, "shield grants two healing on real combat damage")
	gs.end_turn(0)
	check(p.units[2].tideCombatHeals.is_empty(), "shield ability expires at the end of cast turn")
	gs = fixture()
	gs.player(1).avatarHp = 20
	gs.player(1).units[2].front = 1
	give(gs, "c11707", 1)
	gs.basic_attack(0, 0)
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 39, "shield automatic response uses card and resource")
	check(gs.player(1).units[2].hp == 4 and gs.player(1).avatarHp == 22, "response armor blocks hit and counter heals avatar")

func _ai_and_save() -> void:
	var gs := fixture()
	give(gs, "c12202")
	var choice := AI._best_card(gs, 0)
	check(choice.ok and gs.valid_targets(0, gs.hand_card_def(0, choice.hand)).has(choice.target), "AI chooses legal low power kill")
	gs = fixture()
	give(gs, "c12205")
	choice = AI._best_card(gs, 0)
	check(choice.ok and not gs._unit_by_uid(gs.player(1).units, choice.target).is_empty(), "AI death declaration targets enemy")
	gs = fixture()
	give(gs, "c12203")
	check(not AI._best_card(gs, 0).ok, "AI skips illegal empty-front exchange")
	gs = fixture()
	give(gs, "c11701")
	choice = AI._best_card(gs, 0)
	check(choice.ok and (choice.target == "avatar-0" or not gs._unit_by_uid(gs.player(0).units, choice.target).is_empty()), "AI heals friendly side")
	play(gs, "c11708")
	play(gs, "c11707", gs.player(0).units[2].uid)
	gs.player(0).destroyedUnits = 12
	var restored = JSON.parse_string(JSON.stringify(gs.players))
	check(restored[0].destroyedUnits == 12 and restored[0].units[2].tideCombatHeals.size() == 1 and restored[0].units[1].awakened, "new statuses and progress survive JSON round trip")
	for seed_value in range(12):
		gs = GS.create(["panguan", "haifangzhu", "yaodaoji", "taohuayao"], ["panguan", "haifangzhu", "bailang", "shantong"], 90100 + seed_value)
		for turn in 180:
			if gs.winner >= 0: break
			AI.take_turn(gs, gs.action_player())
		check(gs.winner >= 0, "targeted AI match terminates seed %d" % seed_value)

func _attribution_and_lifecycle() -> void:
	var gs := fixture()
	gs.player(1).units[2].front = 1
	gs.player(1).units[2].hp = 1
	gs._card_effect_context = {"playerIndex": 0, "sourceIndex": 0, "definitionId": "c12201", "affectedUnits": []}
	gs._run_passive_effect(0, 1, "passive-damage-enemy-front", {"amount": 2}, {})
	check(gs.player(0).destroyedUnits == 1 and gs.player(1).avatarHp == 30, "nested ability retains real source instead of outer judge card")
	gs = fixture()
	play(gs, "c12201", gs.player(1).units[0].uid)
	gs.current_player = 1
	play(gs, "c12204", null, 1)
	check(gs.player(1).units[0].attack == 2 and gs.player(1).units[0].maxHp == 4, "ink survives form replacement")
	gs = fixture()
	gs.player(0).units[0].front = 1
	gs.player(1).units[0].front = 1
	play(gs, "c12204")
	gs.player(1).units[0].attack = 20
	gs.player(1).units[0].hp = 1
	# Run the opposing attack on its legal turn without triggering start phase.
	gs.current_player = 1
	check(gs.basic_attack(1, 0), "opposing attack legal")
	check(gs.player(0).units[0].hp == 0 and gs.player(1).units[0].hp == 0 and gs.player(1).units[0].knockout == 3, "mutual destruction snapshots ruthless before first death")
	gs = fixture()
	play(gs, "c11707", gs.player(0).units[2].uid)
	gs._knockout_unit(gs.player(0).units[2])
	check(not gs.player(0).units[2].has("tideCombatHeals"), "knockout clears shield temporary combat ability")
	gs = fixture()
	play(gs, "c11707", gs.player(0).units[2].uid)
	play(gs, "c11707", gs.player(0).units[2].uid)
	gs.player(0).avatarHp = 20
	gs.basic_attack(0, 2)
	check(gs.player(0).avatarHp == 24, "separately granted combat heal abilities both resolve")
	gs = fixture()
	gs.player(1).units[2].front = 1
	gs.player(1).units[2].hp = 30
	gs.player(1).units[2].maxHp = 30
	gs.VerifiedRules.Combat.strike(gs, 0, 0, 1, 2, 2, {"lethal": true, "convertCombatToArmorBreak": true})
	check(gs.player(1).units[2].hp == 30 and gs.player(1).units[2].armorBreak == 2, "damage converted to armor break cannot trigger lethal")

func _self_damage_source() -> void:
	var gs := fixture()
	gs.player(0).units[1].hp = 1
	gs.player(1).units[0].awakened = true
	gs._resolve_one_effect(0, 1, {"type": "spell"}, {"action": "damage-self", "value": 2, "target": "source"}, null, {})
	check(gs.player(0).get("destroyedUnits", 0) == 1 and gs.player(1).get("destroyedUnits", 0) == 0, "self inflicted knockout belongs to caster's player")
	check(gs.player(0).avatarHp == 30, "enemy judge cannot claim self inflicted knockout")
