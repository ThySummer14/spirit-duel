extends SceneTree
## Native input acceptance for reference-video movement/countdown/pursuit.
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const Rules := preload("res://scripts/verified_card_rules.gd")
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
var checks := 0
var failures := 0
var out := ""

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("YAOQIN_UI_FAIL ", message)

func _move(at: Vector2) -> void:
	var input := InputEventMouseMotion.new()
	input.position = at
	root.push_input(input, true)

func _click(face: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var at := face.get_global_transform_with_canvas() * (face.size * 0.5)
	_move(at)
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = at
		input.button_index = button
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
	for i in cards.size(): battle.gs.player(0).hand.append({"instanceId": "test-%d" % i, "definitionId": cards[i]})
	battle._last_view = {}
	battle._refresh()

func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
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
		battle.setup(["yaoginshi", "datiangou-gangfeng", "basalt", "lumen"], ["yaoginshi", "datiangou-gangfeng", "basalt", "lumen"], 12808)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for u in p.units:
				u.level = 3
				u.passive_hooks = []
		root.add_child(battle)
		var p := battle.gs.player(0)
		var song: Dictionary = p.units[0]
		song.abilityCountdown.remaining = 3
		p.units[2].hp = 0
		p.units[2].knockout = 2
		_prepare_hand(battle, ["c12804", "c12805", "c12802", "c12808"])
		await create_timer(0.4).timeout
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "惊弦 enters target mode")
		var target := battle._unit_widget(str(p.units[2].uid))
		_move(target.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.visible and battle._aim.valid and "气绝倒计时 -2" in battle._aim.hint, "knocked teammate is a legal aimed target with exact countdown preview")
		await process_frame
		_capture("%d-01-revival-aim" % physical.x)
		_click(target)
		_check(p.units[2].hp > 0 and p.units[2].knockout == 0, "native click revives through countdown")
		await _wait_battle(battle)
		var foe: Dictionary = battle.gs.player(1).units[2]
		foe.hp = 0
		foe.knockout = 1
		_prepare_hand(battle, ["c12805", "c12808"])
		await create_timer(0.4).timeout
		_click(battle._hand_row.get_child(0))
		var ally_face := battle._unit_widget(str(song.uid))
		_click(ally_face)
		_check(battle._pending_target_card == 0 and p.hand.size() == 2, "疯魔 rejects ally without spending card")
		target = battle._unit_widget(str(foe.uid))
		_move(target.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid and "气绝倒计时 +2" in battle._aim.hint, "疯魔 previews extending enemy revival")
		await process_frame
		_capture("%d-02-delay-aim" % physical.x)
		_click(target)
		_check(foe.knockout == 3 and song.abilityHistory == ["healing"], "delay plus own ability trigger resolves through actual UI")
		await _wait_battle(battle)
		var ensemble: Control = battle._hand_row.get_child(0)
		_check("恢复3点生命" in ensemble.data.text and not "尚无" in ensemble.data.text, "existing hand face updates after ability history changes")
		_capture("%d-03-recorded-ensemble" % physical.x)
		_prepare_hand(battle, ["c12802", "c12803", "c12808"])
		await create_timer(0.4).timeout
		_click(battle._hand_row.get_child(0))
		_check(song.abilityCountdown.mode == "kagura", "native awakening switches current mode")
		await _wait_battle(battle)
		_click(battle._hand_row.get_child(0))
		_check(song.abilityCountdown.mode == "requiem" and song.abilityHistory == ["healing", "kagura"], "second awakening records old triggered mode before switching")
		await _wait_battle(battle)
		var popover := UIWidgets.make_unit_popover(song)
		_check(_labels(popover).contains("当前曲目 · 镇魂歌") and _labels(popover).contains("余韵、神乐歌"), "popover describes current ability and actual recorded history")
		popover.free()
		# Opponent uses a card; our response fires automatically, with no manual prompt.
		_prepare_hand(battle, ["c12807"])
		battle.gs.current_player = 1
		battle.gs.player(1).levelUpUsed = true
		battle.gs.player(1).hand = [{"instanceId":"enemy-attack", "definitionId":"c29001"}]
		battle._last_view = battle.gs.snapshot().duplicate(true)
		var before: int = p.avatarHp
		_check(battle.gs.play_card(1, 0), "opponent starts a combat card")
		battle._refresh()
		await process_frame
		_check(p.hand.is_empty() and p.avatarHp == before and battle.gs.response_window.is_empty(), "automatic counter cancels attack without manual response UI")
		_check(battle._input_locked(), "response animation locks duplicate input")
		await create_timer(1.4).timeout
		var response_visible := false
		for effect in battle._effects.get_children():
			if effect.get_meta("automatic_source", "") == song.uid and effect.modulate.a > 0.95: response_visible = true
		_check(response_visible, "response card appears from reacting shikigami and stays readable")
		_capture("%d-04-auto-counter" % physical.x)
		await _wait_battle(battle)
		_check(not battle._input_locked(), "response chain releases input after presentation")
		battle.queue_free()
		await process_frame
	VerifySupport.cleanup_stores(fixture)
	print("YAOQIN_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("YAOQIN_UI_OK")
	quit(0 if failures == 0 else 1)

func _labels(node: Node) -> String:
	var text := str(node.text) if node is Label else ""
	for child in node.get_children(): text += "\n" + _labels(child)
	return text
