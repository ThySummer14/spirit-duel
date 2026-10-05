extends SceneTree
## Existing content effects: target scope, dead-unit exclusion, damage retention, energy cap.
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	for target in ["source", "selected-ally", "all-ally-units", "all-other-allies", "selected-enemy", "all-enemy-units"]:
		_verify_buff(target)
	var gs := _match()
	var p := gs.player(0)
	for starting in [0, 2, 3, 4]:
		p.energy = starting
		gs._resolve_action(0, 0, {}, {"action": "energy-gain", "value": 2}, null, {})
		_check(int(p.energy) == mini(4, starting + 2), "energy caps at four")
	var held_hp: int = p.units[0].hp
	gs._resolve_action(0, 0, {}, {"action": "buff-stats", "target": "selected-ally", "value": {"attack": 2, "hp": 2}}, null, {})
	_check(int(p.units[0].hp) == held_hp, "missing selected target does not buff source")
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		quit(1)
		return
	print("RESOURCE_EFFECTS_OK checks=%d" % checks)
	quit(0)

func _match() -> GameState:
	var gs := GameState.create(["basalt", "lumen", "rime", "ink"], ["storm", "frostblade", "kongo", "ember"], 9041)
	for p in gs.players:
		for i in p.units.size():
			p.units[i].hp = 0 if i == 3 else 2
	return gs

func _verify_buff(target: String) -> void:
	var gs := _match()
	var owner := 1 if target in ["selected-enemy", "all-enemy-units"] else 0
	var chosen: Dictionary = gs.player(owner).units[1]
	var target_id = chosen.uid if target.begins_with("selected") else null
	var before: Array = gs.players.duplicate(true)
	gs._resolve_action(0, 0, {}, {"action": "buff-stats", "target": target, "value": {"attack": 2, "hp": 3}}, target_id, chosen if target_id != null else {})
	for side in 2:
		for i in 4:
			var affected := side == owner and i != 3
			if target == "source": affected = affected and i == 0
			if target.begins_with("selected"): affected = affected and i == 1
			if target == "all-other-allies": affected = affected and i != 0
			var unit: Dictionary = gs.player(side).units[i]
			var old: Dictionary = before[side].units[i]
			_check(int(unit.attack) == int(old.attack) + (2 if affected else 0), target + " attack target scope")
			_check(int(unit.maxHp) == int(old.maxHp) + (3 if affected else 0), target + " max HP target scope")
			_check(int(unit.hp) == int(old.hp) + (3 if affected else 0), target + " preserves damage and dead units")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
