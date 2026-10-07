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
		printerr("PEACH_UI_FAIL ", message)

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
	for i in cards.size(): battle.gs.player(0).hand.append({"instanceId": "peach-ui-%d" % i, "definitionId": cards[i]})
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
		if not out.is_empty():
			DisplayServer.window_set_size(physical)
			DisplayServer.window_move_to_foreground()
		var battle := BattleScreen.new()
		battle.setup(["taohuayao", "yimulian", "zhen", "basalt"], ["taohuayao", "yimulian", "zhen", "basalt"], 10809)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for unit in p.units:
				unit.level = 3
				unit.passive_hooks = []
		root.add_child(battle)
		var p := battle.gs.player(0)
		var source: Dictionary = p.units[0]
		var ally: Dictionary = p.units[3]
		p.avatarHp = 17
		_prepare_hand(battle, ["c10801"])
		await create_timer(0.3).timeout
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "healing opens character selection")
		var avatar := _avatar_button(battle._ally_plate)
		_check(avatar is Button, "own avatar has real target control")
		_move(avatar.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid, "healing aim accepts own avatar")
		await process_frame
		_capture("%d-01-avatar-heal-selection" % physical.x)
		_click(avatar)
		_check(p.avatarHp == 22 and p.hand.is_empty(), "native avatar heal resolves one selected player")
		_check(battle._input_locked(), "heal presentation locks duplicate input")
		await _wait_battle(battle)
		_check(battle._ally_core.text == "22", "player health display updates")
		var inactive: Dictionary = p.units[2]
		inactive.level = 0
		battle.gs._knockout_unit(inactive)
		p.deck = [{"instanceId":"unrelated","definitionId":"c10805"},{"instanceId":"target-instance","definitionId":"c11604"}]
		p.energy = 1
		_prepare_hand(battle, ["c10802"])
		await process_frame
		_click(battle._hand_row.get_child(0))
		var face := battle._unit_widget(str(inactive.uid))
		_move(face.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid and face.selected, "search highlights knocked inactive ally")
		await process_frame
		_capture("%d-02-inactive-search" % physical.x)
		_click(face)
		_check(p.hand.size() == 1 and p.hand[0].instanceId == "target-instance" and p.energy == 1, "native search draws chosen unit from deck using instant")
		await _wait_battle(battle)
		_check(battle._hand_row.get_child(0).data.id == "c11604", "searched actual card appears in hand")
		inactive.level = 3
		inactive.hp = inactive.maxHp
		inactive.knockout = 0
		p.energy = 20
		ally.hp = 1
		_prepare_hand(battle, ["c10809", "c10805"])
		# Let the newly fanned pair reach its visible position before clicking.
		await create_timer(0.3).timeout
		_click(battle._hand_row.get_child(0))
		await _wait_battle(battle)
		_check(source.awakened and source.attack == 3 and source.maxHp == 7, "native awakening uses printed stats (awake=%s, attack=%s, hp=%s, hand=%s)" % [source.awakened, source.attack, source.maxHp, str(p.hand)])
		_click(battle._hand_row.get_child(0))
		_check(ally.hp == 13 and ally.maxHp == 18 and ally.attack == 7, "native bloom runs three separate heals and permanent growth")
		if not out.is_empty():
			await create_timer(0.7).timeout
			_capture("%d-03a-heal-sequence" % physical.x)
		await _wait_battle(battle)
		var popover := UIWidgets.make_unit_popover(source)
		_check("重复2次" in _labels(popover), "form inspector retains repeated random recovery")
		popover.free()
		_capture("%d-03-three-recoveries" % physical.x)
		battle.gs._knockout_unit(ally)
		_prepare_hand(battle, ["c10808"])
		await process_frame
		_click(battle._hand_row.get_child(0))
		face = battle._unit_widget(str(ally.uid))
		_check(face.selected, "revival highlights only knocked ally")
		_click(face)
		_check(ally.hp == 20 and ally.maxHp == 20 and ally.get("swift", false), "native spring revives full health with permanent growth and swift")
		if not out.is_empty():
			await create_timer(0.7).timeout
			_capture("%d-04a-revive-sequence" % physical.x)
		await _wait_battle(battle)
		face = battle._unit_widget(str(ally.uid))
		_check(face.data.get("swift", false), "unit display snapshot includes swift")
		popover = UIWidgets.make_unit_popover(ally)
		_check("迅捷" in _labels(popover), "inspector explains stored swift")
		popover.free()
		_capture("%d-04-spring-swift" % physical.x)
		p.energy = 0
		p.attackUsed = false
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_click(battle._unit_widget(str(ally.uid)))
		_check(battle._selected_attacker == 3, "zero-fire swift unit can be selected for attack")
		_click(battle._enemy_target_btn)
		_check(p.attackUsed and p.energy == 0 and not ally.get("swift", false), "native ordinary attack consumes swift without spending fire")
		await _wait_battle(battle)
		_capture("%d-05-free-basic-attack" % physical.x)
		_prepare_hand(battle, ["c10807"])
		await process_frame
		_check(battle.gs._kw(battle._hand_row.get_child(0).data, "instant"), "living-source mass revival hand dynamically displays instant")
		for unit in p.units: battle.gs._knockout_unit(unit)
		p.energy = 1
		_prepare_hand(battle, ["c10807"])
		await process_frame
		_check(battle._hand_row.get_child(0).playable, "mass revival hand is playable while owner is knocked")
		_check(not battle.gs._kw(battle._hand_row.get_child(0).data, "instant"), "dead-source mass revival shows no instant")
		_click(battle._hand_row.get_child(0))
		_check(p.energy == 0 and p.units.all(func(u): return int(u.hp) == int(u.maxHp)), "native dead-source mass revival returns whole team")
		_check(p.units.all(func(u): return not u.get("swift", false)), "group revival doesn't grant old-version group swift")
		await _wait_battle(battle)
		_check(not battle._input_locked(), "full revival presentation ends normally")
		_capture("%d-06-mass-revival" % physical.x)
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
	print("PEACH_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("PEACH_UI_OK")
	quit(0 if failures == 0 else 1)
