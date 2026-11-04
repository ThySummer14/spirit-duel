extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const Support := preload("res://scripts/verify_support.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
var checks := 0
var failures := 0
var out := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BATTLE_STATUS_UI_FAIL ", message)
func move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	root.push_input(event, true)
func click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	move(at)
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
	var value := str(node.text) + "\n" if node is Label or node is RichTextLabel else ""
	for child in node.get_children(): value += texts(child)
	return value
func hand(battle, ids: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "status-ui-%d" % i, "definitionId": ids[i]})
	battle._last_view = {}
	battle._refresh()
func settled(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.15).timeout
	await process_frame
func capture(name: String) -> void:
	if out.is_empty(): return
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
		if not out.is_empty():
			DisplayServer.window_set_size(physical)
			DisplayServer.window_move_to_foreground()
		var battle := Battle.new()
		battle.setup(["yaodaoji", "yingcao", "taohuayao", "yaoginshi"], ["jutun-tongzi", "bingyong", "datiangou", "yaoginshi"], 10801)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 0
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(battle)
		var p := battle.gs.player(0)
		hand(battle, ["c10702", "c10703", "c10802", "c10104"])
		await create_timer(0.25).timeout
		check(battle._instant_l.text == "瞬发 · 可用", "shared allowance starts lit")
		for i in [0, 1, 2]:
			var face = battle._hand_row.get_child(i)
			check(face.data.payment.usesInstant and face.data.payment.cost == 0, "hand shows effective free cost")
			check(face.enabled and face.playable, "first instant legal at zero fire")
		check(not battle._hand_row.get_child(3).data.payment.instant, "zero slash has no false instant badge")
		await capture("%d-01-instant-ready" % physical.x)
		click(battle._hand_row.get_child(0))
		check(p.energy == 0 and p.keywordUsage.instant.used, "real click spends allowance, not fire")
		var command: Dictionary = battle.gs.command_log.filter(func(c): return c.c == "play_card").back()
		check(Cues.played_card(command.a).payment.usesInstant, "played animation retains payment at use time")
		await settled(battle)
		check(battle._instant_l.text == "瞬发 · 已用", "shared allowance dims after actual play")
		check(battle._hand_row.get_child(0).data.payment.cost == 1 and not battle._hand_row.get_child(0).enabled, "remaining instant costs fire and disables")
		battle._on_hand_hover(true, battle._hand_row.get_child(0))
		await create_timer(0.2).timeout
		check("瞬发本回合已用 · 本次 1 鬼火" in texts(battle._tooltip), "hover explains used allowance and current cost")
		await capture("%d-02-instant-used" % physical.x)
		battle._hide_tooltip()
		# Target selection and cancellation must not reserve or spend instant.
		battle.gs.kw_usage(0, "instant").used = false
		hand(battle, ["c10802"])
		await create_timer(0.2).timeout
		click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0 and not p.keywordUsage.instant.used, "selecting targeted instant keeps allowance")
		escape()
		check(battle._pending_target_card == -1 and not p.keywordUsage.instant.used, "Escape does not consume instant")
		click(battle._hand_row.get_child(0))
		await process_frame
		click(battle._unit_widget(str(p.units[2].uid)))
		check(p.keywordUsage.instant.used and p.energy == 0, "target click completes real instant search")
		await settled(battle)
		# Multiple simultaneous marks, public on both sides. Actual lifecycle
		# is checked below; this composed state stress-tests badge geometry.
		var target: Dictionary = battle.gs.player(1).units[0]
		target.merge({"barrier": true, "swift": true, "frozen": 1, "charge": 3, "armorBreak": 2, "brittle": 2, "shutenFormUnyielding": true, "shutenHowlTurn": battle.gs.turn_counter, "awakened": true}, true)
		battle._last_view = {}
		battle._refresh()
		await process_frame
		var face = battle._unit_widget(str(target.uid))
		check(face.status_marks().size() == 9, "unit exposes every current status")
		var badges := Status.badge_layout(face.status_marks(), face.size)
		check(badges.back().mark.id == "overflow" and badges.back().mark.value == 3, "overflow count is explicit")
		for badge in badges: check(Rect2(Vector2.ZERO, face.size).encloses(badge.rect), "all badge hit geometry stays inside card")
		move(face.get_global_transform_with_canvas() * (face.size * 0.5))
		await create_timer(0.25).timeout
		check(is_instance_valid(battle._tooltip), "real hover opens status inspector")
		var labels := texts(battle._tooltip)
		for label in ["屏障", "迅捷", "眩晕", "充能 3", "破甲 2", "晶裂 2", "不屈", "狂啸", "已觉醒"]: check(label in labels, "full inspector retains " + label)
		check(battle._tooltip.get_global_rect().end.y <= root.size.y, "multi-status inspector fits viewport")
		await capture("%d-03-all-statuses" % physical.x)
		battle.gs._knockout_unit(target)
		battle._last_view = {}
		battle._refresh()
		await process_frame
		check("气绝" in texts(battle._tooltip) and not "狂啸" in texts(battle._tooltip), "open hover refreshes after real knockout")
		battle._hide_tooltip()
		check(face.status_marks().any(func(m): return m.id == "knockout"), "knockout shows separate purple timer")
		check(not face.status_marks().any(func(m): return m.id in ["barrier", "stun", "howl"]), "knockout removes stale combat marks")
		var timer_face = battle._unit_widget(str(p.units[3].uid))
		check(timer_face.status_marks().any(func(m): return m.id == "countdown" and m.active), "living ability timer remains distinct")
		await capture("%d-04-knockout-countdown" % physical.x)
		# Conditional instant updates when Peach dies and revives.
		hand(battle, ["c10807"])
		check(battle._hand_row.get_child(0).data.payment.instant, "living peach has conditional instant mark")
		battle.gs._knockout_unit(p.units[2])
		battle._last_view = {}
		battle._refresh()
		check(not battle._hand_row.get_child(0).data.payment.instant, "knocked peach loses mark on existing hand widget")
		p.units[2].hp = p.units[2].maxHp
		p.units[2].knockout = 0
		battle._refresh()
		check(battle._hand_row.get_child(0).data.payment.instant, "revival restores conditional instant mark")
		battle.gs.end_turn(0)
		battle.gs.end_turn(1)
		await settled(battle)
		check(battle._instant_l.text == "瞬发 · 可用", "new turn restores shared allowance display")
		check(not face.status_marks().any(func(m): return m.id == "howl"), "expired howl never lingers after turn change")
		battle.queue_free()
		for i in 4: await process_frame
	if is_instance_valid(Sfx._hub):
		Sfx._music_name = ""
		if is_instance_valid(Sfx._music_tween): Sfx._music_tween.kill()
		Sfx._music_tween = null
		for player in Sfx._hub.get_children():
			if player is AudioStreamPlayer:
				player.stop()
				player.stream = null
		Sfx._streams.clear()
		Sfx._voices.clear()
		Sfx._hub.queue_free()
		Sfx._music = null
		Sfx._hub = null
		await process_frame
		await create_timer(0.25).timeout
	Support.cleanup_stores(stores)
	print("BATTLE_STATUS_UI_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
