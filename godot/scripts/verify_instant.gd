extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var gs := GameState.create(["jutun-tongzi", "basalt", "lumen", "rime"], ["storm", "ember", "kongo", "ink"], 9041)
	var card := {"cost": 2, "keywords": ["instant"]}
	_check(gs.effective_card_cost(0, card) == 0, "first instant is free")
	_check(gs.player(0).keywordUsage.instant.used == false, "cost query does not consume instant")
	_check(gs.effective_card_cost(0, {"cost": 2}) == 2, "ordinary card keeps cost")
	_check(gs.effective_card_cost(1, card) == 2, "opponent turn does not discount")
	gs.response_window = {"playerIndex": 0}
	_check(gs.effective_card_cost(0, card) == 2, "response window does not discount")
	gs.response_window = {}
	gs.kw_usage(0, "instant").used = true
	_check(gs.effective_card_cost(0, card) == 2, "later instant keeps cost")
	gs._begin_turn(0)
	_check(gs.effective_card_cost(0, card) == 0, "owner turn resets instant")
	for unit in gs.player(0).units: unit.level = 3
	gs.player(0).energy = 0
	gs.player(0).hand = [{"definitionId": "c10201", "instanceId": "instant-a"}, {"definitionId": "c10201", "instanceId": "instant-b"}]
	_check(gs.can_play_card(0, 0).ok, "free instant is legal at zero energy")
	_check(gs.play_card(0, 0), "free instant resolves")
	_check(int(gs.player(0).energy) == 0, "free instant does not make energy negative")
	_check(gs.player(0).keywordUsage.instant.used, "successful play consumes allowance")
	_check(not gs.can_play_card(0, 0).ok, "second instant needs printed cost")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("INSTANT_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
