extends SceneTree
## Regression cases for combat eligibility captured before damage clears statuses.
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	# Basalt has no combat hook that changes either fighter's health.
	for frozen in [0, 1]:
		for lethal in [false, true]:
			for remote in [false, true]:
				for first_strike in [false, true]:
					_check_counter(frozen, lethal, remote, first_strike)
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		quit(1)
		return
	print("COMBAT_REGRESSION_OK cases=16")
	quit(0)

func _check_counter(frozen: int, lethal: bool, remote: bool, first_strike: bool) -> void:
	var gs := GameState.create(["basalt"], ["basalt"], 9017)
	var attacker: Dictionary = gs.player(0).units[0]
	var defender: Dictionary = gs.player(1).units[0]
	attacker.hp = 20
	attacker.maxHp = 20
	attacker.attack = 3
	attacker.shield = 0
	defender.hp = 2 if lethal else 10
	defender.attack = 4
	defender.shield = 0
	defender.frozen = frozen
	defender.front = 1
	gs._resolve_combat(0, 0, 0, false, remote, false, first_strike)
	var counter := frozen == 0 and not remote and not (first_strike and lethal)
	var expected_hp := 16 if counter else 20
	if int(attacker.hp) != expected_hp:
		failures.append("counter frozen=%d lethal=%s remote=%s first_strike=%s expected_hp=%d got=%d" % [frozen, lethal, remote, first_strike, expected_hp, int(attacker.hp)])
	if lethal and (int(defender.hp) != 0 or int(defender.frozen) != 0 or int(defender.front) != 0):
		failures.append("knockout must still clear stun and front status")
