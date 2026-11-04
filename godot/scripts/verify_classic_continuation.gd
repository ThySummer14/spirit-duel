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
		printerr("CLASSIC_CONTINUATION_FAIL ", message)
func _initialize() -> void:
	_book_replacement_duration()
	var dice := GS.create(["qingwa-ciqi", "shantu"], ["quanshen", "qingfangzhu"], 20261013)
	dice.player(0).fortuneNumbers = JSON.parse_string("[2]")
	dice.VerifiedRules.Fortune.record_die(dice, 0, 2)
	check(dice.player(0).fortuneNumbers.size() == 1, "restored numeric die faces are not counted twice")
	var lineups := [
		["shuweng", "jue", "qingwa-ciqi", "shantu"],
		["tiaotiaodidi", "qingshe", "yijin-zhentian", "qingfangzhu"],
		["qingwa-ciqi", "shantu", "zuofutongzi", "yaoginshi"],
		["jue", "shuweng", "xuenv", "quanshen"],
	]
	for index in lineups.size():
		for variant in 3:
			var seed := 202610130 + index * 3 + variant
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
	print("CLASSIC_CONTINUATION checks=%d failures=%d matches=%d" % [checks, failures, matches])
	quit(0 if failures == 0 else 1)

func _book_replacement_duration() -> void:
	# The card grants a replacement for the rest of the game, independently of
	# the original unit's currently active abilities or subsequent knockout.
	var gs := GS.create(["shuweng", "jue"], ["shantu", "qingwa-ciqi"], 11908)
	var p: Dictionary = gs.player(0)
	p.hand = [{"instanceId": "duration-book", "definitionId": "c11908"}]
	p.energy = 20
	p.levelUpUsed = true
	p.units[0].level = 3
	check(gs.play_card(0, 0), "book grants its rest-of-game draw replacement")
	gs.VerifiedRules.Fortune.transform(gs, 0, 0, false)
	check(p.units[0].baseRulesSuppressed, "paper suppresses the original unit abilities")
	p.deck.clear()
	gs._draw(0, 2)
	check(gs.player(1).avatarHp == 20 and gs.winner < 0, "granted global draw replacement persists through paper")
	gs._knockout_unit(p.units[0])
	gs._draw(0, 2)
	check(gs.player(1).avatarHp == 10 and gs.winner < 0, "global draw replacement persists after paper knockout")
