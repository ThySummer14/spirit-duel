extends SceneTree
const GameState := preload("res://scripts/game_state.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for owner in 2:
		var gs := GameState.create(["basalt", "lumen", "rime", "ink"], ["storm", "ember", "kongo", "frostblade"], 9041)
		var unit: Dictionary = gs.player(1 - owner).units[0]
		unit.hp = 2
		var old_attack: int = unit.attack
		var old_max: int = unit.maxHp
		var effect := {"action": "debuff-stats", "target": "selected-enemy", "value": {"attack": -2, "hp": -1}}
		gs._resolve_action(owner, 0, {}, effect, unit.uid, unit)
		_check(int(unit.attack) == old_attack - 2, "negative attack delta is signed")
		_check(int(unit.maxHp) == old_max - 1 and int(unit.hp) == 1, "negative HP delta reduces damaged unit")
		gs._resolve_action(owner, 0, {}, effect, unit.uid, unit)
		_check(int(unit.hp) == 1, "existing baseline floors direct HP reduction at one")
		var before: Array = gs.players.duplicate(true)
		gs._resolve_action(owner, 0, {}, {"action": "debuff-stats", "target": "all-enemy-units", "value": {"attack": 2}}, null, {})
		_check(gs.players == before, "all-enemy with no selected target remains baseline no-op")
		var ally: Dictionary = gs.player(owner).units[0]
		gs._resolve_action(owner, 0, {}, effect, ally.uid, ally)
		_check(gs.players == before, "selected ally is not a selected enemy")
		var attack: int = unit.attack
		gs._resolve_action(owner, 0, {}, {"action": "debuff-stats", "target": "selected-enemy", "value": {"attack": 2}}, unit.uid, unit)
		_check(int(unit.attack) == attack + 2, "positive catalog delta is not silently negated")
		unit.hp = 0
		before = gs.players.duplicate(true)
		gs._resolve_action(owner, 0, {}, effect, unit.uid, unit)
		_check(gs.players == before, "knocked-out target is excluded")
	if not failures.is_empty():
		for failure in failures: printerr(failure)
		quit(1)
		return
	print("SIGNED_DEBUFF_OK checks=%d" % checks)
	quit(0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
