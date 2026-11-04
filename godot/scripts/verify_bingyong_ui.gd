extends SceneTree
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
var checks := 0
var failures := 0
var out := ""

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BINGYONG_UI_FAIL ", message)

func _move(at: Vector2) -> void:
	var input := InputEventMouseMotion.new()
	input.position = at
	root.push_input(input, true)

func _click(face: Control) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	_move(at)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = at
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = down
		root.push_input(input, true)

func _wait_battle(battle) -> void:
	for i in 3: await process_frame
	await create_timer(battle._presentation_remaining() + 0.08).timeout
	await process_frame

func _capture(name: String) -> void:
	if out.is_empty(): return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _prepare_hand(battle, cards: Array) -> void:
	battle.gs.player(0).hand.clear()
	for i in cards.size(): battle.gs.player(0).hand.append({"instanceId": "bingyong-ui-%d" % i, "definitionId": cards[i]})
	battle._last_view = {}
	battle._refresh()

func _avatar_button(plate: Control) -> Control:
	for child in plate.get_children():
		if child is Button: return child
	return plate

func _labels(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += "\n" + _labels(child)
	return result

func _run() -> void:
	var stores := VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	root.theme = ThemeBuilder.build_theme()
	for physical in [Vector2i(1280, 800), Vector2i(1600, 740)]:
		root.size = physical
		if not out.is_empty(): DisplayServer.window_set_size(physical)
		var battle := BattleScreen.new()
		battle.setup(["bingyong","yimulian","zhen","basalt"],["bingyong","yimulian","zhen","basalt"],10309)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for unit in p.units:
				unit.shield = 0
				unit.shieldExpires = 0
				unit.level = 3
				unit.passive_hooks = []
		root.add_child(battle)
		var p := battle.gs.player(0)
		var source: Dictionary = p.units[0]
		_prepare_hand(battle,["c10308"])
		await create_timer(0.2).timeout
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0,"ancient shield opens real ally selection")
		var selected := battle._unit_widget(str(source.uid))
		_move(selected.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid,"shield aiming accepts live owner")
		_capture("%d-01-shield-target" % physical.x)
		_click(selected)
		_check(source.shield == 5 and p.hand.is_empty(),"native shield selection resolves five armor")
		_check(battle._input_locked(),"shield effect locks duplicate inputs")
		await _wait_battle(battle)
		var hp: int = battle.gs.player(1).avatarHp
		_prepare_hand(battle,["c10301"])
		await process_frame
		_click(battle._hand_row.get_child(0))
		_check(battle.gs.player(1).avatarHp == hp-6,"native dust blade uses all current armor")
		await _wait_battle(battle)
		_check(source.attack == 1,"dust blade does not leak attack into permanent body")
		_capture("%d-02-dustblade" % physical.x)
		_prepare_hand(battle,["c10302"])
		source.front = 0
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_click(battle._hand_row.get_child(0))
		_check(source.front == 1 and source.maxHp == 9,"modern mountain installs 1/9 and enters battle area")
		_check(battle.gs.player(1).avatarHp == hp-6 and not p.attackUsed,"entry does not attack or spend ordinary attack")
		await _wait_battle(battle)
		_capture("%d-03-mountain-entry" % physical.x)
		_prepare_hand(battle,["c10303"])
		p.hand[0].enhanceCount = 3
		battle._last_view = {}
		battle._refresh()
		await create_timer(0.45).timeout
		var crash: Dictionary = battle._hand_row.get_child(0).data
		_check(crash.value == 5 and crash.combatOption.shield == 5 and "增强3次" in str(crash.text),"hand renders separate enhanced crash stats")
		_check(battle._hand_row.get_child(0).modulate.a > 0.99,"enhanced crash finishes its hand-entry animation before inspection")
		_capture("%d-04-enhanced-crash" % physical.x)
		_prepare_hand(battle,["c10305"])
		source.shield = 0
		source.shieldExpires = 0
		await process_frame
		_click(battle._hand_row.get_child(0))
		_check(source.attack == 4 and source.maxHp == 7 and source.shield == 2,"forest form renders actual base and entry armor")
		await _wait_battle(battle)
		battle.gs._damage_unit(0,0,50,1)
		battle._last_view = {}
		battle._refresh()
		_check(source.hp == 7 and source.shield == 0,"forest cap preserves hp while consuming last armor")
		await _wait_battle(battle)
		_capture("%d-05-forest-cap" % physical.x)
		var foe: Dictionary = battle.gs.player(1).units[0]
		var binding := ContentLoader.card_def("c10309")
		battle.gs._install_form(1,0,binding,binding.value)
		foe.front = 1
		source.front = 0
		p.units[3].front = 1
		_prepare_hand(battle,["c10301"])
		await create_timer(0.45).timeout
		_check(not battle._hand_row.get_child(0).playable,"dust bind visibly disables replacement combat card")
		_check(battle._hand_row.get_child(0).modulate.a > 0.99,"disabled dust blade is fully visible after entry animation")
		_click(battle._unit_widget(str(source.uid)))
		_check(battle._selected_attacker != 0,"dust bind prevents selecting illegal ordinary attacker")
		_capture("%d-06-dust-bind" % physical.x)
		foe.front = 0
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_check(battle._hand_row.get_child(0).playable,"moving binder out immediately restores combat-card playability")
		battle.queue_free()
		await process_frame
	# Preserve real native audio throughout every scenario, then release the
	# global mixer players before quitting so playback resources can drain.
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
	print("BINGYONG_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("BINGYONG_UI_OK")
	quit(0 if failures == 0 else 1)
