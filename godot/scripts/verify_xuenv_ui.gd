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
		printerr("XUENV_UI_FAIL ", message)
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
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "snow-ui-%d" % i, "definitionId": ids[i]})
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
		battle.setup(["xuenv", "xuetongzi", "panguan", "taohuayao"], ["xuenv", "yaodaoji", "bingyong", "shantong"], 106107)
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
		hand(battle, ["c10610"])
		await create_timer(0.25).timeout
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		check(p.hand.size() == 2 and p.snowballBonus == 1, "heart click generates two snowballs and permanent bonus")
		check(battle._hand_row.get_child(0).data.value == 2 and "2点伤害" in battle._hand_row.get_child(0).data.text, "hand shows current snowball damage")
		await click(battle._hand_row.get_child(0))
		await process_frame
		check(battle._pending_target_card >= 0, "snowball target picker opens")
		check(not gs.valid_targets(0, battle._pending_target_card_def).has("avatar-1"), "snowball excludes avatar")
		await click(battle._unit_widget(str(e.units[2].uid)))
		await settled(battle)
		check(e.units[2].hp == 4 and p.snowballsPlayed == 1, "click target applies two damage and hand-use history")
		check(gs.effective_card_cost(0, gs.hand_card_def(0, 0)) == 1, "remaining snowball loses free instant allowance")
		battle._show_unit_popover(p.units[0], 0, 0)
		check("雪球已用1 · 伤害2" in texts(battle._tooltip), "source inspector exposes public history")
		await capture("%d-01-snowball-history" % physical.x)
		battle._hide_tooltip()
		hand(battle, ["c10607"])
		await process_frame
		check("本次使用2张" in battle._hand_row.get_child(0).data.text, "flurry displays actual cast count")
		await click(battle._hand_row.get_child(0))
		await process_frame
		check(gs.valid_targets(0, battle._pending_target_card_def).has("avatar-1"), "flurry offers enemy avatar")
		check(not gs.valid_targets(0, battle._pending_target_card_def).has("avatar-0"), "flurry excludes friendly avatar")
		await click(battle._enemy_plate)
		await settled(battle)
		check(e.avatarHp == 26 and p.snowballsPlayed == 1, "native avatar click executes two automatic snowballs")
		hand(battle, ["c10609"])
		await process_frame
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		var wall: Dictionary = gs.front_unit(0)
		check(wall.get("iceWall", false) and wall.hp == 4 and wall.attack == 0, "native card summons independent wall")
		var widget := battle._unit_widget(str(wall.get("uid", "")))
		check(widget != null and widget.is_inside_tree(), "real wall has clickable front widget")
		check(widget.drag_payload.is_empty(), "wall does not offer attack drag")
		check(battle._unit_widgets.size() == 9, "original eight widgets plus one summon")
		battle._show_unit_popover(wall, 0, 4)
		check("冰墙 · 不能攻击" in texts(battle._tooltip), "wall inspector explains summon rules")
		await capture("%d-02-ice-wall" % physical.x)
		battle._hide_tooltip()
		hand(battle, ["c10603"])
		await process_frame
		await click(battle._hand_row.get_child(0))
		await process_frame
		check(gs.valid_targets(0, battle._pending_target_card_def).has(wall.uid), "live summon remains a legal unit target")
		await click(battle._unit_widget(str(e.units[1].uid)))
		await settled(battle)
		check(e.units[1].frozen == 1, "collapse first click stuns enemy")
		hand(battle, ["c10603"])
		await process_frame
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(e.units[1].uid)))
		await settled(battle)
		check(e.units[1].hp == 0, "collapse next click destroys stunned enemy")
		# Entering a regular ally removes the summon and keeps original slots.
		check(gs.basic_attack(0, 2), "ordinary ally attacks and replaces wall")
		await settled(battle)
		check(wall.hp == 0 and wall.removed and not is_instance_valid(widget), "removed wall disappears from front and reserve")
		check(gs.player(0).units.slice(0, 4).size() == 4, "original four slots persist")
		check(not gs.valid_targets(0, {"target": "knocked-ally-any-level"}).has(wall.uid), "removed wall excluded from resurrection picker")
		await capture("%d-03-wall-replaced" % physical.x)
		root.remove_child(battle)
		battle.free()
		await process_frame
	# Release the native audio harness before quitting; headless never creates it.
	if Support.Sfx._music_tween != null and is_instance_valid(Support.Sfx._music_tween): Support.Sfx._music_tween.kill()
	Support.Sfx._music_name = ""
	if Support.Sfx._hub != null and is_instance_valid(Support.Sfx._hub):
		for voice in Support.Sfx._hub.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
				voice.stream = null
		Support.Sfx._hub.queue_free()
	Support.Sfx._voices.clear()
	Support.Sfx._music = null
	Support.Sfx._hub = null
	Support.Sfx._streams.clear()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("XUENV_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("XUENV_UI_OK")
	quit(0 if failures == 0 else 1)
