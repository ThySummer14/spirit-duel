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
		printerr("ARCHER_MOUNTAIN_UI_FAIL ", message)
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
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "archer-ui-%d" % i, "definitionId": ids[i]})
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
		battle.setup(["bailang", "shantong", "yaodaoji", "taohuayao"], ["bailang", "shantong", "yaodaoji", "taohuayao"], 110113)
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
		hand(battle, ["c11007"])
		await create_timer(0.25).timeout
		await click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0, "kai opens real target picker")
		check(gs.valid_targets(0, battle._pending_target_card_def).size() == 4, "kai allows four enemy units only")
		escape()
		check(battle._pending_target_card == -1 and p.energy == 40, "cancel does not pay")
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(enemy.units[1].uid)))
		check(p.get("delayedShots", []).size() == 1 and p.energy == 39, "click target creates paid delayed shot")
		check(enemy.units[1].hp == 4 and enemy.avatarHp == 30, "no fake immediate avatar damage")
		await settled(battle)
		battle._show_unit_popover(p.units[0], 0, 0)
		check("会 · 山童" in texts(battle._tooltip), "owner inspector shows private target")
		await capture("%d-01-private-shot" % physical.x)
		battle._hide_tooltip()
		var own_view: Dictionary = battle._unit_widget(str(p.units[0].uid)).data
		check(own_view.has("privateShotHints"), "owner battlefield has private shot mark")
		enemy.delayedShots = [{"target": p.units[2].uid, "sourceIndex": 0, "damage": 8, "card": ContentLoader.card_def("c11007")}]
		battle._last_view = {}
		battle._refresh()
		battle._show_unit_popover(enemy.units[0], 1, 0)
		check(not "会 · 妖刀姬" in texts(battle._tooltip), "opponent inspector hides secret target")
		check(not battle._unit_widget(str(enemy.units[0].uid)).data.has("privateShotHints"), "opponent battlefield has no leaked mark")
		battle._hide_tooltip()
		enemy.delayedShots = []
		p.delayedShots = []
		hand(battle, ["c11004", "c11001", "c11003"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.units[0].attack == 3 and p.units[0].maxHp == 5 and p.units[0].formRules.retainSpellEnhancements, "click installs modern 3/5 zanshin")
		check(Status.unit_marks(p.units[0], gs.turn_counter).any(func(m): return m.id == "remote"), "remote mark reflects form")
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.units[0].attack == 5 and gs.kw_usage(0, "instant").used, "click new bow uses shared instant")
		check(Status.unit_marks(p.units[0], gs.turn_counter).any(func(m): return m.id == "penetration"), "penetration mark from live buff")
		p.units[1].front = 1
		enemy.units[1].front = 1
		enemy.units[1].hp = 10
		enemy.units[1].maxHp = 10
		enemy.units[1].shield = 9
		enemy.units[1].barrier = true
		battle._last_view = {}
		battle._refresh()
		battle._show_unit_popover(p.units[0], 0, 0)
		check("穿刺" in texts(battle._tooltip) and "远程" in texts(battle._tooltip) and "法术强化 +2力量" in texts(battle._tooltip), "inspector distinguishes three effects")
		await capture("%d-02-remote-penetration" % physical.x)
		battle._hide_tooltip()
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(enemy.units[1].hp == 4 and enemy.units[1].shield == 0 and not enemy.units[1].barrier, "UI combat applies penetration on two real hits")
		check(p.units[0].front == 0 and p.units[1].front == 1 and p.units[0].hp == 5, "remote leaves guarding ally and avoids counter")
		check(p.units[0].attack == 5, "zanshin preserves spell power")
		hand(battle, ["c11304", "c11307"])
		await create_timer(0.2).timeout
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.units[1].attack == 6 and p.units[1].maxHp == 9, "mountain form and awakening body")
		gs.end_turn(0)
		await settled(battle)
		check(p.units[1].attack == 0 and battle._unit_widget(str(p.units[1].uid)).data.attack == 0, "enemy turn visible power becomes zero")
		battle._show_unit_popover(p.units[1], 0, 1)
		check("笨拙" in texts(battle._tooltip) and "免疫敌方非战斗伤害" in texts(battle._tooltip), "mountain states explain condition and immunity")
		await capture("%d-03-clumsy-immunity" % physical.x)
		battle._hide_tooltip()
		gs.end_turn(1)
		await settled(battle)
		check(p.units[1].attack == 6, "own turn restores power")
		for uid in battle._unit_widgets:
			var widget = battle._unit_widgets[uid]
			if widget.is_inside_tree(): check(widget.get_global_rect().size.x > 0, "unit remains laid out")
		root.remove_child(battle)
		battle.free()
		await process_frame
	Support.cleanup_stores(stores)
	print("ARCHER_MOUNTAIN_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
