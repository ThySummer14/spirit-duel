extends SceneTree
## Native poison countdown, damage conversion and conditional combat interactions.
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
		printerr("ZHEN_UI_FAIL ", message)

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
		battle.setup(["zhen", "yaoginshi", "yimulian", "basalt"], ["zhen", "yaoginshi", "yimulian", "basalt"], 11609)
		battle._ai_thinking = true
		for p in battle.gs.players:
			p.hand.clear()
			p.energy = 20
			p.levelUpUsed = true
			for unit in p.units:
				unit.level = 3
				unit.passive_hooks = []
				if unit.has("abilityCountdown"): unit.abilityCountdown.remaining = unit.abilityCountdown.reset
		root.add_child(battle)
		var p := battle.gs.player(0)
		var foe := battle.gs.player(1)
		var source: Dictionary = p.units[0]
		_prepare_hand(battle, ["c11602", "c12804", "c11605"])
		await create_timer(0.4).timeout
		_click(battle._hand_row.get_child(0))
		_check(foe.avatarArmorBreak == 2 and source.poisonTriggers == 1 and source.abilityCountdown.remaining == 2, "native revival click triggers real countdown and resets")
		_check(battle._input_locked(), "countdown chain locks duplicate input")
		await _wait_battle(battle)
		_check(battle._enemy_poison.visible and battle._enemy_poison.text == "破 2", "avatar poison has visible status")
		_check(battle.get_global_rect().encloses(battle._enemy_poison.get_global_rect()), "avatar poison stays within viewport")
		var popover := UIWidgets.make_unit_popover(source)
		_check("倒计时2" in _labels(popover) and "已触发1次" in _labels(popover), "inspector shows poison countdown and history")
		_check("大合奏" not in _labels(popover) and "当前曲目" not in _labels(popover), "poison ability never gets qin-only inspector labels")
		popover.free()
		_capture("%d-01-avatar-poison" % physical.x)
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "countdown acceleration enters real selection")
		var target := battle._unit_widget(str(source.uid))
		_move(target.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid and "倒计时 -2" in battle._aim.hint, "aim recognizes poison timer")
		_capture("%d-02-countdown-target" % physical.x)
		_click(target)
		_check(foe.avatarArmorBreak == 4 and source.poisonTriggers == 2, "selected poison timer stacks exact status")
		await _wait_battle(battle)
		_check("已触发2次" in battle._hand_row.get_child(0).data.text, "hand awakening refreshes actual history")
		_click(battle._hand_row.get_child(0))
		await _wait_battle(battle)
		_check(source.awakened and source.attack == 3 and source.poisonTriggers == 3, "native awakening uses recorded rules")
		foe.units[3].front = 1
		p.avatarHp = 10
		_prepare_hand(battle, ["c11604", "c11608"])
		await create_timer(0.2).timeout
		_click(battle._hand_row.get_child(0))
		_check(source.hp == 5 and foe.units[3].hp == 12 and foe.units[3].armorBreak == 7 and source.armorBreak == 1, "manual toxic card converts both sides of original combat")
		await _wait_battle(battle)
		_check(battle._unit_widget(str(foe.units[3].uid)).data.armorBreak == 7, "unit face shows actual poison")
		_capture("%d-03-toxic-combat" % physical.x)
		_click(battle._hand_row.get_child(0))
		_check(p.avatarHp == 22 and foe.units[3].hp == 0, "native temptation detonates poison and heals by damage")
		await _wait_battle(battle)
		_capture("%d-04-conditional-lifesteal" % physical.x)
		foe.units[3].hp = foe.units[3].maxHp
		foe.units[3].knockout = 0
		source.front = 1
		_prepare_hand(battle, ["c11604"])
		battle.gs.current_player = 1
		foe.attackUsed = false
		battle._last_view = battle.gs.snapshot().duplicate(true)
		var before: Dictionary = battle._last_view.duplicate(true)
		var start: int = battle.gs.command_log.size()
		_check(battle.gs.basic_attack(1, 3), "opponent makes a real attack")
		var commands: Array = battle.gs.command_log.slice(start)
		_check(commands.size() == 1, "response doesn't generate another attack command")
		_check(Cues.timeline(before, battle.gs.snapshot().duplicate(true), commands).map(func(c): return c.c) == ["response_card", "basic_attack"], "response is shown before incoming combat")
		_check(source.hp == 5 and foe.units[3].hp == 12 and foe.units[3].armorBreak == 7, "response protects within single battle")
		battle._refresh()
		await process_frame
		_check(battle._input_locked(), "response animation locks input")
		await create_timer(0.55).timeout
		_capture("%d-05-toxic-response" % physical.x)
		await _wait_battle(battle)
		_check(not battle._input_locked(), "response finishes and releases input")
		battle.gs.current_player = 0
		p.energy = 20
		for unit in foe.units: unit.front = 0
		_prepare_hand(battle, ["c11606", "c11602", "c11607"])
		await create_timer(0.2).timeout
		_click(battle._hand_row.get_child(0))
		await _wait_battle(battle)
		_check(source.attack == 6 and source.hp == 7, "scatter installs printed form plus permanent awakening")
		popover = UIWidgets.make_unit_popover(source)
		_check("破甲效果转化为等量伤害" in _labels(popover), "inspector retains form ability beside base countdown")
		popover.free()
		var damage := 2 + int(source.poisonTriggers) + int(foe.avatarArmorBreak)
		var hp: int = foe.avatarHp
		_click(battle._hand_row.get_child(0))
		_check(foe.avatarHp == hp - damage and foe.avatarArmorBreak == 0, "scatter converts actual growing poison and detonates existing status")
		await _wait_battle(battle)
		_check(not battle._enemy_poison.visible, "detonated status leaves avatar UI")
		_capture("%d-06-scatter-countdown" % physical.x)
		battle.queue_free()
		await process_frame
	VerifySupport.cleanup_stores(stores)
	print("ZHEN_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("ZHEN_UI_OK")
	quit(0 if failures == 0 else 1)

func _labels(node: Node) -> String:
	var value := str(node.text) if node is Label else ""
	for child in node.get_children(): value += "\n" + _labels(child)
	return value
