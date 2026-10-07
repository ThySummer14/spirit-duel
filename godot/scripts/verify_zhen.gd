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
		printerr("ZHEN_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["zhen", "yaoginshi", "yimulian", "basalt"], ["zhen", "yaoginshi", "yimulian", "basalt"], 11609)
	for p in gs.players:
		p.hand.clear()
		p.energy = 20
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
			if unit.has("abilityCountdown"): unit.abilityCountdown.remaining = unit.abilityCountdown.reset
	return gs

func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId": "test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, id: String) -> void:
	check(gs.play_card(0, give(gs, 0, id)), "play " + id)

func _initialize() -> void:
	_core()
	_countdown()
	_status()
	_combat()
	_forms()
	_response()
	_ai()
	print("ZHEN checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("ZHEN_OK")
	quit(0 if failures == 0 else 1)

func _core() -> void:
	var gs := fixture()
	var source: Dictionary = gs.player(0).units[0]
	check(not Rules.Countdown.timer(source).is_empty(), "base ability has a real two-turn timer")
	var deck: int = gs.player(0).deck.size()
	play(gs, "c11602")
	check(int(gs.player(1).get("avatarArmorBreak", 0)) == 2 and gs.player(0).deck.size() == deck - 1, "revival reduces countdown then draws; no fixed substitute")
	gs._damage_avatar(1, 1, 0)
	check(gs.player(1).avatarHp == 27 and int(gs.player(1).get("avatarArmorBreak", 0)) == 0, "avatar break adds to one real hit and is consumed")
	gs = fixture()
	source = gs.player(0).units[0]
	var enemy: Dictionary = gs.player(1).units[3]
	enemy.front = 1
	enemy.attack = 4
	play(gs, "c11604")
	check(source.hp == 5 and enemy.hp == 12, "toxic combat converts both directions without HP damage")
	check(int(source.get("armorBreak", 0)) == 4 and int(enemy.get("armorBreak", 0)) == 6, "conversion keeps exact incoming and outgoing power")
	gs.player(0).avatarHp = 10
	play(gs, "c11608")
	check(gs.player(0).avatarHp == 20 and enemy.hp == 2, "conditional lifesteal includes detonated break")
	gs = fixture()
	play(gs, "c11607")
	check(gs.player(1).avatarHp == 28 and int(gs.player(1).get("avatarArmorBreak", 0)) == 14, "flower has no fabricated attack bonus and uses remaining health")
	gs = fixture()
	play(gs, "c11606")
	check(gs.player(0).units[0].attack == 5 and gs.player(0).units[0].hp == 7, "scatter installs printed body")
	check(gs.player(1).units.all(func(u): return int(u.get("armorBreak", 0)) == 0), "scatter does not invent enemy-team poison on entry")
	play(gs, "c11602")
	check(gs.player(1).avatarHp == 28 and int(gs.player(1).get("avatarArmorBreak", 0)) == 0, "scatter converts own countdown into damage even on unmarked target")

func tick(gs: GS, owner: int = 0, amount: int = 2) -> void:
	Rules.reduce_countdown(gs, owner, 0, amount)
	gs._resolve_resolution_stack()

func _countdown() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	check(u.abilityCountdown.remaining == 2, "newly inactive base starts at two")
	tick(gs, 0, 1)
	check(gs.player(1).avatarArmorBreak == 0 and u.abilityCountdown.remaining == 1, "first tick only advances")
	u.frozen = 1
	tick(gs, 0, 7)
	check(gs.player(1).avatarArmorBreak == 2 and u.poisonTriggers == 1 and u.abilityCountdown.remaining == 2, "stun does not stop ability and overflow triggers once")
	u.frozen = 0
	tick(gs)
	check(gs.player(1).avatarArmorBreak == 4 and u.poisonTriggers == 2, "base trigger history accumulates before awakening")
	play(gs, "c11605")
	check(u.awakened and u.attack == 3 and u.maxHp == 5 and u.poisonTriggers == 3, "awakening printed +1/0 and retained history")
	check(gs.player(1).avatarArmorBreak == 6 and u.abilityCountdown.mode == "venom", "documented pending boundary: first awakening reduces old timer before replacing mode")
	tick(gs)
	check(gs.player(1).avatarArmorBreak == 11 and u.poisonTriggers == 4, "awake poison grows from all prior triggers")
	play(gs, "c11605")
	check(u.attack == 4 and u.poisonTriggers == 5 and gs.player(1).avatarArmorBreak == 17, "second awakening reduces current ability and applies printed bonus again")
	gs._knockout_unit(u)
	check(u.abilityCountdown.remaining == 2 and u.poisonTriggers == 5 and u.awakened, "knockout resets timer but preserves permanent history and awakening")
	gs._begin_turn(0)
	check(u.hp == 0 and u.poisonTriggers == 5, "dead countdown ability stays paused")
	gs._begin_turn(0)
	check(u.hp == u.maxHp and u.abilityCountdown.remaining == 1, "natural revival resumes timer in revival phase")
	u.level = 0
	tick(gs)
	check(u.poisonTriggers == 5, "inactive source cannot trigger ability")
	check(gs.rule_events.all(func(e): return e.kind != "automatic-card"), "poison timer isn't a spell or hand play")
	check(not ContentLoader.card_def("c11605").get("verificationPending", []).is_empty(), "awakening ordering uncertainty remains audited")
	check("已触发5次" in Rules.Countdown.mode(u).text, "ability description tracks exact trigger history")
	check("已触发5次" in Rules.Countdown.describe_card(ContentLoader.card_def("c11605"), u).text, "hand awakening has dynamic history")
	gs = fixture()
	check(gs.play_card(0, give(gs, 0, "c12804"), gs.player(0).units[0].uid), "teammate can select poison timer")
	check(gs.player(1).avatarArmorBreak == 2, "targeted countdown reduction triggers actual poison")

func _status() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(1).units[3]
	Rules.ArmorBreak.give(gs, 0, 0, 1, 3, 3)
	Rules.ArmorBreak.give(gs, 0, 0, 1, 3, 2)
	check(u.armorBreak == 5 and u.hp == 12, "poison stacks without immediate damage")
	u.shield = 3
	var hit := gs._damage_unit(1, 3, 1, 0)
	check(hit.damage == 3 and u.hp == 9 and u.shield == 0 and u.armorBreak == 0, "real damage combines poison before armor")
	gs._damage_unit(1, 3, 1, 0)
	check(u.hp == 8, "poison is not applied twice")
	u.armorBreak = 4
	u.barrier = true
	gs._damage_unit(1, 3, 0, 0)
	check(u.barrier and u.armorBreak == 4 and u.hp == 8, "zero damage consumes neither barrier nor poison")
	gs._damage_unit(1, 3, 1, 0)
	check(not u.barrier and u.armorBreak == 4 and u.hp == 8, "barrier prevents damage and preserves poison")
	u.shield = 20
	gs._damage_unit(1, 3, 1, 0)
	check(u.shield == 15 and u.armorBreak == 0 and u.hp == 8, "armor absorbs combined amount without life loss")
	gs.player(1).avatarArmorBreak = 4
	gs.player(1).avatarArmor = 3
	gs.player(1).realms.append({"name": "test", "hp": 10, "avatarLinked": true})
	check(gs._damage_avatar(1, 1, 0) == 2, "avatar damage returns damage after armor and poison")
	check(gs.player(1).avatarHp == 28 and gs.player(1).realms[0].hp == 8 and gs.player(1).avatarArmorBreak == 0, "linked realm receives actual residual damage")
	u.armorBreak = 5
	gs.player(1).avatarArmorBreak = 5
	gs._begin_turn(0)
	check(u.armorBreak == 5 and gs.player(1).avatarArmorBreak == 5, "opposing turn start preserves status")
	gs._begin_turn(1)
	check(u.armorBreak == 0 and gs.player(1).avatarArmorBreak == 0, "owner start clears unit and avatar status")
	u.armorBreak = 3
	gs._knockout_unit(u)
	check(u.armorBreak == 0, "knockout clears poison")
	gs = fixture()
	gs._resolve_one_effect(0, 1, {}, {"action": "apply-armor-break", "target": "all-enemy-units", "value": 2}, null, {})
	check(gs.player(1).units.all(func(v): return v.armorBreak == 2), "other cards enter same status gateway")
	gs._run_passive_effect(0, 1, "passive-armor-break-enemy-avatar", {"amount": 3}, {})
	check(gs.player(1).avatarArmorBreak == 3, "other passives enter same status gateway")

func _combat() -> void:
	for marked in [false, true]:
		var gs := fixture()
		var u: Dictionary = gs.player(0).units[0]
		var enemy: Dictionary = gs.player(1).units[3]
		enemy.front = 1
		enemy.attack = 7
		enemy.armorBreak = 2 if marked else 0
		u.armorBreak = 3
		play(gs, "c11601")
		check(u.hp == (5 if marked else 0), "feather immunity is conditional on marked enemy at attack declaration")
		check(enemy.hp == (6 if marked else 8) and enemy.armorBreak == 0, "feather attack detonates opponent status")
		if marked:
			check(u.armorBreak == 3, "immunity preserves own poison")
			gs._damage_unit(0, 0, 1, 1)
			check(u.hp == 1, "combat immunity does not leak into subsequent spells")
		gs = fixture()
		gs.player(0).avatarHp = 10
		gs.player(1).avatarArmorBreak = 6 if marked else 0
		play(gs, "c11608")
		check(gs.player(0).avatarHp == (20 if marked else 10), "temptation only heals when attack target was marked")
		check(gs.player(0).units[0].shield == 2 and gs.player(0).units[0].attack == 2, "temptation printed armor persists; attack bonus is combat-local")
		gs._begin_turn(0)
		check(gs.player(0).units[0].shield == 0, "temptation armor expires at owner start")
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[3]
	enemy.front = 1
	enemy.armorBreak = 5
	enemy.shield = 20
	gs.player(0).avatarHp = 10
	play(gs, "c11608")
	check(gs.player(0).avatarHp == 10 and enemy.hp == 12 and enemy.shield == 11, "absorbed damage never heals")
	gs = fixture()
	enemy = gs.player(1).units[3]
	enemy.front = 1
	enemy.armorBreak = 6
	enemy.hp = 3
	gs.player(0).avatarHp = 10
	play(gs, "c11608")
	check(gs.player(0).avatarHp == 20 and enemy.hp == 0, "lifesteal uses damage dealt, including overkill")
	gs = fixture()
	enemy = gs.player(1).units[3]
	enemy.front = 1
	enemy.attack = 3
	enemy.shield = 7
	enemy.barrier = true
	enemy.armorBreak = 2
	play(gs, "c11604")
	check(enemy.hp == 12 and enemy.shield == 7 and enemy.barrier and enemy.armorBreak == 8, "conversion creates poison instead of a damage event")
	check(gs.player(0).units[0].armorBreak == 3 and gs.player(0).units[0].attack == 2, "conversion and printed bonus last for one combat only")
	gs._damage_unit(1, 3, 1, 0)
	check(not enemy.barrier and enemy.armorBreak == 8, "later real hit goes through barrier normally")
	gs = fixture()
	play(gs, "c11604")
	check(gs.player(1).avatarHp == 30 and gs.player(1).avatarArmorBreak == 6, "toxic combat also converts attacks on avatar")
	gs = fixture()
	enemy = gs.player(1).units[3]
	enemy.front = 1
	enemy.hp = 11
	enemy.attack = 0
	play(gs, "c11607")
	check(enemy.hp == 9 and enemy.armorBreak == 4, "flower uses post-damage current health and documented pending floor rounding")
	check(not ContentLoader.card_def("c11607").get("verificationPending", []).is_empty(), "rounding is not falsely marked verified")
	gs = fixture()
	enemy = gs.player(1).units[3]
	enemy.front = 1
	enemy.shield = 20
	play(gs, "c11607")
	check(enemy.armorBreak == 0, "flower does not trigger on fully absorbed damage")

func _forms() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	play(gs, "c11603")
	check(u.attack == 4 and u.hp == 6 and u.abilityCountdown.remaining == 2, "solitude has correct printed stats and keeps base timer")
	Rules.ArmorBreak.give(gs, 0, 1, 1, 2, 1)
	gs._resolve_resolution_stack()
	check(u.abilityCountdown.remaining == 1, "teammate's first poison on an enemy reduces countdown")
	Rules.ArmorBreak.give(gs, 0, 1, 1, 2, 2)
	gs._resolve_resolution_stack()
	check(u.abilityCountdown.remaining == 1, "same enemy's second gain in turn is ignored")
	Rules.ArmorBreak.give(gs, 0, 1, 1, -1, 2)
	gs._resolve_resolution_stack()
	check(u.abilityCountdown.remaining == 1, "avatar gain cannot trigger shikigami-only form")
	Rules.ArmorBreak.give(gs, 0, 1, 1, 3, 1)
	gs._resolve_resolution_stack()
	check(u.poisonTriggers == 1 and gs.player(1).avatarArmorBreak == 4, "different enemy's first gain triggers countdown chain")
	play(gs, "c11603")
	Rules.ArmorBreak.give(gs, 0, 1, 1, 2, 1)
	gs._resolve_resolution_stack()
	check(u.abilityCountdown.remaining == 2, "form replacement does not reset victim's first-gain history")
	gs.turn_counter += 1
	Rules.ArmorBreak.give(gs, 1, 2, 1, 2, 1)
	gs._resolve_resolution_stack()
	check(u.abilityCountdown.remaining == 1, "opponent's own poison gain in new turn also qualifies")
	gs = fixture()
	Rules.ArmorBreak.give(gs, 0, 1, 1, 2, 1)
	play(gs, "c11603")
	Rules.ArmorBreak.give(gs, 0, 1, 1, 2, 1)
	gs._resolve_resolution_stack()
	check(gs.player(0).units[0].abilityCountdown.remaining == 2, "first gain before form entered cannot be counted again")
	gs = fixture()
	play(gs, "c11606")
	Rules.ArmorBreak.give(gs, 0, 1, 1, -1, 3)
	check(gs.player(1).avatarArmorBreak == 3 and gs.player(1).avatarHp == 30, "scatter cannot convert teammate poison")
	tick(gs)
	check(gs.player(1).avatarHp == 25 and gs.player(1).avatarArmorBreak == 0, "converted damage detonates existing status exactly once")
	gs.player(1).units[3].front = 1
	gs.player(1).units[3].attack = 3
	play(gs, "c11604")
	check(gs.player(1).units[3].hp == 3 and gs.player(0).units[0].hp == 7 and gs.player(0).units[0].armorBreak == 3, "scatter plus toxic combat converts source poison once; enemy conversion remains poison")
	gs._knockout_unit(gs.player(0).units[0])
	check(gs.player(0).units[0].form.is_empty(), "knockout removes poison-conversion form")

func _response() -> void:
	for blocked in ["", "fire", "level", "stun", "different-target"]:
		var gs := fixture()
		gs.current_player = 1
		var u: Dictionary = gs.player(0).units[0]
		u.front = 1
		give(gs, 0, "c11604")
		if blocked == "fire": gs.player(0).energy = 0
		if blocked == "level": u.level = 1
		if blocked == "stun": u.frozen = 1
		if blocked == "different-target":
			u.front = 0
			gs.player(0).units[3].front = 1
		var commands: int = gs.command_log.size()
		check(gs.basic_attack(1, 3), "response attack " + blocked)
		check(gs.player(0).hand.is_empty() == blocked.is_empty(), "response legality " + blocked)
		if blocked.is_empty():
			check(u.hp == 5 and u.armorBreak == 1 and gs.player(1).units[3].armorBreak == 6, "response applies +4 to retaliation of original combat")
			check(gs.player(0).energy == 19 and u.attack == 2, "response pays once and bonus does not persist")
			check(gs.command_log.size() == commands + 1, "response does not fabricate extra assault command")
			check(gs.rule_events.filter(func(e): return e.kind == "combat-hit").size() == 1, "one response means one original combat")
	var gs := fixture()
	gs.current_player = 1
	give(gs, 0, "c11604")
	var u: Dictionary = gs.player(0).units[0]
	gs._resolve_combat(1, 3, 0, false, false, false, false, u.uid, false, {"pursuit": true})
	gs._resolve_resolution_stack()
	check(gs.player(0).hand.is_empty() and u.front == 0 and u.armorBreak == 1, "reserve pursuit response does not move defender or start an extra attack")
	gs = fixture()
	gs.player(1).units[0].front = 1
	give(gs, 1, "c11604")
	play(gs, "c12807")
	check(gs.basic_attack(0, 3), "attack after manual counterspell")
	check(gs.player(1).hand.is_empty() and gs.player(1).energy == 19, "nullified poison response still spent card and fire")
	check(gs.player(0).units[3].armorBreak == 0 and gs.player(1).units[0].armorBreak == 0 and gs.player(1).units[0].hp == 4, "counterspell prevents response combat modifications")
	gs = fixture()
	gs.player(1).units[3].front = 1
	gs.resolution_stack.append({"kind": "combat-hit", "combatId": 123, "playerIndex": 1, "sourceIndex": 3, "defenderIndex": 0, "power": 1, "options": {}, "remote": false, "pierce": false, "combo": false, "firstStrike": false, "fromReserve": false})
	gs._push_card_frames(0, "c11604", null, ContentLoader.card_def("c11604"), 0, 0, false, 123)
	gs.resolution_stack = JSON.parse_string(JSON.stringify(gs.resolution_stack))
	gs._resolve_resolution_stack()
	check(gs.player(0).units[0].armorBreak == 1 and gs.player(1).units[3].armorBreak == 6, "response continuation survives JSON round trip without shared-reference assumptions")

func _ai() -> void:
	var gs := fixture()
	gs.player(0).energy = 1
	give(gs, 0, "c11604")
	check(not AI._best_card(gs, 0).ok, "AI keeps poison response without a detonation follow-up")
	gs.player(0).energy = 2
	check(AI._best_card(gs, 0).ok, "AI may use poison proactively with a follow-up attack")
	gs.player(0).hand.clear()
	give(gs, 0, "c11602")
	var action := AI._best_card(gs, 0)
	check(action.ok and gs.can_play_card(0, action.hand, action.target).ok, "AI selects legal countdown spell")
	check(AI.take_action(gs, 0) and gs.player(1).avatarArmorBreak == 2, "AI executes real countdown effects")
	gs = fixture()
	gs.player(1).avatarArmorBreak = 6
	gs.player(0).avatarHp = 10
	give(gs, 0, "c11601")
	give(gs, 0, "c11608")
	check(AI._best_card(gs, 0).card_id == "c11608", "AI values conditional lifesteal when its avatar is wounded")
