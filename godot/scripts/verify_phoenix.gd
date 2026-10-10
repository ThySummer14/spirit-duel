extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const Phoenix := preload("res://scripts/phoenix_rules.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PHOENIX_FAIL ", message)

func fixture() -> GS:
	var gs := GS.create(["fenghuanghuo", "datiangou", "yaoginshi", "basalt"], ["fenghuanghuo", "datiangou", "yaoginshi", "basalt"], 12409)
	for p in gs.players:
		p.hand.clear()
		p.energy = 40
		p.levelUpUsed = true
		for unit in p.units:
			unit.level = 3
			unit.passive_hooks = []
	return gs

func give(gs: GS, owner: int, id: String) -> int:
	gs.player(owner).hand.append({"instanceId": "phoenix-test-%d" % gs.next_card_id, "definitionId": id})
	gs.next_card_id += 1
	return gs.player(owner).hand.size() - 1

func play(gs: GS, id: String, target = null) -> void:
	check(gs.play_card(0, give(gs, 0, id), target), "play " + id)

func _initialize() -> void:
	_basic()
	_ignite()
	_forms()
	_enhancement()
	_targets_ai()
	_boundaries()
	check(checks >= 90, "all rule groups ran to completion")
	print("PHOENIX checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("PHOENIX_OK")
	quit(0 if failures == 0 else 1)

func _basic() -> void:
	var gs := fixture()
	var p: Dictionary = gs.player(0)
	var e: Dictionary = gs.player(1)
	play(gs, "c12401")
	check(e.avatarHp == 27, "patched phoenix cry deals two then separate projectile one")
	check(p.energy == 40, "first instant consumes no fire")
	check(int(p.units[0].get("phoenixAvatarHits", 0)) == 2, "two damage instances count separately")
	play(gs, "c12401")
	check(p.energy == 39 and e.avatarHp == 24, "second instant costs one without merging damage")
	gs = fixture()
	p = gs.player(0)
	e = gs.player(1)
	e.units[3].front = 1
	play(gs, "c12404", e.units[3].uid)
	check(e.units[3].hp == 6 and e.avatarHp == 30, "spell resolves then projectile hits surviving front")
	check(int(p.units[0].get("phoenixAvatarHits", 0)) == 0, "unit damage does not enhance dance")
	e.units[3].hp = 5
	play(gs, "c12404", e.units[3].uid)
	check(e.units[3].hp == 0 and e.avatarHp == 29, "projectile re-evaluates front after spell kill")
	check(int(p.units[0].get("phoenixAvatarHits", 0)) == 1, "only exposed avatar projectile counts")
	gs = fixture()
	e = gs.player(1)
	play(gs, "c12402")
	check(e.units[0].hp == 3 and e.units[1].hp == 3 and e.units[2].hp == 3 and e.units[3].hp == 11, "swarm damages every enemy unit once")
	check(e.avatarHp == 29, "swarm has only passive avatar damage")
	gs = fixture()
	play(gs, "c12408")
	check(gs.player(0).units[0].attack == 3 and gs.player(0).units[0].maxHp == 5 and gs.player(1).avatarHp == 29, "awakening is a spell with printed 1/1 and one projectile")
	play(gs, "c12806")
	check(gs.player(1).avatarHp == 28, "teammate spell triggers awakened phoenix")
	play(gs, "c12408")
	check(gs.player(0).units[0].attack == 4 and gs.player(0).units[0].maxHp == 6 and gs.player(1).avatarHp == 27, "repeated awakening stacks body only, no duplicate projectile")
	var source: Dictionary = gs.player(0).units[0]
	gs._knockout_unit(source)
	play(gs, "c12806")
	check(gs.player(1).avatarHp == 27, "knocked phoenix cannot project teammate spells")
	check(int(source.get("phoenixAvatarHits", 0)) == 3 and source.awakened, "history and awakened state survive knockout")
	gs = fixture()
	play(gs, "c12806")
	check(gs.player(1).avatarHp == 30, "unawakened phoenix ignores teammate spell")
	gs.player(0).units[0].awakened = true
	gs.player(0).units[0].frozen = 1
	play(gs, "c12806")
	check(gs.player(1).avatarHp == 29, "stun blocks own plays but not teammate ability trigger")

func _ignite() -> void:
	var gs := fixture()
	var e: Dictionary = gs.player(1)
	e.units[3].front = 1
	play(gs, "c12407", e.units[0].uid)
	check(e.units[0].hp == 2 and e.units[3].hp == 11 and e.avatarHp == 30, "surviving target does not take unconditional avatar followup")
	e.units[0].hp = 2
	play(gs, "c12407", e.units[0].uid)
	check(e.units[0].hp == 0 and e.units[3].hp == 10 and e.avatarHp == 28, "killing reserve deals exact followup then front projectile")
	gs = fixture()
	e = gs.player(1)
	e.units[3].front = 1
	e.units[3].hp = 3
	play(gs, "c12407", e.units[3].uid)
	check(e.units[3].hp == 0 and e.avatarHp == 30, "passive killing survivor does not retroactively trigger ignite reward")
	gs = fixture()
	e = gs.player(1)
	e.units[0].hp = 2
	e.units[0].barrier = true
	e.units[3].front = 1
	play(gs, "c12407", e.units[0].uid)
	check(e.units[0].hp == 2 and e.avatarHp == 30 and not e.units[0].barrier, "barrier blocks ignite kill condition")
	gs = fixture()
	e = gs.player(1)
	e.units[0].hp = 2
	e.units[0].shield = 1
	e.units[3].front = 1
	play(gs, "c12407", e.units[0].uid)
	check(e.units[0].hp == 1 and e.avatarHp == 30, "armor prevents ignite kill condition")
	gs = fixture()
	gs.player(0).units[3].hp = 2
	play(gs, "c12407", gs.player(0).units[3].uid)
	check(gs.player(0).avatarHp == 28 and gs.player(1).avatarHp == 29, "friendly kill follows target controller, passive stays hostile")
	gs = fixture()
	gs.player(0).units[0].hp = 2
	play(gs, "c12407", gs.player(0).units[0].uid)
	check(gs.player(0).avatarHp == 28 and gs.player(1).avatarHp == 29, "original FAQ: self-lethal ignite preserves its already-triggered projectile")
	check(gs.player(0).units[0].phoenixAvatarHits == 1, "projectile after source knockout still records its source-owned damage")
	gs = fixture()
	play(gs, "c12404", gs.player(0).units[0].uid)
	check(gs.player(0).units[0].hp == 0 and gs.player(1).avatarHp == 29, "original FAQ: self-lethal phoenix fire still projects")

func _forms() -> void:
	var gs := fixture()
	play(gs, "c12403")
	var unit: Dictionary = gs.player(0).units[0]
	check(unit.attack == 4 and unit.maxHp == 6, "burning feathers has printed 4/6 body")
	check(gs.player(1).avatarHp == 30, "form is not a spell and does not trigger projection")
	play(gs, "c12401")
	check(gs.player(1).avatarHp == 25, "burning feathers buffs both noncombat damage instances once")
	var view := Phoenix.describe_card(ContentLoader.card_def("c12404"), unit)
	check(view.value == 6 and "6点" in view.text, "live targeted card description includes own bonus")
	check(ContentLoader.card_def("c12404").value == 5, "description never mutates catalog")
	gs.player(1).units[0].hp = 3
	play(gs, "c12407", gs.player(1).units[0].uid)
	check(gs.player(1).avatarHp == 20, "ignite buffs initial hit and kill followup independently")
	check(gs.basic_attack(0, 0), "phoenix ordinary attack legal")
	check(gs.player(1).avatarHp == 16, "burning feathers never buffs ordinary combat")
	play(gs, "c12406")
	check(unit.attack == 5 and unit.maxHp == 6 and Phoenix.bonus(unit) == 0, "cloud form replaces feather damage bonus")
	gs.rng_state = 1000
	play(gs, "c12401")
	check(gs.kw_usage(0, "fortune").last.roll == 4 and gs.player(0).hand.size() == 1 and gs.player(0).hand[0].definitionId == "c12404", "cloud really rolls d6 and creates phoenix fire on four")
	gs.player(0).hand.clear()
	gs.rng_state = 1
	play(gs, "c12401")
	check(gs.kw_usage(0, "fortune").last.roll == 2 and gs.player(0).hand.is_empty(), "cloud fails on two without drawing substitute")
	unit.awakened = true
	var seed_before: int = gs.rng_state
	play(gs, "c12806")
	check(gs.rng_state == seed_before and gs.player(0).hand.size() == 0, "teammate triggers awakened projection but not cloud generation")
	gs = fixture()
	play(gs, "c12406")
	for i in 12: give(gs, 0, "c12404")
	gs.rng_state = 1000
	gs._push_card_frames(0, "c12401", null, ContentLoader.card_def("c12401"), 0, 0, true)
	gs._resolve_resolution_stack()
	check(gs.player(0).hand.size() == 12, "cloud generated card burns at actual hand limit")
	gs._knockout_unit(gs.player(0).units[0])
	check(gs.player(0).units[0].get("formRules", {}).is_empty(), "knockout removes cloud ability")

func _enhancement() -> void:
	var gs := fixture()
	check(gs.basic_attack(0, 0), "ordinary face attack")
	var unit: Dictionary = gs.player(0).units[0]
	check(int(unit.get("phoenixAvatarHits", 0)) == 1, "ordinary combat contributes exactly one historical hit")
	play(gs, "c12401")
	check(int(unit.get("phoenixAvatarHits", 0)) == 3, "history accumulates spell and ability hits")
	var view := Phoenix.describe_card(ContentLoader.card_def("c12405"), unit)
	check(view.value == 8 and "3次" in view.text, "dance display follows total historical damage instances")
	play(gs, "c12405")
	check(gs.player(1).avatarHp == 16 and int(unit.get("phoenixAvatarHits", 0)) == 5, "dance damage uses prior history then records its own hit and passive")
	gs = fixture()
	unit = gs.player(0).units[0]
	gs.player(1).avatarArmor = 3
	play(gs, "c12401")
	check(gs.player(1).avatarHp == 30 and int(unit.get("phoenixAvatarHits", 0)) == 0, "fully armored hits do not fabricate damage history")
	gs._damage_avatar(1, 2, 0)
	check(int(unit.get("phoenixAvatarHits", 0)) == 0, "damage without phoenix source does not increment its history")
	gs = fixture()
	var e: Dictionary = gs.player(1)
	e.units[3].front = 1
	e.units[3].hp = 3
	e.units[3].shield = 1
	play(gs, "c12405")
	check(e.units[3].hp == 0 and e.avatarHp == 28, "dance overflow subtracts armor and HP, then passive targets exposed avatar")
	check(gs.player(0).units[0].phoenixAvatarHits == 2, "piercing overflow is a distinct avatar damage instance")
	gs = fixture()
	e = gs.player(1)
	e.units[3].front = 1
	e.units[3].hp = 3
	e.units[3].barrier = true
	play(gs, "c12405")
	check(e.units[3].hp == 2 and e.avatarHp == 28, "barrier protects shikigami but not allocated overflow; passive remains separate")
	check(gs.player(0).units[0].phoenixAvatarHits == 1, "overflow through unit barrier still enhances by its real avatar damage")
	gs = fixture()
	play(gs, "c12403")
	gs.player(1).units[3].front = 1
	gs.player(1).units[3].hp = 3
	play(gs, "c12405")
	check(gs.player(1).avatarHp == 25, "feathers added once before piercing, not again to overflow")

func _targets_ai() -> void:
	var gs := fixture()
	var card := ContentLoader.card_def("c12407")
	check(gs.valid_targets(0, card).size() == 8, "any-unit includes both teams")
	gs.player(0).units[3].level = 0
	gs.player(1).units[0].hp = 0
	check(gs.valid_targets(0, card).size() == 7, "any-unit includes inactive living units but rejects knocked targets")
	var index := give(gs, 0, "c12404")
	check(not gs.can_play_card(0, index, "avatar-1").ok, "targeted phoenix fire cannot directly hit avatar")
	check(not gs.can_play_card(0, index, gs.player(1).units[0].uid).ok, "targeted fire cannot target corpse")
	gs = fixture()
	gs.player(1).units[3].front = 1
	gs.player(1).units[0].hp = 2
	gs.player(0).units[3].hp = 1
	give(gs, 0, "c12407")
	var decision := AI._best_card(gs, 0)
	check(decision.ok and decision.target == gs.player(1).units[0].uid, "AI finds enemy conditional kill and never picks friendly low health")
	check(gs.play_card(0, decision.hand, decision.target), "AI choice passes actual legality")
	gs = fixture()
	gs.player(0).units[0].phoenixAvatarHits = 10
	gs.player(1).avatarHp = 9
	gs.player(1).units[3].front = 1
	gs.player(1).units[3].hp = 5
	give(gs, 0, "c12405")
	decision = AI._best_card(gs, 0)
	check(decision.ok and decision.score > 500, "AI recognizes enhanced piercing lethal")
	gs = fixture()
	gs.player(1).units[3].front = 1
	gs.player(1).units[0].hp = 1
	gs.player(1).units[0].unyielding = true
	gs.player(1).avatarHp = 2
	give(gs, 0, "c12407")
	decision = AI._best_card(gs, 0)
	check(decision.ok and decision.target == gs.player(1).units[0].uid and decision.score > 500, "AI knows one-health unyielding cannot stop ignite lethal followup")
	check(not ContentLoader.card_def("c12401").get("verificationPending", []).is_empty(), "snapshot version conflict is retained in audit")

func _boundaries() -> void:
	var gs := fixture()
	var source: Dictionary = gs.player(0).units[0]
	var enemy: Dictionary = gs.player(1).units[0]
	source.frozen = 1
	var index := give(gs, 0, "c12401")
	check(not gs.can_play_card(0, index).ok, "stunned source cannot play own phoenix spell")
	source.frozen = 0
	source.level = 1
	index = give(gs, 0, "c12405")
	check(not gs.can_play_card(0, index).ok, "enhancement does not bypass card level")
	gs = fixture()
	source = gs.player(0).units[0]
	enemy = gs.player(1).units[0]
	gs._damage_avatar(1, 1, 0, 3)
	gs._damage_avatar(0, 1, 0, 0)
	check(int(source.get("phoenixAvatarHits", 0)) == 0, "other source damage and friendly avatar damage excluded from history")
	gs._damage_avatar(1, 0, 0, 0)
	check(int(source.get("phoenixAvatarHits", 0)) == 0, "zero damage cannot enhance")
	gs.player(1).avatarArmor = 1
	gs._damage_avatar(1, 2, 0, 0)
	check(int(source.get("phoenixAvatarHits", 0)) == 1, "partially armored real damage contributes one hit")
	check(int(enemy.get("phoenixAvatarHits", 0)) == 0, "enemy phoenix never inherits opposing damage history")
	gs = fixture()
	source = gs.player(0).units[0]
	var card := ContentLoader.card_def("c12401")
	gs._push_card_frames(0, "c12401", null, card, 0, 0, true)
	gs._resolve_resolution_stack()
	check(gs.player(1).avatarHp == 27 and source.phoenixAvatarHits == 2, "automatic spell use still counts as spell and projects only once")
	check(gs.player(0).energy == 40 and gs.command_log.is_empty(), "automatic use does not pretend hand payment or player command")
	gs = fixture()
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	play(gs, "c12401")
	check(gs.player(1).avatarHp == 29, "counter removes card effects but preserves the independent spell-use projectile")
	check(gs.player(0).hand.is_empty() and gs.kw_usage(0, "instant").used, "countered instant still consumes played card and instant allowance")
	check(gs.player(0).units[0].phoenixAvatarHits == 1, "countered spell only records actual ability damage")
	check(gs.resolution_stack.is_empty(), "countered spell finishes the independent use frame without stranding the stack")
	gs = fixture()
	play(gs, "c12406")
	gs.rng_state = 1000
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	play(gs, "c12401")
	check(gs.player(1).avatarHp == 29 and gs.player(0).hand.size() == 1 and gs.player(0).hand[0].definitionId == "c12404", "countered own spell retains independent cloud fortune and real generated fire")
	check(gs.kw_usage(0, "fortune").last.roll == 4, "countered spell rolls the actual configured cloud die once")
	gs = fixture()
	gs.player(0).units[0].awakened = true
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	play(gs, "c12806")
	check(gs.player(1).avatarHp == 29, "countered teammate spell preserves awakened projection")
	gs = fixture()
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	play(gs, "c12403")
	check(gs.player(1).avatarHp == 30 and gs.player(0).units[0].attack == 2, "countered form neither applies body nor creates a spell-use ability")
	gs = fixture()
	give(gs, 1, "c12807")
	play(gs, "c12401")
	check(gs.player(1).avatarHp == 29 and gs.player(1).hand.is_empty(), "actual automatic magic counter cannot delete pending phoenix usage trigger")
	gs = fixture()
	gs.player(1).units[3].front = 1
	gs.player(1).units[3].hp = 2
	gs.player(1).units[3].unyielding = true
	play(gs, "c12405")
	check(gs.player(1).avatarHp == 27 and gs.player(1).units[3].hp == 0, "documented pending boundary: unyielding does not erase computed overflow; passive defeats remaining one HP")
	check(int(gs.player(0).units[0].get("phoenixAvatarHits", 0)) == 1, "only overflowing first hit damages avatar behind unyielding")
