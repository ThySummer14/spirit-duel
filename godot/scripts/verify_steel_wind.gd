extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
const Rules := preload("res://scripts/verified_card_rules.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
var checks := 0
var failures := 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("STEEL_WIND_FAIL ", message)

func _fixture() -> GameState:
	var gs := GameState.create(["datiangou-gangfeng", "basalt", "lumen", "rime"], ["basalt", "lumen", "rime", "ember"], 29002)
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		p.avatarHp = 100
		p.maxAvatarHp = 100
		for u in p.units:
			u.level = 3
			u.passive_hooks = []
			u.shield = 0
			u.attack = 3
			u.hp = 30
			u.maxHp = 30
	return gs

func _play(gs: GameState, id: String, target = null) -> void:
	gs.player(0).hand.append({"instanceId": "verify-%d" % gs.command_log.size(), "definitionId": id})
	_check(gs.play_card(0, gs.player(0).hand.size() - 1, target), "play " + id)

func _casts(gs: GameState) -> Array:
	return gs.rule_events.filter(func(e): return e.kind == "automatic-card")

func _initialize() -> void:
	_leaf()
	_origins()
	_origin_choices()
	_forms()
	_realm()
	_combat_damage()
	_responses()
	_replay()
	print("STEEL_WIND checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("STEEL_WIND_OK")
	quit(0 if failures == 0 else 1)

func _leaf() -> void:
	var gs := _fixture()
	var p := gs.player(0)
	var uid: String = p.units[1].uid
	p.units[2].front = 1
	var deck_size: int = p.deck.size()
	var foe := gs.player(1).duplicate(true)
	_play(gs, "c29002", uid)
	_check(gs.front_index(0) == 1 and p.units[2].front == 0, "reserve moves to front and displaces previous occupant")
	_check(p.hand.size() == 1 and p.deck.size() == deck_size - 1, "no countdown draws exactly one")
	_check(int(p.energy) == 20 and not p.attackUsed, "first instant and movement use neither energy nor attack opportunity")
	_check(gs.player(1) == foe and int(p.units[1].shield) == 0, "movement does not attack or grant invented armor")
	_play(gs, "c29002", uid)
	_check(gs.front_index(0) == -1 and int(p.energy) == 19, "second instant costs one and front moves back")
	p.units[1].hp = 0
	_check(not gs.valid_targets(0, ContentLoader.card_def("c29002")).has(uid), "cannot move knocked-out target")
	_check(not gs.valid_targets(0, ContentLoader.card_def("c29002")).has(gs.player(1).units[0].uid), "cannot move enemy")
	gs = _fixture()
	_play(gs, "c29001")
	var unit: Dictionary = gs.player(0).units[0]
	_check(int(unit.spellCountdown.remaining) == 2, "combat attaches true countdown")
	var held: int = gs.player(0).hand.size()
	_play(gs, "c29002", unit.uid)
	_check(int(unit.spellCountdown.remaining) == 1 and gs.player(0).hand.size() == held, "countdown target reduces once without drawing")
	_play(gs, "c29002", unit.uid)
	_check(_casts(gs).size() == 1 and int(unit.spellCountdown.remaining) == 2, "reaching zero automatically casts and resets")

func _origins() -> void:
	for id in ["c29001", "c29004", "c29005", "c29007"]:
		var gs := _fixture()
		var unit: Dictionary = gs.player(0).units[0]
		gs.player(1).units[0].front = 1
		_play(gs, id, gs.player(1).units[1].uid if id == "c29005" else null)
		var expected: String = ContentLoader.card_def(id).originCard.id
		_check(str(unit.spellCountdown.card.id) == expected, "correct origin for " + id)
		Rules.reduce_countdown(gs, 0, 0, 9)
		gs._resolve_resolution_stack()
		_check(_casts(gs).size() == 1 and int(unit.spellCountdown.remaining) == 2, "overflow triggers once, discards excess for " + id)
		_check(gs.response_window.is_empty(), "automatic origin creates no response prompt")
	var gs := _fixture()
	var enemy := gs.player(1)
	enemy.units[0].front = 1
	_play(gs, "c29005", enemy.units[1].uid)
	_check(int(enemy.units[0].hp) == 30 and int(enemy.units[1].hp) == 25, "pursuit hits selected reserve despite enemy front")
	_check(int(gs.player(0).units[0].hp) == 28, "updated steel feather has armor but no first-strike immunity")
	gs = _fixture()
	enemy = gs.player(1)
	enemy.units[0].front = 1
	enemy.units[0].hp = 2
	_play(gs, "c29004")
	_check(int(gs.player(0).units[0].hp) == 30, "lethal extra first hit prevents retaliation")
	gs = _fixture()
	enemy = gs.player(1)
	enemy.units[0].front = 1
	_play(gs, "c29004")
	_check(int(enemy.units[0].hp) == 24 and int(gs.player(0).units[0].hp) == 27, "combo vs surviving unit has two hits and one counter")
	gs = _fixture()
	_play(gs, "c29004")
	_check(int(gs.player(1).avatarHp) == 97, "combo does not double avatar damage")
	gs = _fixture()
	_play(gs, "c29007")
	_check(int(gs.player(1).avatarHp) == 92 and _casts(gs).size() == 1, "avatar hit accelerates origin, whose three damage includes the avatar")
	_check(gs.player(1).units.all(func(u): return int(u.hp) == 27), "blade origin really damages every living enemy by three")
	gs = _fixture()
	enemy = gs.player(1)
	enemy.units[0].front = 1
	enemy.units[0].shield = 10
	_play(gs, "c29001")
	Rules.reduce_countdown(gs, 0, 0, 2)
	gs._resolve_resolution_stack()
	_check(gs.front_index(1) == 0 and int(enemy.units[0].hp) == 30, "fan cannot displace through fully absorbing armor")
	enemy.units[0].shield = 0
	Rules.reduce_countdown(gs, 0, 0, 2)
	gs._resolve_resolution_stack()
	_check(gs.front_index(1) == -1 and int(enemy.units[0].hp) == 28, "fan displaces only the damaged living front")
	# Replacement, preservation through knockout, suspension, revival and ticking.
	gs = _fixture()
	_play(gs, "c29001")
	_play(gs, "c29004")
	var unit: Dictionary = gs.player(0).units[0]
	_check(str(unit.spellCountdown.card.name) == "天狗风乱", "new combat replaces old countdown")
	gs._damage_unit(0, 0, 999, 1)
	_check(not unit.spellCountdown.is_empty(), "steel origin survives knockout")
	gs._begin_turn(0)
	_check(int(unit.spellCountdown.remaining) == 2 and int(unit.knockout) == 1, "preserved ability timer pauses while knocked out")
	gs._begin_turn(0)
	_check(int(unit.hp) > 0 and int(unit.spellCountdown.remaining) == 1, "natural revival precedes the once-per-turn ability tick")
	gs._begin_turn(0)
	_check(int(unit.spellCountdown.remaining) == 2 and _casts(gs).size() == 1, "living countdown triggers and resets at owner's turn start")

func _origin_choices() -> void:
	var gs := _fixture()
	var unit: Dictionary = gs.player(0).units[0]
	gs.player(1).units[0].front = 1
	gs.player(1).units[0].hp = 4
	gs.player(0).hand.append({"instanceId":"manual-origin", "definitionId":"c29005"})
	var held: int = gs.player(0).hand.size()
	_check(gs.play_card(0, 0, null, true), "hand card can be used as its origin")
	_check(int(gs.player(1).units[0].hp) == 0 and gs.player(0).hand.size() == held, "black feather deals four and draws exactly once on kill")
	_check(int(gs.player(0).energy) == 19 and int(unit.hp) == 30 and int(unit.shield) == 0, "origin consumes one card and one energy, does not attack or add combat armor")
	_check(unit.get("spellCountdown", {}).is_empty(), "manual origin is a spell, does not install combat countdown")
	_check(gs.command_log[0].a.get("origin", false), "command stores selected origin for deterministic replay")
	gs = _fixture()
	gs.player(0).hand.append({"instanceId":"manual-origin", "definitionId":"c29005"})
	_check(gs.play_card(0, 0, null, true), "origin can hit an empty front")
	_check(int(gs.player(1).avatarHp) == 96 and gs.player(0).hand.is_empty(), "avatar damage does not award kill draw")
	gs = _fixture()
	gs.player(1).units[0].front = 1
	gs.player(1).units[0].shield = 4
	gs.player(0).hand.append({"instanceId":"manual-origin", "definitionId":"c29005"})
	_check(gs.play_card(0, 0, null, true), "origin against armor")
	_check(int(gs.player(1).units[0].hp) == 30 and gs.player(0).hand.is_empty(), "armor absorption does not award kill draw")
	gs = _fixture()
	gs.player(0).hand.append({"instanceId":"pursuit", "definitionId":"c29005"})
	_check(gs.valid_targets(0, ContentLoader.card_def("c29005")).has("avatar-1"), "pursuit may attack avatar when front is empty")
	_check(gs.play_card(0, 0, "avatar-1") and int(gs.player(1).avatarHp) == 95, "pursuit avatar combat resolves normally")
	gs = _fixture()
	gs.player(1).units[0].front = 1
	gs.player(0).hand.append({"instanceId":"pursuit", "definitionId":"c29005"})
	_check(not gs.can_play_card(0, 0, "avatar-1").ok, "pursuit cannot bypass front to hit avatar")
	gs.player(0).units[0].frozen = 1
	_check(not gs.can_play_card(0, 0, null, true).ok, "stun also prevents selecting origin spell")
	gs = _fixture()
	_play(gs, "c29006")
	gs.player(0).hand.append({"instanceId":"origin-form", "definitionId":"c29001"})
	_check(gs.play_card(0, gs.player(0).hand.size() - 1, null, true), "manual origin with justice form")
	_check(gs.player(0).units[0].get("barrier", false), "manual origin triggers true spell-based barrier")

func _forms() -> void:
	var gs := _fixture()
	var unit: Dictionary = gs.player(0).units[0]
	_play(gs, "c29003", gs.player(0).units[1].uid)
	_check(int(unit.attack) == 3 and int(unit.maxHp) == 4 and int(unit.hp) == 4, "form uses printed base 3/4, not +3/+4")
	_check(int(gs.player(0).units[1].shield) == 2 and int(unit.shield) == 0, "entry armor goes to selected ally")
	_play(gs, "c29001")
	_check(gs.end_turn(0), "end turn")
	_check(int(unit.spellCountdown.remaining) == 1, "armored ally countdown ticks at own turn end")
	gs = _fixture()
	unit = gs.player(0).units[0]
	_play(gs, "c29006")
	_check(int(unit.attack) == 3 and int(unit.maxHp) == 6, "justice uses printed 3/6")
	_play(gs, "c29002", unit.uid)
	_check(unit.barrier and int(unit.shield) == 0, "spell grants barrier, not armor")
	unit.shield = 5
	unit.brittle = 1
	gs._damage_unit(0, 0, 99, 1)
	_check(not unit.barrier and int(unit.hp) == 6 and int(unit.shield) == 5 and int(unit.brittle) == 1, "barrier absorbs full next damage before armor and brittle")
	_play(gs, "c29001")
	_check(int(unit.spellCountdown.remaining) == 1, "combat installs origin before justice reduces timer")
	Rules.reduce_countdown(gs, 0, 0, 1)
	gs._resolve_resolution_stack()
	_check(unit.barrier, "automatically used origin is a spell for justice")
	_play(gs, "c29003", unit.uid)
	_check(not unit.formRules.get("barrierOnSpell", false), "form switch removes old ability")
	gs._damage_unit(0, 0, 99, 1) # barrier
	gs._damage_unit(0, 0, 99, 1)
	_check(unit.form.is_empty() and unit.formRules.is_empty(), "knockout removes form but preserves awakened origin")

func _realm() -> void:
	var gs := _fixture()
	var unit: Dictionary = gs.player(0).units[0]
	_play(gs, "c29008")
	_check(unit.awakened and int(unit.attackBonus) == 0, "realm awakens without invented stat gain")
	_check(gs.player(0).realms.size() == 1 and int(gs.player(0).realms[0].hp) == 6, "true six durability illusion")
	_play(gs, "c29001")
	_check(_casts(gs).size() == 1 and int(unit.spellCountdown.remaining) == 1, "realm's first hand play reduces newly attached awakened origin")
	_play(gs, "c29001")
	_check(_casts(gs).size() == 1, "same turn second hand play cannot retrigger realm")
	gs._damage_avatar(0, 6, 1)
	_check(gs.player(0).realms.is_empty() and unit.awakened, "avatar damage destroys realm while awakening remains")
	var before: int = _casts(gs).size()
	gs.turn_counter += 1
	_play(gs, "c29001")
	_check(_casts(gs).size() == before, "destroyed realm stops ticking hand plays")
	gs = _fixture()
	_play(gs, "c29008")
	_play(gs, "c29002", gs.player(0).units[1].uid)
	_play(gs, "c29001")
	_check(_casts(gs).is_empty(), "once per turn consumed even if first user's unit has no countdown")

func _replay() -> void:
	var first := _fixture()
	var second := _fixture()
	for gs in [first, second]:
		_play(gs, "c29004")
		Rules.reduce_countdown(gs, 0, 0, 2)
		gs._resolve_resolution_stack()
	_check(first.players == second.players and first.rng_state == second.rng_state, "six random points and all state are deterministic")
	var total := 0
	for u in first.player(1).units: total += 30 - int(u.hp)
	total += 97 - int(first.player(1).avatarHp) # combat already dealt three
	_check(total == 6, "random storm distributes exactly six damage points")
	var raw := JSON.stringify(first.snapshot())
	var restored = JSON.parse_string(raw)
	_check(restored.players[0].units[0].spellCountdown.card.id == first.player(0).units[0].spellCountdown.card.id, "countdown payload and source survive JSON snapshot")

func _combat_damage() -> void:
	for pierce in [false, true]:
		var gs := _fixture()
		gs.player(1).units[0].front = 1
		gs.player(1).units[0].hp = 2
		gs.player(1).units[0].shield = 1
		gs._resolve_combat(0, 0, 2, pierce, false, false, false)
		_check(int(gs.player(1).avatarHp) == (98 if pierce else 100), "knockout adds no avatar damage; pierce deals only two real overflow")
	var gs := _fixture()
	gs.player(1).units[0].front = 1
	gs.player(1).units[0].hp = 1
	_play(gs, "c29007")
	_check(int(gs.player(1).avatarHp) == 100 and _casts(gs).is_empty(), "killing a shikigami does not count as storm hitting the avatar")

func _responses() -> void:
	var gs := _fixture()
	gs.player(1).hand = [{"instanceId":"response-1", "definitionId":"hoar-barrier"}]
	gs.player(1).units[0].front = 1
	_play(gs, "c29001")
	_check(not gs.response_window.is_empty(), "ordinary combat still opens legal response window")
	_check(int(gs.player(0).units[0].spellCountdown.remaining) == 2 and int(gs.player(1).units[0].hp) == 30, "origin attached once before paused combat")
	_check(gs.play_card(1, 0, gs.player(1).units[0].uid), "defender can play targeted response")
	var guard := 0
	while not gs.response_window.is_empty() and guard < 10:
		guard += 1
		gs.pass_response(int(gs.response_window.playerIndex))
	_check(gs.resolution_stack.is_empty() and int(gs.player(0).units[0].spellCountdown.remaining) == 2, "response continuation does not attach or tick countdown twice")
	_check(gs.rule_events.filter(func(e): return e.kind == "countdown-set").size() == 1, "single origin assignment across LIFO response")
