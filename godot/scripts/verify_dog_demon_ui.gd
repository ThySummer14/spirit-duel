extends SceneTree
const Battle := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Support := preload("res://scripts/verify_support.gd")
var checks := 0
var failures := 0
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DOG_DEMON_UI_FAIL ", message)
func click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	await process_frame
	await create_timer(0.14).timeout
	at = face.get_global_transform_with_canvas() * (face.size * 0.5)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = at
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input, true)
func escape() -> void:
	var input := InputEventKey.new()
	input.keycode = KEY_ESCAPE
	input.pressed = true
	root.push_input(input, true)
func texts(node: Node) -> String:
	var text := str(node.text) + "\n" if node is Label or node is RichTextLabel else ""
	for child in node.get_children(): text += texts(child)
	return text
func hand(battle, ids: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in ids.size(): battle.gs.player(0).hand.append({"instanceId": "dog-ui-%d" % i, "definitionId": ids[i]})
	battle._last_view = {}
	battle._refresh()
func settled(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.2).timeout
	await process_frame
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
		var battle := Battle.new()
		battle.setup(["quanshen", "caitongzi", "taohuayao", "yingcao"], ["quanshen", "caitongzi", "taohuayao", "yingcao"], 111121)
		battle._ai_thinking = true
		battle.gs.phase = "main"
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for unit in p.units: unit.level = 3
		root.add_child(battle)
		var gs = battle.gs
		var p: Dictionary = gs.player(0)
		var enemy: Dictionary = gs.player(1)
		hand(battle, ["c11102"])
		await create_timer(0.25).timeout
		await click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0, "ghost hand opens actual picker")
		check(gs.valid_targets(0, battle._pending_target_card_def).size() == 4, "picker lists reserve enemy units")
		check(not gs.valid_targets(0, battle._pending_target_card_def).has("avatar-1"), "ghost hand cannot aim at avatar")
		await capture("%d-01-ghost-target" % physical.x)
		escape()
		check(battle._pending_target_card == -1 and p.energy == 40, "cancel picker preserves fire")
		await click(battle._hand_row.get_child(0))
		await process_frame
		await click(battle._unit_widget(str(enemy.units[2].uid)))
		check(p.hand.is_empty() and p.energy == 39 and enemy.units[2].front == 1, "target click pulls selected unit and pays once")
		check(enemy.units[2].hp == 3 and enemy.avatarHp == 30, "UI resolves real combat against chosen enemy")
		await settled(battle)
		gs._knockout_unit(p.units[0])
		hand(battle, ["c12103"])
		await settled(battle)
		check(battle._hand_row.get_child(0).data.payment.cost == 0, "revive displays its 2021 instant cost")
		await click(battle._hand_row.get_child(0))
		check(p.units[0].hp == p.units[0].maxHp and p.hand.is_empty(), "click source-only revive without ally target picker")
		check(battle._pending_target_card == -1, "source-only revive never asks for unrelated ally")
		await settled(battle)
		hand(battle, ["xinshen-lianmo"])
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		hand(battle, ["c12108"])
		await click(battle._hand_row.get_child(0))
		await settled(battle)
		hand(battle, ["c12102"])
		check(gs.hand_card_def(0, 0).value == 1 and gs.hand_card_def(0, 0).combatOption.shield == 3, "enhanced hand card reflects entry history")
		battle._show_unit_popover(p.units[0], 0, 0)
		check("心技一体" in texts(battle._tooltip) and "1" in texts(battle._tooltip), "unit inspector explains current combat form")
		await capture("%d-02-training-form" % physical.x)
		battle._hide_tooltip()
		hand(battle, ["c11105"])
		await settled(battle)
		await click(battle._hand_row.get_child(0))
		check(battle._pending_target_card == 0 and gs.valid_targets(0, battle._pending_target_card_def).has(enemy.units[0].uid), "pursuit can target reserve with an occupied enemy front")
		check(not gs.valid_targets(0, battle._pending_target_card_def).has("avatar-1"), "pursuit cannot choose avatar through occupied front")
		escape()
		battle.queue_free()
		await process_frame
	Support.cleanup_audio()
	await process_frame
	await process_frame
	Support.cleanup_stores(stores)
	print("DOG_DEMON_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("DOG_DEMON_UI_OK")
	quit(0 if failures == 0 else 1)
