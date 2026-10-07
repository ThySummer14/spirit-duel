extends SceneTree
## Native input, response ordering, delayed protection and enhanced hand text.
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
		printerr("DATIANGOU_UI_FAIL ", message)

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
		battle.setup(["datiangou", "yaoginshi", "datiangou-gangfeng", "basalt"], ["datiangou", "yaoginshi", "datiangou-gangfeng", "basalt"], 10509)
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
		_prepare_hand(battle, ["c10509", "c10508"])
		await create_timer(0.4).timeout
		_click(battle._hand_row.get_child(0))
		_check(battle._pending_target_card == 0, "shield enters ally target mode")
		var target := battle._unit_widget(str(p.units[3].uid))
		_move(target.get_global_rect().get_center())
		await process_frame
		battle._process(0)
		_check(battle._aim.valid and "下个回合再获得2护甲" in battle._aim.hint, "aim explains both actual shield grants")
		await process_frame
		_capture("%d-01-shield-aim" % physical.x)
		_click(target)
		_check(p.units[3].shield == 2 and p.units[3].pendingShields.size() == 1, "native target click grants and schedules")
		await _wait_battle(battle)
		var popover := UIWidgets.make_unit_popover(p.units[3])
		_check("下回合护甲 +2" in _labels(popover), "popover displays scheduled effect")
		popover.free()
		popover = UIWidgets.make_unit_popover(source)
		_check("暴风之盾" in _labels(popover) and "已使用法术 1" in _labels(popover), "caster exposes retained spell and match history")
		popover.free()
		_prepare_hand(battle, ["c10508"])
		source.spellsUsed = 9
		battle._refresh()
		await create_timer(0.3).timeout
		_check("9/10" in battle._hand_row.get_child(0).data.text, "justice displays actual progress")
		source.spellsUsed = 10
		battle._refresh()
		await create_timer(0.3).timeout
		_check(battle._hand_row.get_child(0).data.effect == "destroy-enemy-units" and "消灭所有" in battle._hand_row.get_child(0).data.text, "existing hand face changes to the enhanced effect")
		_capture("%d-02-enhanced-justice" % physical.x)
		var destruction_before := battle.gs.snapshot().duplicate(true)
		var destruction_start: int = battle.gs.command_log.size()
		_click(battle._hand_row.get_child(0))
		var destruction_cues := Cues.build(destruction_before, battle.gs.snapshot().duplicate(true), battle.gs.command_log.slice(destruction_start))
		_check(destruction_cues.filter(func(c): return c.kind == "destroy").size() == 4 and not destruction_cues.any(func(c): return c.kind == "damage"), "destruction is presented without fictitious damage numbers")
		_check(battle.gs.player(1).units.all(func(u): return u.hp == 0), "native click executes destruction instead of fixed damage")
		await _wait_battle(battle)
		# Opponent attack triggers our real hand shield automatically.
		for unit in battle.gs.player(1).units:
			unit.hp = unit.maxHp
			unit.knockout = 0
			unit.front = 0
		p.units[3].front = 1
		p.units[3].shield = 0
		p.units[3].shieldExpires = 0
		p.units[3].erase("pendingShields")
		var hp: int = p.units[3].hp
		_prepare_hand(battle, ["c10509"])
		battle.gs.current_player = 1
		battle.gs.player(1).attackUsed = false
		battle._last_view = battle.gs.snapshot().duplicate(true)
		var before: Dictionary = battle._last_view.duplicate(true)
		var start: int = battle.gs.command_log.size()
		_check(battle.gs.basic_attack(1, 0), "opponent starts basic attack")
		var commands: Array = battle.gs.command_log.slice(start)
		var timeline := Cues.timeline(before, battle.gs.snapshot().duplicate(true), commands)
		_check(timeline.map(func(c): return c.c) == ["response_card", "basic_attack"], "presentation orders response before lunge")
		_check(p.units[3].hp == hp - 1 and p.hand.is_empty() and battle.gs.response_window.is_empty(), "automatic shield intercepts attack without manual dialog")
		battle._refresh()
		await process_frame
		_check(battle._input_locked(), "response sequence locks duplicate input")
		await create_timer(0.65).timeout
		var visible_response := false
		for node in battle._effects.get_children():
			if node.get_meta("automatic_source", "") == source.uid and node.modulate.a > 0.9: visible_response = true
		_check(visible_response, "response card appears before attack damage beat")
		_capture("%d-03-shield-response" % physical.x)
		await _wait_battle(battle)
		_check(not battle._input_locked(), "input restored after complete response chain")
		battle.gs.end_turn(1)
		battle._refresh()
		_check(p.units[3].shield == 2, "scheduled shield lands after own-turn cleanup")
		await _wait_battle(battle)
		_capture("%d-04-delayed-shield" % physical.x)
		p.levelUpUsed = true
		for unit in battle.gs.player(1).units:
			unit.hp = 20
			unit.maxHp = 20
			unit.front = 0
		_prepare_hand(battle, ["c10503"])
		await create_timer(0.3).timeout
		before = battle.gs.snapshot().duplicate(true)
		_click(battle._hand_row.get_child(0))
		var hits := Cues.random_hit_cues(before, battle.gs.snapshot().duplicate(true))
		_check(hits.size() == 6 and hits.all(func(h): return h.family == "wind"), "six actual random targets become six wind projectiles")
		_check(battle._input_locked(), "multi-hit cast holds input across all impacts")
		await create_timer(0.6).timeout
		_capture("%d-05-six-hit-wind" % physical.x)
		await _wait_battle(battle)
		_check(not battle._input_locked(), "multi-hit sequence finishes without stuck controls")
		battle.queue_free()
		await process_frame
	VerifySupport.cleanup_stores(stores)
	print("DATIANGOU_UI checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("DATIANGOU_UI_OK")
	quit(0 if failures == 0 else 1)

func _labels(node: Node) -> String:
	var value := str(node.text) if node is Label else ""
	for child in node.get_children(): value += "\n" + _labels(child)
	return value
