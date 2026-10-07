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
		printerr("DATIANGOU_FAIL ", message)

func fixture(seed_value := 10509) -> GS:
	var gs := GS.create(["datiangou", "yaoginshi", "datiangou-gangfeng", "basalt"], ["datiangou", "yaoginshi", "datiangou-gangfeng", "basalt"], seed_value)
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
	_replay()
	_damage_and_form()
	_awakening()
	_justice()
	_shields()
	_responses()
	_determinism_ai()
	print("DATIANGOU checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("DATIANGOU_OK")
	quit(0 if failures == 0 else 1)

func _replay() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	check(not u.has("spellCountdown"), "no invented timer before first spell")
	play(gs, "c10504")
	check(gs.player(1).avatarHp == 28, "no old extra passive damage")
	check(u.spellCountdown.card.id == "c10504" and u.spellCountdown.remaining == 2, "last spell is attached with two turns")
	var energy: int = gs.player(0).energy
	tick(gs, 1)
	check(gs.player(1).avatarHp == 28, "one turn does not cast")
	tick(gs, 3)
	check(gs.player(1).avatarHp == 26 and u.spellCountdown.remaining == 2, "overflow triggers once and resets")
	check(gs.player(0).energy == energy and gs.player(0).hand.is_empty(), "replay consumes neither hand nor fire")
	check(u.spellsUsed == 2, "automatic spells contribute to spell count")
	play(gs, "c10502")
	check(u.spellCountdown.card.id == "c10504" and u.spellsUsed == 2, "form does not replace or count as spell")
	play(gs, "c10501")
	check(u.spellCountdown.card.id == "c10501", "new spell replaces old timer")
	u.frozen = 1
	tick(gs, 2)
	check(gs.player(1).avatarHp == 18, "stun blocks hand use but not ability replay")
	gs._damage_unit(0, 0, 99, 1)
	check(not u.has("spellCountdown"), "normal tengu loses attached spell on knockout")
	check(u.spellsUsed == 4, "match spell history survives knockout")
	u.hp = u.maxHp
	tick(gs, 2)
	check(gs.player(1).avatarHp == 18, "revival does not resurrect discarded spell")
	gs = fixture()
	play(gs, "c10504")
	gs.player(0).units[0].level = 0
	tick(gs, 2)
	check(gs.player(1).avatarHp == 28, "inactive unit timer cannot fire")

func _damage_and_form() -> void:
	var gs := fixture()
	var enemy: Dictionary = gs.player(1).units[0]
	enemy.front = 1
	enemy.shield = 2
	play(gs, "c10504")
	check(enemy.front == 1 and enemy.hp == 4 and enemy.shield == 0, "fully armored fan hit does not displace")
	play(gs, "c10504")
	check(enemy.front == 0 and enemy.hp == 2, "actual damage displaces survivor")
	gs = fixture()
	enemy = gs.player(1).units[0]
	enemy.front = 1
	var deck: int = gs.player(0).deck.size()
	play(gs, "c10501")
	check(enemy.hp == 0 and gs.player(0).deck.size() == deck - 1, "black feather kills then draws exactly one")
	play(gs, "c10501")
	check(gs.player(1).avatarHp == 26 and gs.player(0).deck.size() == deck - 1, "avatar hit draws nothing")
	gs = fixture()
	gs._grow_unit(gs.player(0).units[0], 1, 1)
	play(gs, "c10502")
	check(gs.player(0).units[0].attack == 5 and gs.player(0).units[0].maxHp == 7, "form sets printed base and retains permanent growth")
	for u in gs.player(1).units:
		u.hp = 20
		u.maxHp = 20
	gs.player(1).units[1].barrier = true
	play(gs, "c10506")
	check(gs.player(1).avatarHp == 27, "feather storm hits avatar without form bonus")
	check(gs.player(1).units[0].hp == 16 and gs.player(1).units[1].hp == 19, "form followup is a separate hit, including barrier-affected enemy")
	check(gs.rule_events.filter(func(e): return e.kind == "form-followup").size() == 4, "one followup per affected live unit")
	gs = fixture()
	play(gs, "c10502")
	for u in gs.player(1).units:
		u.hp = 20
		u.maxHp = 20
	play(gs, "c10503")
	var followups: Array = gs.rule_events.filter(func(e): return e.kind == "form-followup")
	var targets: Array = []
	var total := 30 - int(gs.player(1).avatarHp)
	for e in followups: targets.append(e.target)
	for u in gs.player(1).units: total += 20 - int(u.hp)
	check(total == 6 + followups.size(), "wind is exactly six individual random points plus distinct followups")
	var unique := {}
	for id in targets: unique[id] = true
	check(targets.size() == unique.size(), "repeat hits never multiply form followup")
	check(followups.size() < 4, "fixed seed is not a substitute blanket area hit")
	var a := fixture()
	var b := fixture()
	play(a, "c10503")
	play(b, "skin-datiangou-93150")
	check(a.player(1).units == b.player(1).units and a.player(1).avatarHp == b.player(1).avatarHp, "alternate art executes identical six-hit distribution")

func _awakening() -> void:
	var gs := fixture()
	play(gs, "c10504")
	tick(gs, 1)
	play(gs, "c10507")
	var u: Dictionary = gs.player(0).units[0]
	check(u.attack == 5 and u.maxHp == 6, "2021 awakening grants printed two/two")
	check(gs.player(1).avatarHp == 26 and u.spellCountdown.card.id == "c10504", "awakening immediately triggers the retained one-turn spell")
	check(u.spellCountdown.remaining == 1 and u.spellCountdown.reset == 1, "awakened timer repeats every own turn")
	play(gs, "c10507")
	check(u.attack == 7 and u.maxHp == 8 and gs.player(1).avatarHp == 24, "second awakening applies printed effect again without replaying itself")
	check(u.spellsUsed == 5, "awakening and triggered spells each count once")
	gs = fixture()
	play(gs, "c10507")
	check(not gs.player(0).units[0].has("spellCountdown"), "awakening without a prior spell does not invent one")
	play(gs, "c10501")
	check(gs.player(0).units[0].spellCountdown.remaining == 1, "future spell attaches awakened period")

func _justice() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[0]
	u.level = 1
	var pool: Array = Rules.SpellReplay.generation_pool(u, ContentLoader.card_def("c10508"))
	check(pool.size() == 2 and pool.all(func(c): return c.id in ["c10504", "c10509"]), "one-level pool excludes self, form, high-level black feather and skin duplicates")
	u.level = 3
	pool = Rules.SpellReplay.generation_pool(u, ContentLoader.card_def("c10508"))
	check(pool.size() == 6 and pool.any(func(c): return c.id == "c10507"), "three-level pool includes awakening exactly once")
	u.spellsUsed = 9
	var energy: int = gs.player(0).energy
	play(gs, "c10508")
	check(gs.player(0).energy == energy and gs.player(0).hand.size() == 1, "instant first unenhanced justice generates a card at nine prior spells")
	check(gs.player(1).units.all(func(x): return x.hp > 0) and u.spellsUsed == 10, "tenth spell does not retroactively enhance itself")
	tick(gs, 2)
	check(gs.player(0).hand.size() == 2 and gs.player(1).units.all(func(x): return x.hp > 0), "attached unenhanced copy stays generation after threshold")
	for victim in gs.player(1).units:
		victim.hp = 90
		victim.shield = 90
		victim.barrier = true
		victim.unyielding = true
	play(gs, "c10508")
	check(gs.player(1).units.all(func(x): return x.hp == 0), "enhanced justice destroys through HP, armor, barrier and unyielding")
	check(gs.player(1).avatarHp == 30 and gs.player(0).hand.size() == 2, "destruction is not damage, does not hit avatar or also generate")
	check(gs.player(0).energy == energy - 1, "second instant costs one fire")
	gs.player(1).units[0].hp = 90
	tick(gs, 2)
	check(gs.player(1).units[0].hp == 0, "enhanced copy retains destruction on replay")
	gs = fixture()
	for i in 12: give(gs, 0, "c10504")
	gs._push_card_frames(0, "c10508", null, ContentLoader.card_def("c10508"), 0, 0, true)
	gs._resolve_resolution_stack()
	check(gs.player(0).hand.size() == 12 and gs.player(0).deck.size() > 0, "generated card burns at hand limit without drawing or fatigue")

func _shields() -> void:
	var gs := fixture()
	var u: Dictionary = gs.player(0).units[3]
	play(gs, "c10509", u.uid)
	check(u.shield == 2 and u.pendingShields.size() == 1, "manual shield schedules distinct second grant")
	gs.end_turn(0)
	check(u.shield == 4 and u.pendingShields.is_empty(), "next opponent turn grants on original target")
	gs.end_turn(1)
	check(u.shield == 0, "both shield grants expire at target owner's turn start")
	gs = fixture()
	u = gs.player(0).units[3]
	play(gs, "c10509", u.uid)
	gs._damage_unit(0, 3, 99, 1)
	u.hp = u.maxHp
	gs.end_turn(0)
	check(u.shield == 0 and not u.has("pendingShields"), "knockout removes scheduled grant even after revival")
	gs = fixture()
	play(gs, "c10509", gs.player(0).units[3].uid)
	tick(gs, 2)
	var automatic: Dictionary = gs.rule_events.filter(func(e): return e.kind == "automatic-card").back()
	check(automatic.target != gs.player(0).units[3].uid and automatic.target != null, "fixed seed replay independently selects a random living ally")
	var target: Dictionary = gs._unit_by_uid(gs.player(0).units, automatic.target)
	check(target.shield == 2, "automatic selected target receives actual shield")

func _responses() -> void:
	for attack in ["basic", "card"]:
		var gs := fixture()
		var defender: Dictionary = gs.player(1).units[0]
		defender.front = 1
		give(gs, 1, "c10509")
		if attack == "basic": check(gs.basic_attack(0, 0), "basic attack starts")
		else: play(gs, "c29001")
		check(defender.hp == 3 and defender.shield == 0, "response armor applied before " + attack + " damage")
		check(gs.player(1).energy == 19 and gs.player(1).hand.is_empty(), "response pays actual hand and fire")
		check(defender.spellCountdown.card.id == "c10509", "response spell attaches replay to caster")
		check(gs.response_window.is_empty() and gs.resolution_stack.is_empty(), "no manual response UI or stuck continuation")
		var kinds: Array = gs.rule_events.map(func(e): return e.kind)
		check(kinds.find("response-card") < kinds.find("combat-hit"), "event chronology places response before attack impact")
		gs.end_turn(0)
		check(defender.shield == 2, "response delayed armor arrives after own-turn cleanup")
	for blocked in ["fire", "level", "dead", "stun", "reserve", "avatar"]:
		var gs := fixture()
		var p := gs.player(1)
		p.units[3].front = 1
		give(gs, 1, "c10509")
		match blocked:
			"fire": p.energy = 0
			"level": p.units[0].level = 0
			"dead": p.units[0].hp = 0
			"stun": p.units[0].frozen = 1
			"reserve": pass
			"avatar": p.units[3].front = 0
		if blocked == "reserve": play(gs, "c29005", p.units[1].uid)
		else: check(gs.basic_attack(0, 0), "blocked response attack " + blocked)
		check(p.hand.size() == 1, "response respects " + blocked)
	var gs := fixture()
	gs.player(1).units[3].front = 1
	play(gs, "c12807")
	give(gs, 1, "c10509")
	var hp: int = gs.player(1).units[3].hp
	check(gs.basic_attack(0, 0), "sealed response attack")
	check(gs.player(1).units[3].hp == hp - 3 and not gs.player(1).units[0].has("spellCountdown"), "proactive magic seal counters shield before it grants anything")
	gs = fixture()
	play(gs, "c10504")
	give(gs, 1, "c12807")
	gs.player(0).nullifyNextCardTurn = gs.turn_counter
	tick(gs, 2)
	check(gs.player(1).hand.size() == 1 and gs.player(1).avatarHp == 26 and gs.player(0).has("nullifyNextCardTurn"), "ability replay neither triggers counter nor consumes pre-existing seal")
	gs = fixture()
	give(gs, 1, "c12807")
	play(gs, "c29001")
	check(gs.player(0).units[2].spellCountdown.card.name == "风神一扇" and gs.player(0).units[2].front == 0, "nullified steel combat still attaches its when-used origin ability")

func _determinism_ai() -> void:
	var a := fixture()
	var b := fixture()
	for gs in [a, b]:
		play(gs, "c10503")
		play(gs, "c10508")
		play(gs, "c10509", gs.player(0).units[3].uid)
		tick(gs, 2)
	check(a.snapshot() == b.snapshot(), "seed controls damage, generation and replay target consistently")
	check(JSON.parse_string(JSON.stringify(a.snapshot())) is Dictionary, "timers and delayed effects are serializable")
	var gs := fixture()
	give(gs, 0, "c10508")
	gs.player(0).units[0].spellsUsed = 10
	check(AI._best_card(gs, 0).ok, "AI can play enhanced justice")
