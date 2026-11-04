extends SceneTree
## Mixed rules stay legal and deterministic after pending-state JSON roundtrips.
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
var matches := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WAVE2_CONTINUATION_FAIL ", message)
func _initialize() -> void:
	_summon_and_guard_interactions()
	var dice := GS.create(["qingwa-ciqi", "shantu"], ["quanshen", "qingfangzhu"], 20261013)
	dice.player(0).fortuneNumbers = JSON.parse_string("[2]")
	dice.VerifiedRules.Fortune.record_die(dice, 0, 2)
	check(dice.player(0).fortuneNumbers.size() == 1, "restored numeric die faces are not counted twice")
	var lineups := [
		["yaohu", "lingyuyuqian", "rihefang", "yanyanluo"],
		["tiaotiaomeimei", "buzhinhuo", "xiaolunan", "lianyou"],
		["yatiangou", "rihefang", "qingwa-ciqi", "shantu"],
		["yanyanluo", "buzhinhuo", "yaohu", "qingshe"],
		["xiaolunan", "lianyou", "yatiangou", "lingyuyuqian"],
		["tiaotiaomeimei", "rihefang", "shuweng", "jue"],
	]
	for index in lineups.size():
		for variant in 3:
			var seed := 202610140 + index * 3 + variant
			var a := GS.create(lineups[index], lineups[(index + 1) % lineups.size()], seed)
			var b := GS.create(lineups[index], lineups[(index + 1) % lineups.size()], seed)
			for step in 180:
				if a.winner >= 0 or b.winner >= 0: break
				var owner := a.action_player()
				var before := a.command_log.size()
				AI.take_turn(a, owner)
				AI.take_turn(b, owner)
				check(a.winner >= 0 or a.command_log.size() > before, "mixed AI advances seed %d step %d" % [seed, step])
				if step % 5 == 0:
					b.players = JSON.parse_string(JSON.stringify(b.players))
					b.pending_choice = JSON.parse_string(JSON.stringify(b.pending_choice))
					b.response_window = JSON.parse_string(JSON.stringify(b.response_window))
					b.resolution_stack = JSON.parse_string(JSON.stringify(b.resolution_stack))
				var original = JSON.parse_string(JSON.stringify(a.snapshot()))
				var restored = JSON.parse_string(JSON.stringify(b.snapshot()))
				check(original == restored, "mixed state survives JSON seed %d step %d" % [seed, step])
				if failures > 0: break
			check(a.winner >= 0 and a.winner == b.winner, "both seeded mixed matches complete")
			matches += 1
	print("WAVE2_CONTINUATION checks=%d failures=%d matches=%d" % [checks, failures, matches])
	quit(0 if failures == 0 else 1)

func _summon_and_guard_interactions() -> void:
	var gs := GS.create(["yatiangou","tiaotiaomeimei","yanyanluo","lingyuyuqian"],["shantong","bailang","yingcao","yaodaoji"],20261015)
	for p in gs.players:
		p.hand.clear()
		p.energy = 30
		p.levelUpUsed = true
		for u in p.units: u.level = 3
	var p: Dictionary = gs.player(0)
	p.units[0].front = 1
	gs.VerifiedRules.TomatoFire.summon(gs,0,1,"tomato")
	gs._resolve_resolution_stack()
	check(p.units[0].front == 0 and gs.player(1).avatarHp == 29, "tomato displaces crow and resolves its actual movement once")
	var tomato: Dictionary = gs.front_unit(0)
	gs.VerifiedRules.SunSmoke.summon(gs,0,2)
	gs._resolve_resolution_stack()
	check(tomato.hp == 0 and tomato.removed and gs.front_unit(0).smokeClone, "clone replaces and removes tomato immediately")
	var clone: Dictionary = gs.front_unit(0)
	gs.VerifiedRules.TomatoFire.summon(gs,0,1,"burn")
	gs._resolve_resolution_stack()
	check(clone.hp == 0 and clone.removed and gs.front_unit(0).burnEntity, "burn replaces and removes smoke clone")
	var burn: Dictionary = gs.front_unit(0)
	gs.VerifiedRules.Movement.move_to(gs,0,p.units.size()-1,0)
	check(burn.hp == 0 and burn.removed and gs.front_index(0) < 0, "explicit movement removes burn summon rather than retaining a reserve body")
	gs.VerifiedRules.TomatoFire.summon(gs,0,1,"tomato")
	tomato = gs.front_unit(0)
	check(gs.VerifiedRules.Movement.move_to(gs,0,3,1), "ordinary unit moves into occupied front")
	gs._resolve_resolution_stack()
	check(tomato.hp == 0 and tomato.removed and p.units[3].front == 1, "ordinary movement removes replaced tomato")
	# A single attack-start projection must not be repeated by avatar guards.
	gs = GS.create(["lingyuyuqian","bailang","yingcao","yaodaoji"],["yanyanluo","tiaotiaodidi","qingshe","yingcao"],20261015)
	for side in gs.players:
		side.hand.clear()
		side.energy = 30
		side.levelUpUsed = true
		for u in side.units: u.level = 3
	p = gs.player(0)
	var foe: Dictionary = gs.player(1)
	gs._apply_form(0,0,preload("res://scripts/content_loader.gd").card_def("c18007"))
	foe.hand.append({"instanceId":"guard-smoke","definitionId":"c16404"})
	check(gs.basic_attack(0,0), "home attacks against automatic smoke guard")
	check(foe.avatarHp == 27, "only one home projection before smoke responds")
	check(foe.units.size() == 5 and foe.units[4].smokeClone, "smoke summons actual blocker")
	check(gs.rule_events.filter(func(e):return e.kind == "fox-suzuka-hit" and e.card.id == "suzuka-home").size() == 1, "resumed guarded attack never reruns attack-start effects")
	check(gs.player(1).get("enemyAvatarAttacks",0) == 0, "guarded attack is not recorded as attacking avatar")
	gs = GS.create(["yatiangou","rihefang","yingcao","yaodaoji"],["shantu","bailang","yingcao","yaodaoji"],20261015)
	for side in gs.players:
		side.hand.clear()
		side.energy = 30
		side.levelUpUsed = true
		for u in side.units: u.level = 3
	gs.VerifiedRules.Movement.hold(gs,0,0,1,1)
	gs.VerifiedRules.Fortune.transform(gs,0,0,false)
	check(gs.player(1).units[1].has("movementHolders"), "hold persists after its caster transforms, until the card's ending condition")
	check(gs.basic_attack(0,0), "original crow identity may attack as paper")
	check(not gs.player(1).units[1].has("movementHolders"), "paper caster attacking releases granted hold without requiring original ability")
