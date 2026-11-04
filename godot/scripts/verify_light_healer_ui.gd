extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LIGHT_HEALER_UI_FAIL ", text)
func click(face: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = face.get_global_transform_with_canvas() * (face.size * 0.5)
	root.push_input(motion, true)
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
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	root.push_input(e, true)
func texts(n: Node) -> String:
	var value := str(n.text) + "\n" if n is Label or n is RichTextLabel else ""
	for child in n.get_children(): value += texts(child)
	return value
func hand(b, ids: Array) -> void:
	b.gs.player(0).hand.clear()
	for i in ids.size(): b.gs.player(0).hand.append({"instanceId": "light-ui-%d" % i, "definitionId": ids[i]})
	b._last_view = {}
	b._refresh()
func settled(b) -> void:
	for i in 3: await process_frame
	await create_timer(b._presentation_remaining() + 0.18).timeout
	await process_frame
func card_faces(n: Node) -> Array:
	var found: Array = []
	if n is Control and n.get("data") is Dictionary and n.get("data").has("unitId"): found.append(n)
	for child in n.get_children(): found.append_array(card_faces(child))
	return found
func capture(name: String) -> void:
	if out.is_empty(): return
	await create_timer(0.25).timeout
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
		var b := Battle.new()
		b.setup(["qingxingdeng", "qingfangzhu", "zuofutongzi", "haifangzhu"], ["qingxingdeng", "qingfangzhu", "zuofutongzi", "haifangzhu"], 20261010)
		b._ai_thinking = true
		for p in b.gs.players:
			p.hand.clear()
			p.energy = 2
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(b)
		var gs = b.gs
		var p: Dictionary = gs.player(0)
		hand(b, ["c12902"])
		await create_timer(0.25).timeout
		await click(b._hand_row.get_child(0))
		await settled(b)
		check(gs.pending_choice.get("type") == "lantern-choice", "real click starts night talk")
		check("选择一张置入手牌" in texts(b._choice_layer), "choice explains direct hand acquisition")
		check("剩余2次" in texts(b._choice_layer), "choice shows repetitions")
		check(b._end_btn.disabled, "cannot end during choice")
		var faces := card_faces(b._choice_layer)
		check(faces.size() == 3, "three visible candidate cards")
		await capture("%d-01-night-talk" % physical.x)
		await click(faces[0])
		await settled(b)
		check(p.hand.size() == 1 and gs.pending_choice.remaining == 1, "first candidate click moves to hand")
		check("剩余1次" in texts(b._choice_layer), "second choice redraws fresh layer")
		faces = card_faces(b._choice_layer)
		check(faces.size() == 3, "second candidate pool")
		await click(faces.back())
		await settled(b)
		check(gs.pending_choice.is_empty() and p.hand.size() == 2 and p.energy == 0, "second click completes and drains fire")
		check(b._choice_layer == null, "choice panel closes")
		p.energy = 2
		p.units[3].level = 1
		hand(b, ["c12903", "mingdeng"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		check(b._pending_target_card == 0, "level opens target picker")
		check(gs.valid_targets(0, b._pending_target_card_def) == [p.units[3].uid], "only lowest unit highlighted")
		escape()
		check(p.energy == 2 and p.hand.size() == 2, "cancel doesn't discard lantern or spend fire")
		await click(b._hand_row.get_child(0))
		await click(b._unit_widget(str(p.units[3].uid)))
		await settled(b)
		check(p.units[3].level == 2 and p.hand.is_empty(), "target click levels and discards")
		p.energy = 4
		p.avatarHp = 15
		hand(b, ["c12503"])
		await create_timer(0.2).timeout
		await click(b._hand_row.get_child(0))
		check(gs.valid_targets(0, b._pending_target_card_def).has("avatar-0") and gs.valid_targets(0, b._pending_target_card_def).has("avatar-1"), "light offers both avatars")
		await click(b._ally_target_btn)
		await settled(b)
		check(p.avatarHp == 21, "avatar click heals twice")
		hand(b, ["c13005", "c13008"])
		await create_timer(0.2).timeout
		check(b._hand_row.get_child(0).data.level == 3, "normal awakening shows three levels")
		await click(b._hand_row.get_child(0))
		await settled(b)
		b._show_unit_popover(p.units[2], 0, 2)
		check("失败重投一次" in texts(b._tooltip), "awakening reroll status in inspector")
		check("双方运势 0/12" in texts(b._tooltip), "fortune ledger in inspector")
		await capture("%d-02-fortune" % physical.x)
		b._hide_tooltip()
		p.enemyAvatarAttacks = 7
		hand(b, ["c12508", "c12507"])
		b._on_hand_hover(true, b._hand_row.get_child(0))
		check(card_faces(b._tooltip).any(func(face): return "当前生命设为17" in str(face.data.text)), "rebirth count shown on live drawn card")
		b._hide_tooltip()
		await click(b._hand_row.get_child(1))
		await settled(b)
		check(p.units[1].hp == 0 and p.monkImmuneTurn == gs.turn_counter, "sacrifice click really kills monk")
		b._show_unit_popover(p.units[1], 0, 1)
		check("舍生 · 牌手本回合免伤" in texts(b._tooltip), "immunity remains visible while source knocked out")
		await capture("%d-03-sacrifice" % physical.x)
		root.remove_child(b)
		b.free()
		await process_frame
	Support.cleanup_audio()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("LIGHT_HEALER_UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
