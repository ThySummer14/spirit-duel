extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Native := preload("res://scripts/dog_demon_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DOG_DEMON_FAIL ", message)
func fixture() -> GS:
	var gs := GS.create(["quanshen", "caitongzi", "taohuayao", "yingcao"], ["quanshen", "caitongzi", "taohuayao", "yingcao"], 311121)
	gs.phase = "main"
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs
func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId": "dog-demon-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1
func play(gs: GS, id: String, target = null) -> bool:
	return gs.play_card(0, give(gs, 0, id), target)
func _initialize() -> void:
	_opening_dog()
	_training()
	_forms()
	_rebirth()
	_guard()
	_strength()
	_pull()
	_chain()
	_wrath()
	_ai()
	_summon_contract()
	_serialized_chain()
	print("DOG_DEMON checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("DOG_DEMON_OK")
	quit(0 if failures == 0 else 1)
func _training() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	for unit in p.units: unit.level = 0
	p.levelUpUsed = false
	check(gs.level_up(0, 0), "first level")
	check(p.hand.size() == 1 and p.hand[0].definitionId == "xinshen-lianmo", "0 to 1 produces training")
	check(gs.play_card(0, 0), "training playable")
	check(p.units[0].attack == 3 and p.units[0].maxHp == 6 and p.energy == 39, "training permanently grows once and costs fire")
	gs._knockout_unit(p.units[0])
	check(p.units[0].attack == 3 and p.units[0].maxHp == 6, "training survives knockout")
	p.units[0].level = 0
	p.levelUpUsed = false
	check(gs.level_up(0, 0), "knocked dog may level")
	check(p.hand.size() == 1, "knocked dog receives training")
	check(not gs.can_play_card(0, 0).ok, "knocked dog cannot train")
	p.units[0].awakened = true
	p.units[0].level = 0
	p.levelUpUsed = false
	gs.level_up(0, 0)
	check(p.hand.size() == 1, "awakening replaces original upgrade ability")
func _forms() -> void:
	var gs := fixture()
	var dog: Dictionary = gs.player(0).units[0]
	check(play(gs, "xinshen-lianmo"), "first training")
	check(play(gs, "c12108"), "training form")
	check(dog.attack == 5 and dog.hp == 10, "4/9 form retains permanent +1/+1")
	var idx := give(gs, 0, "c12102")
	var view := gs.hand_card_def(0, idx)
	check(view.value == 1 and view.combatOption.shield == 3, "form buffs combat power and armor")
	check(play(gs, "xinshen-lianmo"), "late training")
	view = gs.hand_card_def(0, idx)
	check(view.value == 1 and view.combatOption.shield == 3, "played form retains entry snapshot")
	check(play(gs, "c12108"), "replace training form")
	view = gs.hand_card_def(0, idx)
	check(view.value == 2 and view.combatOption.shield == 4, "new form reads new history")
	check(play(gs, "c12105"), "instant form")
	view = gs.hand_card_def(0, idx)
	check(view.value == 0 and view.keywords.has("instant"), "replacing training form removes bonus and grants instant")
	var fire := int(gs.player(0).energy)
	check(gs.play_card(0, idx), "instant combat")
	check(gs.player(0).energy == fire and gs.kw_usage(0, "instant").used, "instant uses shared allowance")
	gs._knockout_unit(dog)
	check(dog.form.is_empty() and dog.attack == 4 and dog.maxHp == 7, "form removed on knockout, permanent training remains")
func _rebirth() -> void:
	var gs := fixture()
	var dog: Dictionary = gs.player(0).units[0]
	var idx := give(gs, 0, "c12103")
	check(not gs.can_play_card(0, idx).ok, "revive blocked for living source")
	gs._knockout_unit(dog)
	gs._knockout_unit(gs.player(0).units[1])
	check(not gs.can_play_card(0, idx, gs.player(0).units[1].uid).ok, "revive cannot select another ally")
	check(gs.play_card(0, idx), "knocked dog revives itself")
	check(dog.hp == 5 and gs.player(0).units[1].hp == 0, "full source-only revival")
	check(play(gs, "c12106"), "dog awakening")
	check(dog.attack == 3 and dog.maxHp == 6, "2021 awakening printed +1/+1")
	Native.end_turn(gs, 1)
	check(dog.attack == 3, "enemy end turn does not grow dog")
	Native.end_turn(gs, 0)
	check(dog.attack == 4 and dog.maxHp == 7, "living awakened dog grows at own end turn")
	gs._knockout_unit(dog)
	Native.end_turn(gs, 0)
	check(dog.hp == 8 and dog.maxHp == 8 and dog.attack == 5 and dog.knockout == 0, "dead dog revives before permanent growth")
	dog.hp = 1
	gs._grow_unit(dog, 0, 130)
	dog.hp = 1
	check(play(gs, "c12101") and dog.hp == dog.maxHp, "full healing has no 99 hp cap")
func _guard() -> void:
	for instant in [false, true]:
		var gs := fixture()
		var p: Dictionary = gs.player(1)
		var dog: Dictionary = p.units[0]
		var ally: Dictionary = p.units[2]
		var attacker: Dictionary = gs.player(0).units[1]
		attacker.attack = 4
		attacker.hp = 30
		ally.front = 1
		if instant: gs._apply_form(1, 0, Content.card_def("c12105"))
		p.energy = 0 if instant else 1
		give(gs, 1, "c12109")
		gs._resolve_combat(0, 1, 0, false, false, false, false)
		gs._resolve_resolution_stack()
		check(ally.hp == ally.maxHp and ally.front == 0 and dog.front == 1, "guard replaces target without damaging protected ally")
		check(dog.hp == dog.maxHp and dog.shield == 0, "guard armor applied before original attack")
		check(attacker.hp == 30 - int(dog.attack), "guard has one counterattack, no extra attack")
		check(p.hand.is_empty() and p.energy == 0, "guard consumes one response at actual fire cost")
		check(gs.kw_usage(1, "instant").get("used", false) == instant, "enemy-turn instant records usage")
	var gs := fixture()
	gs.player(1).units[0].front = 1
	give(gs, 1, "c12109")
	gs._resolve_combat(0, 1, 0, false, false, false, false)
	gs._resolve_resolution_stack()
	check(gs.player(1).hand.size() == 1, "guard cannot respond when dog itself attacked")
func _strength() -> void:
	var gs := fixture()
	var demon: Dictionary = gs.player(0).units[1]
	Native.turn_start(gs, 0, 1)
	check(demon.attack == 4, "demon base turn growth")
	check(play(gs, "c11103") and demon.attack == 7, "haoken exact +3")
	check(play(gs, "c11106") and demon.attack == 7 and demon.maxHp == 5, "awakening printed +0/+1")
	Native.turn_start(gs, 0, 1)
	check(demon.attack == 14, "awakening doubles current strength")
	gs._knockout_unit(demon)
	check(demon.attack == 3 and demon.demonPeakStrength == 14, "ordinary growth erased, peak history persists")
	gs.VerifiedRules.Peach.revive(gs, 0, 0, demon, false, false)
	check(play(gs, "c11107") and demon.attack == 14, "broken arm restores historic peak")
	Native.turn_start(gs, 0, 1)
	check(demon.attack == 28 and demon.demonPeakStrength == 28, "revived awakened demon continues doubling")
func _pull() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[2]
	var idx := give(gs, 0, "c11102")
	check(gs.hand_card_def(0, idx).target == "enemy-reserve-unit", "ghost hand opens reserve selection for empty front")
	check(not gs.can_play_card(0, idx).ok, "ghost hand requires valid pull target")
	check(gs.play_card(0, idx, enemy.uid), "ghost hand pulls selected unit")
	check(enemy.front == 1 and enemy.hp == enemy.maxHp - 3 and gs.player(1).avatarHp == 30, "pull then real combat, no fake +2 or face damage")
	gs = fixture()
	enemy = gs.player(1).units[2]
	enemy.front = 1
	idx = give(gs, 0, "c11102")
	check(gs.hand_card_def(0, idx).target == "auto", "occupied front needs no pull selection")
	check(gs.play_card(0, idx), "occupied ghost hand attacks front")
	gs = fixture()
	for unit in gs.player(1).units: gs._knockout_unit(unit)
	idx = give(gs, 0, "c11102")
	check(not gs.can_play_card(0, idx).ok, "all enemy units knocked means ghost hand cannot be used")
func _chain() -> void:
	var gs := fixture()
	var demon: Dictionary = gs.player(0).units[1]
	demon.attackBonus = 3
	gs._recalc(demon)
	demon.hp = 30
	for unit in gs.player(1).units:
		unit.hp = 2
		unit.attack = 0
	gs.player(1).units[0].hp = 5
	gs.player(1).units[3].front = 1
	check(play(gs, "c11105", gs.player(1).units[0].uid), "hell hand pursuit selects reserve despite occupied front")
	check(gs.player(1).units.all(func(u): return int(u.hp) == 0), "hell hand chains until no living enemy")
	check(gs.player(1).avatarHp == 30 and demon.demonKills == 4, "chain attacks never fall through to avatar")
	check(gs.rule_events.filter(func(e): return e.kind == "demon-chain-attack").size() == 3, "exactly one extra attack for each continuing kill")
	gs = fixture()
	demon = gs.player(0).units[1]
	demon.attack = 8
	demon.hp = 1
	gs.player(1).units[0].attack = 8
	check(play(gs, "c11105", gs.player(1).units[0].uid), "lethal exchange")
	check(demon.hp == 0 and gs.player(1).units[1].hp > 0, "dead source cannot chain after simultaneous exchange")
func _wrath() -> void:
	var gs := fixture()
	check(play(gs, "c11104"), "wrath form")
	var demon: Dictionary = gs.player(0).units[1]
	check(demon.attack == 3 and demon.maxHp == 7, "wrath is 3/7 body")
	gs.player(1).units[0].front = 1
	gs.player(1).units[0].hp = 1
	gs.player(1).units[2].hp = 2
	gs.player(1).units[3].hp = 3
	gs._damage_unit(1, 0, 1, 0, 1)
	check(gs.player(1).units[2].hp == 0 and gs.player(1).units[3].hp == 1 and demon.demonKills == 2, "source-owned front kill splashes reserves and records secondary kills")
	check(gs.player(1).avatarHp == 30, "wrath never damages avatar")
	var before := int(gs.player(1).units[3].hp)
	gs._damage_unit(1, 1, 99, 0, 1)
	check(gs.player(1).units[3].hp == before, "reserve kill cannot splash again")
func _ai() -> void:
	var gs := fixture()
	var idx := give(gs, 0, "c12103")
	check(Native.score_card(gs, 0, gs.hand_card_def(0, idx), null) < 0, "AI will not revive living dog")
	gs._knockout_unit(gs.player(0).units[0])
	check(Native.score_card(gs, 0, gs.hand_card_def(0, idx), null) > 70 and gs.can_play_card(0, idx).ok, "AI can legally revive knocked dog")
	check(AI.take_action(gs, 0) and gs.player(0).units[0].hp == gs.player(0).units[0].maxHp, "actual AI action revives knocked dog")
	idx = give(gs, 0, "c11102")
	var card := gs.hand_card_def(0, idx)
	for target in gs.valid_targets(0, card): check(gs.can_play_card(0, idx, target).ok, "AI enumeration selects legal ghost hand target")

func _summon_contract() -> void:
	for shikigami in [false, true]:
		var gs := fixture()
		play(gs, "c11104")
		var target: Dictionary = gs.player(1).units[0]
		target.summoned = true
		target.countsAsShikigami = shikigami
		target.front = 1
		var before := int(gs.player(1).units[2].hp)
		gs._damage_unit(1, 0, 99, 0, 1)
		check(int(gs.player(0).units[1].get("demonKills", 0)) == (1 if shikigami else 0), "summon kill follows explicit shikigami contract")
		check(gs.player(1).units[2].hp == before - (2 if shikigami else 0), "ice wall qualifies for wrath, ordinary summon does not")
func _serialized_chain() -> void:
	var gs := fixture()
	var demon: Dictionary = gs.player(0).units[1]
	demon.attack = 20
	demon.hp = 50
	for unit in gs.player(1).units:
		unit.hp = 1
		unit.attack = 0
	var card := Content.card_def("c11105")
	var options: Dictionary = card.combatOption.duplicate(true)
	options.combatCard = card
	gs._resolve_combat(0, 1, 0, false, false, false, false, gs.player(1).units[0].uid, false, options)
	check(gs.resolution_stack.any(func(f): return f.kind == "demon-chain-attack"), "hell chain continuation is an explicit frame")
	gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
	gs._resolve_resolution_stack()
	check(gs.player(1).units.all(func(u): return int(u.hp) == 0), "serialized chain preserves targets, card context and continuation")

func _opening_dog() -> void:
	var gs := GS.create(["quanshen", "caitongzi", "taohuayao", "yingcao"], ["quanshen", "caitongzi", "taohuayao", "yingcao"], 121121)
	for owner in 2:
		check(gs.player(owner).hand.any(func(c): return c.definitionId == "xinshen-lianmo"), "initial 0 to 1 upgrade grants training")
	check(Content.card_def("c12103").keywords.has("instant"), "2021 revive gained instant")
