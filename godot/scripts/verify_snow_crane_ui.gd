extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SNOW_CRANE_UI_FAIL ", message)
func move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	root.push_input(event, true)
func click(face: Control) -> void:
	move(face.get_global_transform_with_canvas() * (face.size * 0.5))
	await process_frame
	await create_timer(0.14).timeout
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
func texts(node: Node) -> String:
	var text := str(node.text) + "\n" if node is Label or node is RichTextLabel else ""
	for child in node.get_children(): text += texts(child)
	return text
func hand(battle, ids: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "snow-crane-ui-%d" % i, "definitionId": ids[i]})
	battle._last_view = {}
	battle._refresh()
func settled(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.18).timeout
	await process_frame
func capture(name: String) -> void:
	if out.is_empty(): return
	await create_timer(0.25).timeout
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func run() -> void:
	var stores := Support.isolate_stores()
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var battle := Battle.new()
		battle.setup(["xuetongzi", "guniao", "yaodaoji", "taohuayao"], ["xuetongzi", "guniao", "yaodaoji", "bingyong"], 112109)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(battle)
		var gs = battle.gs
		var p: Dictionary = gs.player(0)
		var enemy: Dictionary = gs.player(1)
		enemy.units[0].front = 1
		enemy.units[2].hp = 2
		enemy.units[2].attack = 1
		hand(battle, ["c10905"])
		await create_timer(0.25).timeout
		await click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0, "sky slash opens real target choice")
		check(gs.valid_targets(0, battle._pending_target_card_def).size() == 3, "three reserve targets and no front/avatar")
		escape()
		check(battle._pending_target_card == -1 and p.energy == 40, "escape cancels without payment")
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(enemy.units[0].uid)))
		check(battle._pending_target_card == 0 and p.energy == 40, "front click rejected without consuming card")
		await capture("%d-01-reserve-target" % physical.x)
		await click(battle._unit_widget(str(enemy.units[2].uid)))
		await settled(battle)
		check(enemy.units[2].hp == 0 and enemy.avatarHp == 26 and enemy.units[0].hp == 4, "reserve selection resolves actual attack and overflow")
		check(p.units[1].front == 0 and p.units[1].hp == 3, "crane counters then retreats")
		enemy.units[0].front = 0
		hand(battle, ["c11207", "c11202", "c11206"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(enemy.avatarFrozen == 1 and battle._enemy_stun.visible and "眩晕 1" in battle._enemy_stun.text, "avatar stun visible after real frost wind")
		check(battle._hand_row.get_child(0).data.payment.cost == 0, "stunned avatar makes dance visibly free")
		battle._show_unit_popover(p.units[0], 0, 0)
		check("眩晕记录 1" in texts(battle._tooltip) and "冰雪免伤" in texts(battle._tooltip), "inspector exposes real history and conditional immunity")
		await capture("%d-02-avatar-stun" % physical.x)
		battle._hide_tooltip()
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(gs.kw_usage(0, "instant").used and p.energy == 38, "dance spends shared instant after wind")
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.units[0].attack == 6 and p.units[0].maxHp == 7, "enhanced thaw uses history on visible form")
		battle._show_unit_popover(p.units[0], 0, 0)
		check("每次至多受3伤害" in texts(battle._tooltip), "thaw cap has explicit status")
		await capture("%d-03-thaw-status" % physical.x)
		battle._hide_tooltip()
		hand(battle, ["c10908"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(Status.unit_marks(p.units[1], gs.turn_counter).any(func(m): return m.id == "remote"), "crane awakening shows remote")
		battle._show_unit_popover(p.units[1], 0, 1)
		check("远程" in texts(battle._tooltip), "remote inspector visible")
		await capture("%d-04-remote" % physical.x)
		battle._hide_tooltip()
		gs.end_turn(0)
		gs.end_turn(1)
		await settled(battle)
		check(not battle._enemy_stun.visible, "avatar stun mark expires with rule")
		root.remove_child(battle)
		battle.free()
		await process_frame
	Support.cleanup_stores(stores)
	print("SNOW_CRANE_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
