extends SceneTree
## Permanent growth must increase living HP once and never revive a knocked-out unit.
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	for hp in [0, 1, 5, 10]:
		var gs := GameState.create(["basalt"], ["basalt"], 9021)
		var unit: Dictionary = gs.player(0).units[0]
		unit.baseMaxHp = 10
		unit.maxHp = 10
		unit.hp = hp
		unit.knockout = 2 if hp == 0 else 0
		gs._grow_unit(unit, 2, 3)
		_check(int(unit.hp) == (hp + 3 if hp > 0 else 0), "growth preserves damage and knockout: initial HP %d, got %d" % [hp, unit.hp])
		_check(int(unit.maxHp) == 13, "maximum HP grows once")
		_check(int(unit.attack) == int(unit.baseAttack) + 2, "attack grows once")
		_check(int(unit.knockout) == (2 if hp == 0 else 0), "growth preserves knockout countdown")
		gs._grow_unit(unit, 1, 2)
		_check(int(unit.hp) == (hp + 5 if hp > 0 else 0), "successive growth does not double heal")
		_check(int(unit.maxHp) == 15, "successive growth stacks maximum HP")
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		quit(1)
		return
	print("GROWTH_REGRESSION_OK checks=24")
	quit(0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
