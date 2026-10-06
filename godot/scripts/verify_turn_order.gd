extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var gs := GameState.create(["qingxingdeng", "basalt", "lumen", "rime"], ["storm", "frostblade", "kongo", "ember"], 424242)
	_check(gs.player(0).hand.back().definitionId == "mingdeng", "opening draw precedes generated token")
	var top: String = gs.player(0).deck.back().definitionId
	var before: int = gs.player(0).hand.size()
	_check(gs.end_turn(0) and gs.end_turn(1), "turn cycle succeeds")
	_check(gs.player(0).hand[before].definitionId == top, "turn draw precedes token")
	_check(gs.player(0).hand[before + 1].definitionId == "mingdeng", "token follows turn draw")
	gs = GameState.create(["qingxingdeng", "caitongzi", "lumen", "rime"], ["storm", "frostblade", "kongo", "ember"], 424242)
	gs.player(0).deck.clear()
	before = gs.player(0).hand.size()
	var attack: int = gs.player(0).units[1].attack
	gs._begin_turn(0)
	_check(gs.winner == 1, "empty deck ends match")
	_check(gs.player(0).hand.size() == before, "no generated token after defeat")
	_check(int(gs.player(0).units[1].attack) == attack, "no passive growth after defeat")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("TURN_ORDER_OK checks=7")
	quit(0)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
