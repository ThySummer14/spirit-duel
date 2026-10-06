extends SceneTree
## Existing damage-self primitive uses ordinary unit damage, before subsequent effects.
const GameState := preload("res://scripts/game_state.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for owner in 2:
		for shield in [0, 2, 5]:
			var gs := GameState.create(["basalt", "lumen", "rime", "ink"], ["storm", "ember", "kongo", "frostblade"], 9041)
			var unit: Dictionary = gs.player(owner).units[1]
			unit.hp = 3
			unit.shield = shield
			unit.front = 1
			var other_hp: int = gs.player(1 - owner).units[1].hp
			gs._resolve_action(owner, 1, {"value": 3}, {"action": "damage-self"}, null, {})
			_check(int(unit.hp) == mini(3, shield), "self damage uses card fallback and source index")
			_check(int(unit.shield) == maxi(0, shield - 3), "shield absorbs self damage")
			_check(int(unit.knockout) == (2 if shield == 0 else 0), "lethal self damage sets countdown")
			_check(int(unit.front) == (0 if shield == 0 else 1), "only lethal damage removes front")
			_check(int(gs.player(owner).avatarHp) == 30, "existing baseline damages unit rather than avatar")
			_check(int(gs.player(1 - owner).units[1].hp) == other_hp, "enemy is untouched")
	var gs := GameState.create(["basalt", "lumen", "rime", "ink"], ["storm", "ember", "kongo", "frostblade"], 9041)
	var unit: Dictionary = gs.player(0).units[0]
	unit.hp = 3
	unit.unyielding = true
	gs._resolve_action(0, 0, {}, {"action": "damage-self", "value": 9}, null, {})
	_check(int(unit.hp) == 1 and int(unit.knockout) == 0, "unyielding applies to self damage")
	unit.unyielding = false
	unit.brittle = 1
	gs._resolve_action(0, 0, {}, {"action": "damage-self", "value": 1}, null, {})
	_check(int(unit.hp) == 0 and int(unit.brittle) == 0, "brittle and lethal cleanup apply")
	var attack: int = unit.attack
	gs._resolve_action(0, 0, {}, {"action": "buff-stats", "target": "source", "value": {"attack": 3}}, null, {})
	_check(int(unit.attack) == attack and int(unit.hp) == 0, "following buff cannot revive or strengthen knocked-out source")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("SELF_DAMAGE_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
