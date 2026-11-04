extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("XUENV_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["xuenv", "xuetongzi", "panguan", "taohuayao"], ["xuenv", "yaodaoji", "bingyong", "shantong"], 106107)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	return gs
func give(gs: GS, id: String, owner: int = 0) -> int:
	gs.player(owner).hand.append({"instanceId": "xuenv-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null, owner: int = 0) -> void:
	check(gs.play_card(owner, give(gs, id, owner), target), "play " + id)
func snow_count(gs: GS, owner: int = 0) -> int:
	return gs.player(owner).hand.filter(func(c): return c.definitionId == "xueqiu").size()
func _initialize() -> void:
	var gs := fixture()
	check(gs.player(0).units[0].hp == 5 and gs.player(0).units[0].attack == 2, "2020 corrected base 2/5")
	play(gs, "c10604")
	check(gs.player(0).units[0].attack == 3 and gs.player(0).units[0].maxHp == 5, "2020 corrected snowstorm 3/5")
	gs = fixture()
	gs.VerifiedRules.Stun.apply(gs, 1, 1)
	check(snow_count(gs) == 1, "teammate stun produces snowball")
	gs.VerifiedRules.Stun.apply(gs, 1, 2)
	check(snow_count(gs) == 1, "per turn production cap")
	gs.turn_counter += 1
	gs.VerifiedRules.Stun.apply(gs, 1, -1)
	check(snow_count(gs) == 1, "avatar stun does not produce snowball")
	gs.VerifiedRules.Stun.apply(gs, 1, 3)
	check(snow_count(gs) == 2, "actual turn changes production limit")
	gs = fixture()
	gs.player(0).units[0].level = 0
	gs.VerifiedRules.Stun.apply(gs, 1, 1)
	check(snow_count(gs) == 0, "inactive snow woman no passive")
	gs.player(0).units[0].level = 3
	gs._knockout_unit(gs.player(0).units[0])
	gs.VerifiedRules.Stun.apply(gs, 1, 2)
	check(snow_count(gs) == 0, "dead snow woman no passive")
	gs = fixture()
	var target: Dictionary = gs.player(1).units[1]
	play(gs, "c10603", target.uid)
	check(target.frozen == 1 and target.hp == target.maxHp and snow_count(gs) == 1, "collapse first stuns without damage")
	target.hp = 40; target.shield = 20; target.barrier = true
	play(gs, "c10603", target.uid)
	check(target.hp == 0 and int(gs.player(0).destroyedUnits) == 1, "collapse destroys stunned through HP armor and barrier")
	gs = fixture()
	play(gs, "c10603", gs.player(0).units[1].uid)
	check(gs.player(0).units[1].frozen == 2, "collapse permits friendly unit; own-turn stun lasts next turn")
	check(snow_count(gs, 1) == 0 and int(gs.player(1).get("enemyStuns", 0)) == 0, "self-inflicted friendly stun cannot award enemy snowball/history")
	gs = fixture()
	play(gs, "c10605", "avatar-1")
	check(gs.player(1).avatarHp == 27 and snow_count(gs) == 1, "blow snow hits avatar then grants token")
	play(gs, "c10610")
	check(snow_count(gs) == 3 and gs.player(0).snowballBonus == 1, "heart creates 2 tokens and permanent bonus")
	var first := gs.hand_card_def(0, 0)
	check(int(first.value) == 2 and gs.effective_card_cost(0, first) == 0, "already-held snowball updates and first instant free")
	check(not gs.can_play_card(0, 0, "avatar-1").ok, "manual snowball cannot target avatar")
	var energy: int = gs.player(0).energy
	check(gs.play_card(0, 0, gs.player(1).units[2].uid), "manual snowball plays")
	check(gs.player(0).snowballsPlayed == 1 and gs.player(0).energy == energy, "hand use counted and first instant free")
	check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 1, "second snowball costs one fire")
	play(gs, "c10610")
	check(gs.player(0).snowballBonus == 2 and int(gs.hand_card_def(0, 0).value) == 3, "heart stacks across all tokens")
	gs = fixture()
	play(gs, "c10606")
	target = gs.player(1).units[2]
	target.shield = 1
	play(gs, "xueqiu", target.uid)
	check(target.frozen == 0 and target.hp == target.maxHp, "armor-only snowball cannot awaken-stun")
	play(gs, "xueqiu", target.uid)
	check(target.frozen == 1 and snow_count(gs) == 1, "awaken damage stuns and produces token")
	check(gs.player(0).units[0].attack == 4 and gs.player(0).units[0].maxHp == 6, "awakening permanent +2/+1")
	gs._knockout_unit(gs.player(0).units[0])
	check(gs.player(0).units[0].awakened and gs.player(0).units[0].maxHp == 6, "awakening survives knockout")
	gs = fixture()
	play(gs, "c10604", null, 0)
	gs.current_player = 1
	check(gs.basic_attack(1, 2), "enemy basic attack")
	check(gs.player(1).units[2].hp == 5 and gs.player(1).units[2].frozen == 2 and snow_count(gs) == 1, "storm damages attacker after combat, own-turn stun 2")
	gs = fixture()
	play(gs, "c10604")
	gs.current_player = 1
	gs.player(1).units[2].shield = 1
	check(gs.basic_attack(1, 2), "armored enemy basic attack")
	check(gs.player(1).units[2].frozen == 0 and gs.player(1).units[2].hp == 6, "storm armor hit no stun")
	gs = fixture()
	gs.player(0).units[2].front = 1
	gs.player(0).units[2].hp = 10
	gs.player(0).units[2].maxHp = 10
	give(gs, "c10602")
	gs.current_player = 1
	check(gs.basic_attack(1, 1), "attack shield response")
	check(gs.player(0).energy == 39 and gs.player(0).units[2].hp == 9, "shield response pays and applies before damage")
	check(gs.player(1).units[1].frozen == 2 and snow_count(gs) == 1, "shield retaliatory damage stuns attacking unit")
	gs.VerifiedRules.Xuenv.end_turn(gs)
	check(not gs.player(0).units[2].has("snowCombatStunTurn"), "shield grant expires at actual turn end")
	gs = fixture()
	gs.player(0).units[2].front = 1
	var original: Array = gs.player(0).units.map(func(u): return u.uid)
	play(gs, "c10609")
	var wall: Dictionary = gs.front_unit(0)
	check(wall.get("iceWall", false) and wall.hp == 4 and wall.attack == 0 and gs.player(0).units[2].front == 0, "wall is real independent 0/4 front summon")
	check(gs.player(0).units.slice(0, 4).map(func(u): return u.uid) == original and gs.player(0).units[0].shield == 0, "wall never replaces original roster or grants fake armor")
	check(not gs.can_basic_attack(0, 4).ok and not gs.can_level_up(0, 4), "wall cannot attack or level up")
	check(gs.min_level(0) == 3, "wall does not distort upgrade minimum")
	gs.current_player = 1
	check(gs.basic_attack(1, 1), "enemy attacks wall")
	check(wall.hp == 1 and gs.player(1).units[1].frozen == 2 and gs.player(0).avatarHp == 30, "wall absorbs hit and stuns attacker")
	gs._begin_turn(0)
	check(wall.front == 1 and wall.hp == 1, "wall persists across owner's turn begin")
	gs.current_player = 0; gs.player(0).levelUpUsed = true; gs.player(0).energy = 20
	check(gs.basic_attack(0, 2), "original ally replaces wall")
	check(wall.hp == 0 and wall.removed and wall.knockout == 0, "replaced wall removed without resurrection countdown")
	check(not gs.valid_targets(0, ContentLoader.card_def("c10807")).has(wall.uid), "removed wall never offered as target")
	check(not gs.VerifiedRules.Peach.revive(gs, 0, 3, wall), "wall cannot be revived directly")
	gs = fixture()
	play(gs, "c10609")
	wall = gs.front_unit(0)
	gs.player(1).units[1].attack = 6
	gs.current_player = 1
	check(gs.basic_attack(1, 1), "enemy destroys wall")
	check(wall.hp == 0 and wall.knockout == 0 and gs.player(1).units[1].frozen == 2, "lethal hit still triggers wall stun but never revives wall")
	gs = fixture()
	play(gs, "c10609")
	wall = gs.front_unit(0)
	gs._damage_unit(0, 4, 2, 1, 1, false)
	check(wall.hp == 2 and gs.player(1).units[1].frozen == 0, "spell damage to wall never stuns source")
	play(gs, "c10609")
	check(wall.removed and gs.front_unit(0).hp == 4 and gs.player(0).units.size() == 6, "new wall replaces prior without slot reuse")
	gs = fixture()
	gs.player(0).snowballsPlayed = 3
	gs.player(0).snowballBonus = 1
	give(gs, "xueqiu")
	energy = int(gs.player(0).energy)
	play(gs, "c10607", "avatar-1")
	check(gs.player(1).avatarHp == 22 and gs.player(0).energy == energy - 1, "modern flurry performs four separate 2-damage casts and costs fire")
	check(gs.player(0).snowballsPlayed == 3 and snow_count(gs) == 1 and not gs.kw_usage(0, "instant").used, "flurry neither consumes hand nor inflates hand history nor spends instant")
	check(gs.rule_events.filter(func(e): return e.kind == "automatic-card" and e.card.id == "xueqiu").size() == 4, "flurry emits four actual automatic card events")
	gs = fixture()
	gs.player(0).snowballsPlayed = 2
	target = gs.player(1).units[2]; target.barrier = true
	play(gs, "c10607", target.uid)
	check(target.hp == 4 and not target.barrier, "separate flurry hits break only one barrier")
	gs = fixture()
	give(gs, "c10607")
	gs.player(0).snowballsPlayed = 29
	var best: Dictionary = AI._best_card(gs, 0)
	check(best.get("target") == "avatar-1", "AI selects lethal flurry avatar target")
	check(gs.play_card(0, 0, best.target), "long-history flurry executes")
	check(gs.winner == 0 and gs.player(1).avatarHp == 0, "30 sequential snowballs avoid stack limit and finish lethal")
	print("XUENV checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("XUENV_RULES_OK")
	quit(0 if failures == 0 else 1)
