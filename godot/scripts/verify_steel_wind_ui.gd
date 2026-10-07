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
		printerr("STEEL_UI_FAIL ", message)

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

func _origin_option(node: Node, origin: bool) -> Control:
	if node.has_meta("origin_option") and bool(node.get_meta("origin_option")) == origin: return node as Control
	for child in node.get_children():
		var found := _origin_option(child, origin)
		if found != null: return found
	return null

func _choose_origin(battle, origin: bool) -> void:
	await process_frame
	var face := _origin_option(battle, origin)
	_check(face != null, "origin choice has native selectable card")
	if face != null: _click(face)
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
		battle.setup(["datiangou-gangfeng", "yaoginshi", "bingyong", "yingcao"], ["basalt", "lumen", "rime", "ember"], 29002)
		battle._ai_thinking = true
		_check(battle.gs.player(0).units.size() == 4, "fixture has all four shikigami")
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for u in p.units:
				u.level = 3
				u.hp = 20
				u.maxHp = 20
				u.passive_hooks = []
		root.add_child(battle)
		_prepare_hand(battle, ["c29002", "c29001", "c29004", "c29005", "c29006"])
		await create_timer(0.35).timeout
		var unit: Dictionary = battle.gs.player(0).units[0]
		var face := battle._unit_widget(str(unit.uid))
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "leaf selects target before spending resources")
		_move(face.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.visible and battle._aim.valid and "抽1张牌" in battle._aim.hint, "aim previews movement plus conditional draw")
		await process_frame
		_capture("%d-01-leaf-aim" % physical.x)
		_click(face, MOUSE_BUTTON_RIGHT)
		_check(battle._pending_target_card == -1 and battle.gs.command_log.is_empty(), "right click cancels without card/energy use")
		_click(battle._hand_row.get_child(0))
		var enemy_face := battle._unit_widget(str(battle.gs.player(1).units[0].uid))
		_click(enemy_face)
		_check(battle._pending_target_card == 0 and battle.gs.command_log.is_empty(), "enemy click rejected without losing leaf")
		_click(face)
		_check(battle.gs.front_index(0) == 0 and battle.gs.command_log.size() == 1, "actual viewport click moves without an assault command")
		var amount: int = battle.gs.command_log.size()
		_click(face)
		_check(battle.gs.command_log.size() == amount and battle._input_locked(), "movement lock rejects duplicate input")
		await _wait_battle(battle)
		_check(not battle._input_locked(), "movement unlocks after animation")
		_capture("%d-02-leaf-moved" % physical.x)
		# One combat card, then leaf triggers the selected origin on a second move.
		_prepare_hand(battle, ["c29001", "c29002"])
		await create_timer(0.35).timeout
		_click(battle._hand_row.get_child(0))
		await _choose_origin(battle, false)
		await _wait_battle(battle)
		_check(int(unit.get("spellCountdown", {}).get("remaining", -1)) == 2, "combat visibly sets countdown")
		if unit.get("spellCountdown", {}).is_empty():
			printerr("INPUT_DIAGNOSTIC ", battle.gs.command_log, " pending=", battle._pending_target_card)
			battle.queue_free()
			await process_frame
			VerifySupport.cleanup_stores(fixture)
			quit(1)
			return
		unit.spellCountdown.remaining = 1
		battle._last_view = {}
		battle._refresh()
		await process_frame
		_click(battle._hand_row.get_child(0))
		face = battle._unit_widget(str(unit.uid))
		_move(face.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check("倒计时 -1" in battle._aim.hint, "aim switches from draw to real countdown reduction")
		await process_frame
		_capture("%d-03-countdown-aim" % physical.x)
		var before := battle.gs.snapshot().duplicate(true)
		_click(face)
		for i in 3: await process_frame
		var shown := false
		for effect in battle._effects.get_children():
			if effect.get_meta("automatic_source", "") == unit.uid: shown = true
		_check(shown, "origin showcase originates from its own shikigami")
		var changes := Cues.rule_changes(before, battle.gs.snapshot())
		_check(changes.any(func(e): return e.kind == "automatic-card" and e.card.name == "风神一扇"), "automatic origin retains correct card identity")
		await create_timer(0.65).timeout
		var readable := false
		for effect in battle._effects.get_children():
			if effect.get_meta("automatic_source", "") == unit.uid and effect.modulate.a > 0.95: readable = true
		_check(readable, "automatic card remains fully readable during hold, before fade")
		_capture("%d-04-origin-cast" % physical.x)
		await _wait_battle(battle)
		# Pursuit aim and animation must agree about the reserve target.
		battle.gs.player(1).units[0].front = 1
		_prepare_hand(battle, ["c29005", "c29006", "c29008"])
		await create_timer(0.35).timeout
		_click(battle._hand_row.get_child(0))
		await _choose_origin(battle, false)
		var reserve: Dictionary = battle.gs.player(1).units[2]
		var target := battle._unit_widget(str(reserve.uid))
		_check(battle._can_drop_command({"kind":"card", "hand":0}, reserve.uid), "pursuit supports reserve drop through occupied front")
		_click(target)
		for i in 3: await process_frame
		face = battle._unit_widget(str(unit.uid))
		_check(str(face.get_meta("attack_target_uid", "")) == reserve.uid, "pursuit lunge follows selected target")
		await create_timer(0.32).timeout
		_capture("%d-05-pursuit" % physical.x)
		await _wait_battle(battle)
		# Real hand-play choice, cancel, and use the spell without making an attack.
		_prepare_hand(battle, ["c29005"])
		await create_timer(0.35).timeout
		var spent: int = battle.gs.player(0).energy
		_click(battle._hand_row.get_child(0))
		await process_frame
		_check(is_instance_valid(battle._origin_choice_layer) and int(battle.gs.player(0).energy) == spent, "choice opens before consuming card or energy")
		_capture("%d-06-origin-choice" % physical.x)
		_click(_origin_option(battle, true), MOUSE_BUTTON_RIGHT)
		_check(not is_instance_valid(battle._origin_choice_layer) and battle.gs.player(0).hand.size() == 1, "cancel leaves original hand card intact")
		await process_frame
		_click(battle._hand_row.get_child(0))
		await _choose_origin(battle, true)
		_check(battle.gs.command_log.back().a.get("origin", false) and int(battle.gs.player(0).energy) == spent - 1, "native origin choice records one spell hand play")
		await _wait_battle(battle)
		# Restart removes old timer, barrier and pending animation data.
		battle.setup(["datiangou-gangfeng", "yaoginshi", "bingyong", "yingcao"], ["basalt", "lumen", "rime", "ember"], 29003)
		battle._ai_thinking = true
		_check(battle.gs.rule_events.is_empty() and battle.gs.player(0).units[0].get("spellCountdown", {}).is_empty(), "restart does not carry old countdown or events")
		battle.queue_free()
		await process_frame
		await process_frame
	VerifySupport.cleanup_stores(fixture)
	print("STEEL_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("STEEL_UI_OK")
	quit(0 if failures == 0 else 1)
