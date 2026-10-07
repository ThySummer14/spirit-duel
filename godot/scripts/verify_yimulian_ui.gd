extends SceneTree
## Native form lifecycle, response interception, countdown and player resources.
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
		printerr("YIMULIAN_UI_FAIL ", message)

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
		battle.setup(["yimulian", "yaoginshi", "datiangou-gangfeng", "basalt"], ["yimulian", "yaoginshi", "datiangou", "basalt"], 11809)
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
		_prepare_hand(battle, ["c11802", "c11803"])
		await create_timer(0.4).timeout
		_click(battle._hand_row.get_child(0))
		_check(source.form.cardId == "c11802" and source.attack == 2 and source.hp == 7, "native form click installs actual printed body")
		_check(source.formCountdown.remaining == 2 and int(p.get("avatarArmor", 0)) == 0, "entry waits for countdown before awakening")
		await _wait_battle(battle)
		var popover := UIWidgets.make_unit_popover(source)
		_check("倒计时 2 · 风符·护" in _labels(popover), "inspector identifies current form timer")
		_check(battle._unit_widget(str(source.uid)).data.formCountdown.remaining == 2, "battle face receives the same form timer as inspector")
		popover.free()
		var deck: int = p.deck.size()
		_click(battle._hand_row.get_child(0))
		_check(source.form.is_empty() and source.hp == 6 and p.avatarArmor == 5 and p.deck.size() == deck - 2, "native gale destroys, triggers, draws two")
		_check(battle._input_locked(), "departure chain locks repeated input")
		await _wait_battle(battle)
		_check(battle._ally_armor.visible and battle._ally_armor.text == "甲 5", "avatar plate exposes actual armor")
		_capture("%d-01-avatar-armor" % physical.x)
		_prepare_hand(battle, ["c11806", "c11804"])
		await create_timer(0.3).timeout
		_click(battle._hand_row.get_child(0))
		await _wait_battle(battle)
		_click(battle._hand_row.get_child(0))
		await _wait_battle(battle)
		_check(source.attack == 5 and source.shield == 0, "encourage form does not add fake self buffs")
		_check(battle._encourage_l.visible and "鼓舞 +3 / +3" == battle._encourage_l.text, "banked encouragement has a player resource indicator")
		_check(battle.get_global_rect().encloses(battle._encourage_l.get_global_rect()), "encourage indicator stays inside viewport")
		_capture("%d-02-encourage" % physical.x)
		# Use a real attack from the other side against our source to test the
		# conditional hand response, its form replacement, and animation order.
		source.front = 1
		source.hp = 1
		_prepare_hand(battle, ["c11808"])
		battle.gs.current_player = 1
		battle.gs.player(1).attackUsed = false
		battle._last_view = battle.gs.snapshot().duplicate(true)
		var before: Dictionary = battle._last_view.duplicate(true)
		var start: int = battle.gs.command_log.size()
		_check(battle.gs.basic_attack(1, 3), "opponent can attack")
		var timeline := Cues.timeline(before, battle.gs.snapshot().duplicate(true), battle.gs.command_log.slice(start))
		_check(timeline.map(func(c): return c.c) == ["response_card", "form_trigger", "basic_attack"], "response, old form departure and attack preserve order")
		_check(source.form.cardId == "c11808" and source.hp == 8 and source.attack == 8, "instant form with awakening intercepts actual damage")
		_check(battle.gs.kw_usage(0, "encourage").attack == 6 and p.hand.is_empty(), "old form leaves real encouragement before response finishes")
		battle._refresh()
		await process_frame
		_check(battle._input_locked(), "response locks input until all beats finish")
		await create_timer(0.55).timeout
		_capture("%d-03-instant-response" % physical.x)
		await _wait_battle(battle)
		popover = UIWidgets.make_unit_popover(source)
		_check("本回合结束自毁" in _labels(popover), "inspector exposes temporary form lifetime")
		popover.free()
		_check(battle.gs.end_turn(1), "opponent turn ends")
		battle._refresh()
		await _wait_battle(battle)
		_check(source.form.is_empty() and source.hp == 6 and source.attack == 4, "automatic self-destruction returns awakened basic body")
		_check(not battle._ally_armor.visible, "expired avatar armor leaves plate at owner start")
		p.energy = 20
		p.levelUpUsed = true
		for unit in battle.gs.player(1).units:
			unit.hp = unit.maxHp
			unit.knockout = 0
			unit.front = 0
		_prepare_hand(battle, ["c11807", "c12804"])
		await create_timer(0.3).timeout
		before = battle.gs.snapshot().duplicate(true)
		_click(battle._hand_row.get_child(0))
		_check(Cues.random_hit_cues(before, battle.gs.snapshot().duplicate(true)).size() == 1, "dragon entry presents actual first target")
		await _wait_battle(battle)
		popover = UIWidgets.make_unit_popover(source)
		_check("龙 · 下次最多2个目标" in _labels(popover), "active dragon exposes its growing target count")
		popover.free()
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "qin acceleration enters real target choice")
		var target := battle._unit_widget(str(source.uid))
		_move(target.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid and "倒计时 -2" in battle._aim.hint, "countdown target pointer recognizes form timer")
		_capture("%d-04-form-countdown-aim" % physical.x)
		before = battle.gs.snapshot().duplicate(true)
		_click(target)
		var hits := Cues.random_hit_cues(before, battle.gs.snapshot().duplicate(true))
		_check(hits.size() == 2 and hits.all(func(h): return h.family == "wind"), "second dragon wave has two actual wind impacts")
		_check(battle._input_locked(), "dragon chain holds controls across impacts")
		await create_timer(0.6).timeout
		_capture("%d-05-dragon-wave" % physical.x)
		await _wait_battle(battle)
		_check(not battle._input_locked(), "complete form chain releases controls")
		battle.queue_free()
		await process_frame
	VerifySupport.cleanup_stores(stores)
	print("YIMULIAN_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("YIMULIAN_UI_OK")
	quit(0 if failures == 0 else 1)

func _labels(node: Node) -> String:
	var value := str(node.text) if node is Label else ""
	for child in node.get_children(): value += "\n" + _labels(child)
	return value
