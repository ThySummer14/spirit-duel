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
		printerr("JUDGE_TIDE_UI_FAIL ", message)
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
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "judge-ui-%d" % i, "definitionId": ids[i]})
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
		battle.setup(["panguan", "haifangzhu", "yaodaoji", "taohuayao"], ["panguan", "haifangzhu", "yaodaoji", "bingyong"], 122117)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(battle)
		var gs = battle.gs
		var p: Dictionary = gs.player(0)
		var e: Dictionary = gs.player(1)
		hand(battle, ["c12202"])
		await create_timer(0.25).timeout
		await click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0, "goujue opens target picker")
		check(not gs.valid_targets(0, battle._pending_target_card_def).has(e.units[2].uid), "high power enemy is not offered")
		escape()
		check(battle._pending_target_card == -1 and p.energy == 40, "cancel preserves energy")
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(e.units[0].uid)))
		await settled(battle)
		check(e.units[0].hp == 0 and p.destroyedUnits == 1 and p.energy == 39, "real click resolves true destruction")
		battle._show_unit_popover(p.units[0], 0, 0)
		check("消灭进度 1/13" in texts(battle._tooltip), "inspector has exact destruction progress")
		await capture("%d-01-judge-progress" % physical.x)
		battle._hide_tooltip()
		check(battle._unit_widget(str(p.units[0].uid)).data.judgeKills == 1, "battlefield receives progress projection")
		hand(battle, ["c12201"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(e.units[2].uid)))
		await settled(battle)
		check(e.units[2].attack == 1 and e.units[2].hp == 3, "ink target click reduces health and power")
		battle._show_unit_popover(e.units[2], 1, 2)
		check("墨笔 · 力量 -2 / 生命 -1" in texts(battle._tooltip), "ink marker explains persistent debuff")
		await capture("%d-02-ink" % physical.x)
		battle._hide_tooltip()
		hand(battle, ["c12205"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		check(gs.valid_targets(0, battle._pending_target_card_def).has(p.units[3].uid), "declaration UI offers friendly targets")
		await process_frame
		await click(battle._unit_widget(str(p.units[3].uid)))
		await settled(battle)
		check(p.units[3].hp == 0 and p.destroyedUnits == 2, "friendly target click destroys and records")
		hand(battle, ["c12203"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		check(p.hand.size() == 1 and not gs.can_play_card(0, 0).ok, "empty-front exchange cannot be played from UI")
		hand(battle, ["c11708", "c11701"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.units[1].awakened and p.units[1].maxHp == 9, "awakening click applies correct body")
		var before := int(p.energy)
		await click(battle._hand_row.get_child(0))
		check(gs.valid_targets(0, battle._pending_target_card_def).has("avatar-0"), "heal UI includes avatar")
		await process_frame
		await click(battle._unit_widget(str(p.units[2].uid)))
		await settled(battle)
		check(p.units[2].shield == 3 and p.units[2].attack == 6 and p.energy == before, "first instant heal creates armor and power without fire")
		battle._show_unit_popover(p.units[1], 0, 1)
		check("过量治疗 → 护甲与力量" in texts(battle._tooltip), "awake status explains conversion")
		await capture("%d-03-overheal" % physical.x)
		battle._hide_tooltip()
		hand(battle, ["c11707"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(p.units[2].uid)))
		await settled(battle)
		battle._show_unit_popover(p.units[2], 0, 2)
		check("沧海之盾 · 战斗伤害回复牌手 2" in texts(battle._tooltip), "temporary grant is visible with amount")
		await capture("%d-04-combat-heal" % physical.x)
		battle._hide_tooltip()
		gs.end_turn(0)
		await settled(battle)
		check(not Status.unit_marks(p.units[2], gs.turn_counter).any(func(m): return m.id == "tide-combat-heal"), "temporary mark disappears after expiry")
		for uid in battle._unit_widgets:
			var widget = battle._unit_widgets[uid]
			if widget.is_inside_tree(): check(widget.get_global_rect().size.x > 0, "unit remains laid out")
		root.remove_child(battle)
		battle.free()
		await process_frame
	Support.cleanup_stores(stores)
	print("JUDGE_TIDE_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
