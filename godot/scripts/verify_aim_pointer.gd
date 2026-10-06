extends SceneTree
## The aiming guide needs fresh viewport-local input, never a stale desktop cursor.
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("AIM_POINTER_FAIL ", message)

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event)

func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	var battle := BattleScreen.new()
	battle.setup(["ember", "basalt", "lumen", "rime"], ["storm", "kongo", "frostblade", "ink"], 20261005)
	battle._ai_thinking = true
	for player in battle.gs.players:
		player.levelUpUsed = true
		for unit in player.units: unit.level = 3
	battle.gs.player(0).hand = [{"instanceId": "aim-brace", "definitionId": "brace"}]
	root.add_child(battle)
	root.size = Vector2i(1280, 800)
	await process_frame
	await process_frame
	battle._on_hand_clicked(0, ContentLoader.card_def("brace"))
	battle._process(0.0)
	_check(not battle._aim.visible, "no guide before fresh pointer evidence")
	var ally := battle._unit_widget("player:ember")
	var enemy := battle._unit_widget("ai:storm")
	var ally_point := ally.get_global_rect().get_center()
	var enemy_point := enemy.get_global_rect().get_center()
	var card_point: Vector2 = battle._hand_row.get_child(0).get_global_rect().get_center()
	_check(battle._aim_context(ally_point).get("valid", false), "legal ally targeting remains valid")
	var invalid := battle._aim_context(enemy_point)
	_check(not invalid.is_empty() and invalid.over_target and not invalid.valid, "enemy portrait remains explicit invalid feedback for an ally spell")
	_check(not battle._aim_context(card_point).is_empty(), "pointer may guide from the hand")
	for point in [Vector2(-5, 200), Vector2(1285, 200), Vector2(300, -5), Vector2(300, 805), Vector2(1270, 10)]:
		_check(battle._aim_context(point).is_empty(), "outside-window/header pointer hides guide: %s" % point)
	_check(battle._aim_context(battle._end_btn.get_global_rect().get_center()).is_empty(), "end-turn HUD is not targeting space")
	_check(battle._aim_context(battle._enemy_hand.get_global_rect().get_center()).is_empty(), "opponent hand HUD is not targeting space")
	_check(battle._aim_context(Vector2(NAN, 10)).is_empty(), "non-finite pointer does not draw")
	_motion(ally_point)
	await process_frame
	battle._process(0.0)
	_check(battle._aim.visible and battle._aim.valid and battle._aim.endpoint.distance_to(battle._center_of(ally)) < 0.1, "fresh viewport mouse motion snaps to the legal target")
	_motion(Vector2(1270, 10))
	await process_frame
	battle._process(0.0)
	_check(not battle._aim.visible, "actual HUD mouse motion hides the line")
	_motion(ally_point)
	await process_frame
	root.mouse_exited.emit()
	battle._process(0.0)
	_check(not battle._aim.visible and battle._pending_target_card == 0, "window exit hides guide without losing card selection")
	_motion(ally_point)
	await process_frame
	battle._process(0.0)
	_check(battle._aim.visible, "fresh re-entry motion restores guide")
	root.focus_exited.emit()
	battle._process(0.0)
	_check(not battle._aim.visible, "focus loss invalidates pointer evidence")
	var previous_transform := root.canvas_transform
	root.canvas_transform = Transform2D(0, Vector2(24, 18))
	_motion(battle.get_canvas_transform() * ally_point)
	await process_frame
	battle._process(0.0)
	_check(battle._aim.visible and battle._aim.valid and battle._aim.endpoint.distance_to(battle._center_of(ally)) < 0.1, "viewport pointer is transformed into the current canvas")
	root.canvas_transform = previous_transform
	_check(battle.gs.command_log.is_empty(), "aim updates do not execute game commands")
	battle.queue_free()
	await process_frame
	VerifySupport.cleanup_stores(fixture)
	print("AIM_POINTER checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty(): print("AIM_POINTER_OK")
	quit(0 if failures.is_empty() else 1)
