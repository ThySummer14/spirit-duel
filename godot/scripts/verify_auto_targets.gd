extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var gs := GameState.create(["xixueji-xiyi", "basalt", "lumen", "rime"], ["storm", "ember", "kongo", "ink"], 9041)
	for unit in gs.player(0).units: unit.level = 3
	gs.player(0).hand = [{"definitionId": "c66301", "instanceId": "auto-target"}]
	var before: Array = gs.players.duplicate(true)
	_check(not gs.can_play_card(0, 0, "ai:storm").ok, "automatic spell rejects an explicit target")
	_check(not gs.play_card(0, 0, "ai:storm"), "invalid command is rejected")
	_check(gs.players == before, "rejected command preserves cards, energy and units")
	_check(gs.command_log.is_empty(), "rejected command is not recorded")
	_check(gs.play_card(0, 0), "automatic card still plays without target")
	_check(int(gs.player(0).units[0].hp) == int(before[0].units[0].hp) - 2, "self cost resolves")
	_check(gs.player(1) == before[1], "missing selected enemy does not fall back to avatar")
	gs.player(1).units[0].front = 1
	var hp: int = gs.player(1).units[0].hp
	gs._apply_damage_action(0, "selected-enemy", 4, {})
	_check(int(gs.player(1).units[0].hp) == hp, "missing selected enemy does not fall back to front")
	gs._apply_damage_action(0, "selected-enemy", 2, gs.player(1).units[0])
	_check(int(gs.player(1).units[0].hp) == hp - 2, "actual selected enemy still takes damage")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("AUTO_TARGETS_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
