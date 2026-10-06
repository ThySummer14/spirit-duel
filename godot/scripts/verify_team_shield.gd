extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for owner in 2:
		var gs := GameState.create(["basalt", "lumen", "rime", "ink"], ["storm", "ember", "kongo", "frostblade"], 9041)
		for i in 4:
			gs.player(owner).units[i].shield = i
		gs.player(owner).units[3].hp = 0
		var before: Array = gs.players.duplicate(true)
		gs._resolve_action(owner, 1, {"value": 5}, {"action": "shield-self-player"}, null, {})
		for i in 4:
			_check(int(gs.player(owner).units[i].shield) == i + (5 if i < 3 else 0), "living allies receive additive shield; dead ally excluded")
			_check(gs.player(owner).units[i].hp == before[owner].units[i].hp, "team shield does not heal or revive")
		_check(gs.player(1 - owner) == before[1 - owner], "opponent state unchanged")
		_check(gs.player(owner).avatarHp == before[owner].avatarHp, "avatar HP unchanged")
		gs._resolve_action(owner, 1, {}, {"action": "shield-self-player", "value": 2}, null, {})
		_check(int(gs.player(owner).units[0].shield) == 7, "repeated effects stack")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("TEAM_SHIELD_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
