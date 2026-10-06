extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for owner in 2:
		var gs := GameState.create(["basalt", "lumen", "rime", "ink"], ["storm", "ember", "kongo", "frostblade"], 9041)
		var foe := gs.player(1 - owner)
		var target: Dictionary = foe.units[0]
		target.front = 1
		target.shield = 3
		var hp: int = target.hp
		gs._resolve_action(owner, 0, {}, {"action": "bounce-to-reserve"}, target.uid, target)
		_check(int(target.front) == 0, "selected enemy returns to reserve")
		_check(int(target.hp) == hp and int(target.shield) == 3, "return preserves HP and shield")
		_check(gs.front_index(1 - owner) == -1, "reserve return does not auto-promote another unit")
		gs._run_passive_effect(owner, 0, "passive-damage-enemy-front-on-form", {"amount": 2}, {})
		_check(int(foe.avatarHp) == 30, "form hook keeps its existing no-fallback behavior")
		gs._run_passive_effect(owner, 0, "passive-damage-enemy-front", {"amount": 2}, {})
		_check(int(foe.avatarHp) == 30, "ordinary entry hook still requires explicit fallback")
		gs._run_passive_effect(owner, 0, "passive-damage-enemy-front-on-spell", {"amount": 2}, {})
		_check(int(foe.avatarHp) == 28, "spell hook hits exposed core")
		target.front = 1
		gs._run_passive_effect(owner, 0, "passive-damage-enemy-front-on-spell", {"amount": 2}, {})
		_check(int(target.shield) == 1 and int(foe.avatarHp) == 28, "spell hook prefers occupied front")
		var before: Array = gs.players.duplicate(true)
		gs._resolve_action(owner, 0, {}, {"action": "bounce-to-reserve"}, null, {})
		gs._resolve_action(owner, 0, {}, {"action": "bounce-to-reserve"}, gs.player(owner).units[0].uid, gs.player(owner).units[0])
		_check(gs.players == before, "missing and allied targets are ignored")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("BOUNCE_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
