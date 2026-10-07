extends SceneTree
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const Phoenix := preload("res://scripts/phoenix_rules.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
var checks := 0
var failures := 0
var out := ""

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PHOENIX_UI_FAIL ", message)

func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	root.push_input(event, true)

func _click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	_move(at)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func _wait(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.1).timeout
	await process_frame

func _capture(name: String) -> void:
	if out.is_empty(): return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _hand(battle, cards: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in cards.size(): battle.gs.player(0).hand.append({"instanceId": "phoenix-ui-%d" % i, "definitionId": cards[i]})
	battle._last_view = {}
	battle._refresh()

func _run() -> void:
	var stores := VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	var completed_viewports := 0
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty():
			DisplayServer.window_set_size(physical)
			DisplayServer.window_move_to_foreground()
		var battle := BattleScreen.new()
		battle.setup(["fenghuanghuo", "datiangou", "yaoginshi", "basalt"], ["fenghuanghuo", "datiangou", "yaoginshi", "basalt"], 12409)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 40
			p.levelUpUsed = true
			for u in p.units:
				u.level = 3
				u.passive_hooks = []
		root.add_child(battle)
		var p: Dictionary = battle.gs.player(0)
		var e: Dictionary = battle.gs.player(1)
		var source: Dictionary = p.units[0]
		_hand(battle, ["c12403", "c12407", "c12405", "c12404"])
		await create_timer(0.3).timeout
		_click(battle._hand_row.get_child(0))
		_check(source.attack == 4 and source.hp == 6 and e.avatarHp == 30, "native form uses printed body without spell trigger")
		_check(battle._input_locked(), "form presentation prevents duplicate input")
		await _wait(battle)
		_check("3点伤害" in battle._hand_row.get_child(0).data.text, "ignite live hand text includes feather bonus")
		_check("6点伤害" in battle._hand_row.get_child(1).data.text, "dance includes current feather bonus")
		var popover := UIWidgets.make_unit_popover(source)
		_check("非战斗伤害+1" in _labels(popover), "inspector exposes active damage modifier")
		popover.free()
		e.units[3].front = 1
		e.units[0].hp = 3
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "ignite enters actual target selection")
		var target := battle._unit_widget(str(e.units[0].uid))
		_move(target.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid, "enemy reserve is a legal spell target")
		_check("3" in battle._aim.hint, "aim uses live spell damage")
		_capture("%d-01-ignite-target" % physical.x)
		_click(target)
		_check(e.units[0].hp == 0 and e.avatarHp == 27 and e.units[3].hp == 10, "targeted kill damages target owner then projects to front")
		_check(source.phoenixAvatarHits == 1, "native card records only actual avatar followup")
		await _wait(battle)
		_check("7点伤害" in battle._hand_row.get_child(0).data.text and "1次" in battle._hand_row.get_child(0).data.text, "dance hand refreshes historical enhancement")
		_capture("%d-02-enhanced-dance" % physical.x)
		e.units[3].hp = 4
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_click(battle._hand_row.get_child(0))
		_check(e.units[3].hp == 0 and e.avatarHp == 22, "native dance pierces for three and separately projects two")
		_check(source.phoenixAvatarHits == 3, "native piercing and passive each enhance next dance")
		await _wait(battle)
		_capture("%d-03-piercing-result" % physical.x)
		_click(battle._hand_row.get_child(0))
		var ally := battle._unit_widget(str(p.units[3].uid))
		_move(ally.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid, "one shikigami text allows living allied target")
		_capture("%d-04-friendly-target" % physical.x)
		_click(ally)
		_check(p.units[3].hp == 6 and e.avatarHp == 20, "friendly fire damages selected ally while base projectile stays hostile")
		await _wait(battle)
		_hand(battle, ["c12408", "c12806", "c12406", "c12401"])
		await create_timer(0.35).timeout
		_click(battle._hand_row.get_child(0))
		await _wait(battle)
		_check(source.awakened and source.attack == 5 and e.avatarHp == 18, "awakening retains form and fires once")
		_click(battle._hand_row.get_child(0))
		_check(e.avatarHp == 16, "teammate spell causes own phoenix projection")
		await _wait(battle)
		_capture("%d-05-team-spell" % physical.x)
		_click(battle._hand_row.get_child(0))
		await _wait(battle)
		_check(source.attack == 6 and source.hp == 7 and Phoenix.bonus(source) == 0, "cloud replaces feather but preserves awakening body")
		battle.gs.rng_state = 1000
		_click(battle._hand_row.get_child(0))
		_check(battle.gs.kw_usage(0, "fortune").get("last", {}).get("roll", -1) == 4, "cloud reports actual die face")
		_check(p.hand.size() == 1 and p.hand[0].definitionId == "c12404", "cloud creates usable phoenix fire card")
		await _wait(battle)
		_check(battle._hand_row.get_child_count() == 1 and battle._hand_row.get_child(0).data.name == "凤火", "generated card appears as real hand card")
		_check(not battle._input_locked(), "completed chain releases native input")
		_capture("%d-06-cloud-generation" % physical.x)
		e.hand.append({"instanceId": "phoenix-ui-counter", "definitionId": "c12807"})
		_hand(battle, ["c12401"])
		battle.gs.rng_state = 1
		await create_timer(0.35).timeout
		_click(battle._hand_row.get_child(0))
		_check(e.hand.is_empty() and p.hand.is_empty(), "actual magic response consumes both played cards")
		_check(e.avatarHp == 12, "countered phoenix cry still presents exactly one independent projectile")
		await _wait(battle)
		_check(not battle._input_locked(), "counter and pending ability finish their presentation chain")
		_capture("%d-07-countered-spell" % physical.x)
		source.hp = 5
		_hand(battle, ["c12404"])
		battle.gs.rng_state = 1
		await create_timer(0.35).timeout
		_click(battle._hand_row.get_child(0))
		var self_target := battle._unit_widget(str(source.uid))
		_click(self_target)
		_check(source.hp == 0, "native own target permits self-lethal phoenix fire")
		_check(e.avatarHp == 11, "source knockout does not erase already-created projectile")
		await _wait(battle)
		_check(not battle._input_locked(), "knockout and preserved projection release input")
		_capture("%d-08-self-lethal-spell" % physical.x)
		completed_viewports += 1
		battle.queue_free()
		await process_frame
	# Native audio runs on its own mixer thread. Release the global test
	# players before quitting so their final playback buffers can be collected.
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
	VerifySupport.cleanup_stores(stores)
	_check(completed_viewports == 2, "both viewport scenarios ran to completion")
	print("PHOENIX_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("PHOENIX_UI_OK")
	quit(0 if failures == 0 else 1)

func _labels(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += "\n" + _labels(child)
	return result
