extends SceneTree
## 字体、音量持久化、弹层输入、手牌边界与异步 AI 生命周期回归。
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const MainScene := preload("res://scenes/main_menu.tscn")
const VerifySupport := preload("res://scripts/verify_support.gd")
const ALLY := ["ember", "basalt", "lumen", "rime"]
const FOE := ["storm", "kongo", "frostblade", "ink"]
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PRESENTATION_FAIL ", message)

func _run() -> void:
	var fixture := VerifySupport.isolate_stores()
	root.size = Vector2i(1280, 800)
	root.theme = ThemeBuilder.build_theme()
	for font in [ThemeBuilder.sys_font(), ThemeBuilder.display_font()]:
		for ch in "敌对焰瞬勾御札眩晕归队":
			_check(font.has_char(ch.unicode_at(0)), "bundled font contains %s" % ch)
	var directory := DirAccess.open("res://assets/audio")
	var sounds := 0
	for filename in directory.get_files():
		if not filename.ends_with(".wav"): continue
		var stream := Sfx._stream(filename.trim_suffix(".wav"))
		_check(stream is AudioStreamWAV and stream.get_length() > 0, "audio imports and decodes: %s" % filename)
		if stream is AudioStreamWAV:
			_check((stream.loop_mode != AudioStreamWAV.LOOP_DISABLED) == filename.begins_with("bgm_"), "music loops continuously and effects remain one-shot: %s" % filename)
		sounds += 1
	_check(sounds == 22, "all 22 generated sounds are present")
	await _verify_settings()
	await _verify_lifted_hit_area()
	await _verify_hand_and_modal()
	await _verify_battle_feel()
	await _verify_moving_hit_feedback()
	await _verify_ai_lifecycle()
	VerifySupport.cleanup_stores(fixture)
	print("PRESENTATION checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("PRESENTATION_OK")
	quit(0 if failures == 0 else 1)

func _verify_settings() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	main._show_settings()
	var sliders: Array = main._current.find_children("*", "HSlider", true, false)
	_check(sliders.size() == 2, "settings provides separate music and SFX controls")
	for slider in sliders:
		slider.value = 0 if slider.get_meta("channel") == "music" else 35
	_check(is_zero_approx(float(Sfx.settings().music)) and is_equal_approx(float(Sfx.settings().sfx), 0.35), "slider input changes both volumes")
	Sfx._settings.clear()
	_check(is_zero_approx(float(Sfx.settings().music)) and is_equal_approx(float(Sfx.settings().sfx), 0.35), "volumes survive a settings reload")
	Sfx.set_volume("music", 3)
	_check(is_equal_approx(float(Sfx.settings().music), 1), "volume clamps to the supported range")
	var file := FileAccess.open(Sfx.storage_path, FileAccess.WRITE)
	file.store_string('{"music":"invalid","sfx":9}')
	file.close()
	Sfx._settings.clear()
	_check(is_equal_approx(float(Sfx.settings().music), 0.6) and is_equal_approx(float(Sfx.settings().sfx), 1), "malformed settings cannot break the next launch")
	main.queue_free()
	await process_frame

func _verify_hand_and_modal() -> void:
	root.size = Vector2i(1280, 800)
	var battle := BattleScreen.new()
	battle.setup(ALLY, FOE, 20261004)
	battle._ai_thinking = true
	root.add_child(battle)
	var hand: Array = battle.gs.player(0).hand
	while hand.size() < 12:
		hand.append({"instanceId": "presentation-%d" % hand.size(), "definitionId": "flash-thrust"})
	battle._refresh()
	await create_timer(0.35).timeout
	_check(battle._hand_row.get_child_count() == 12, "the complete twelve-card hand remains inspectable")
	for card in battle._hand_row.get_children():
		var inside := true
		for corner in [Vector2.ZERO, Vector2(card.size.x, 0), card.size, Vector2(0, card.size.y)]:
			var point: Vector2 = card.get_global_transform() * corner
			inside = inside and point.x >= 0 and point.x <= 1280 and point.y >= 0 and point.y <= 800
		_check(inside, "rotated hand card stays completely inside the viewport")
	var face: Control = battle._hand_row.get_child(5)
	var rest_position := face.position
	face._set_hover(true)
	await create_timer(0.2).timeout
	_check(face.position.is_equal_approx(rest_position) and face.visual_offset.y < 0 and face.visual_scale > 1, "hover lifts the drawing without moving its hit area")
	var commands_before := battle.gs.command_log.size()
	var long_card: Dictionary = ContentLoader.card_def("flash-thrust").duplicate(true)
	long_card.text = "完整牌文必须保持可读。".repeat(100)
	var modal := UIWidgets.show_card_modal(battle, long_card)
	await create_timer(0.3).timeout
	var scroll := modal.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	_check(scroll.size.y <= 500 and scroll.get_v_scroll_bar().max_value > scroll.size.y, "long rules scroll inside a bounded inspector")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	root.push_input(escape)
	await create_timer(0.2).timeout
	_check(not is_instance_valid(modal), "Esc closes the active modal through viewport input")
	_check(battle.gs.command_log.size() == commands_before, "closing an inspector never executes a battle command")
	face._set_hover(false)
	battle.gs.level_up(0, 1)
	battle.gs.basic_attack(0, 0)
	_check(_portrait_count(battle) == 8, "moving to the front line reuses the same eight portraits")
	battle.setup(ALLY, FOE, 20261005)
	battle._ai_thinking = true
	_check(_portrait_count(battle) == 8 and battle._unit_widgets.size() == 8, "restarting a mounted battle does not duplicate portrait nodes")
	battle.queue_free()
	await process_frame

func _verify_lifted_hit_area() -> void:
	var clicks := [0]
	var card := UIWidgets.make_hand_card(ContentLoader.card_def("flash-thrust"), true, func(_i, _def): clicks[0] += 1)
	root.add_child(card)
	card.position = Vector2(500, 400)
	card.size = Vector2(124, 192)
	card.visual_offset = Vector2(0, -60)
	card.visual_scale = 1.16
	await process_frame
	# 用户点悬停后抬起的牌面上缘；此处在原始矩形之外、绘制矩形之内。
	var point := Vector2(560, 370)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click)
	await process_frame
	_check(clicks[0] == 1, "the visibly lifted card can be clicked above its original hit rectangle")
	card.drag_payload = {"kind": "card", "hand": 0}
	var drag_start := InputEventMouseButton.new()
	drag_start.position = point
	drag_start.button_index = MOUSE_BUTTON_LEFT
	drag_start.pressed = true
	root.push_input(drag_start)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = point + Vector2(60, 0)
	drag_motion.relative = Vector2(60, 0)
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag_motion)
	await process_frame
	_check(root.gui_is_dragging() and root.gui_get_drag_data() == card.drag_payload, "dragging the lifted card passes its payload through the transparent button")
	drag_start.pressed = false
	drag_start.position = drag_motion.position
	root.push_input(drag_start)
	await process_frame
	_check(clicks[0] == 1 and not root.gui_is_dragging(), "cancelling a card drag does not accidentally play the card")
	card.queue_free()
	await process_frame

func _verify_ai_lifecycle() -> void:
	var battle := BattleScreen.new()
	battle.setup(ALLY, FOE, 20261006)
	root.add_child(battle)
	battle.gs.end_turn(0)
	battle._check_auto_ai()
	battle.setup(ALLY, FOE, 20261007)
	await create_timer(0.7).timeout
	_check(battle.gs.current_player == 0 and battle.gs.command_log.is_empty(), "an old AI timer cannot act in the restarted game")
	var enemy: Dictionary = battle.gs.player(1)
	battle.gs.current_player = 1
	enemy.levelUpUsed = true
	enemy.energy = 2
	enemy.hand = [{"instanceId": "ai-presentation", "definitionId": "gust-guard"}]
	for unit in enemy.units: unit.level = 3
	battle._refresh()
	var legality := battle.gs.can_play_card(1, 0, enemy.units[0].uid)
	_check(battle.gs.play_card(1, 0, enemy.units[0].uid), "AI presentation fixture plays a legal spell: %s" % legality.get("reason", ""))
	var command_count := battle.gs.command_log.size()
	battle._check_auto_ai()
	await create_timer(0.45).timeout
	_check(battle.gs.command_log.size() == command_count, "AI waits while its large card showcase is still visible")
	await create_timer(1.0).timeout
	_check(battle.gs.command_log.size() > command_count, "AI resumes autonomously when the showcase has finished")
	var state_ref: WeakRef = weakref(battle.gs)
	battle.queue_free()
	await process_frame
	_check(state_ref.get_ref() == null, "freeing a battle immediately releases its state despite pending AI/presentation timers")

func _portrait_count(battle: BattleScreen) -> int:
	var count := 0
	for box in [battle._enemy_reserve, battle._enemy_front, battle._ally_front, battle._ally_reserve]:
		count += box.get_children().filter(func(child): return child.has_meta("unit_uid")).size()
	return count


func _verify_moving_hit_feedback() -> void:
	root.size = Vector2i(1280, 800)
	var battle := BattleScreen.new()
	battle.setup(ALLY, FOE, 20261010)
	battle._ai_thinking = true
	root.add_child(battle)
	for player in battle.gs.players:
		player.hand.clear()
		player.levelUpUsed = true
		for unit in player.units: unit.level = 3
	var attacker: Dictionary = battle.gs.player(0).units[1]
	var defender: Dictionary = battle.gs.player(1).units[0]
	for unit in [attacker, defender]:
		unit.maxHp = 10
		unit.hp = 10
		unit.shield = 0
	attacker.attack = 2
	defender.attack = 3
	defender.front = 1
	battle._refresh()
	await create_timer(0.35).timeout
	var source := battle._unit_widget(str(attacker.uid))
	var target := battle._unit_widget(str(defender.uid))
	# 通过真实卡面按钮输入，从准备区选中出击者，再点击敌方前线。
	for face in [source, target]:
		var point: Vector2 = face.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click)
	_check(battle.gs.command_log.size() == 1 and battle._input_locked(), "viewport clicks select an attacker and execute one attack")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	_check(battle.gs.current_player == 0 and battle.gs.command_log.size() == 1, "real Enter input cannot skip the active attack")
	await create_timer(0.48).timeout
	var labels: Array = battle._effects.get_children().filter(func(node): return node is Label and node.text == "-3" and node.has_meta("anchor"))
	_check(labels.size() == 1, "counterattack damage appears exactly once at impact")
	if labels.size() == 1:
		var anchor: Vector2 = labels[0].get_meta("anchor")
		_check(anchor.distance_to(battle._center_of(source)) > 50.0, "counterattack damage follows the lunging portrait instead of its empty resting slot")
	await create_timer(battle._presentation_remaining() + 0.1).timeout
	_check(attacker.hp == 7 and defender.hp == 8 and source.visual_offset.length() < 0.1 and source.z_index == 0, "the real attack settles with correct damage and a restored portrait")
	battle.queue_free()
	await process_frame


func _verify_battle_feel() -> void:
	root.size = Vector2i(1280, 800)
	var battle := BattleScreen.new()
	battle.setup(ALLY, FOE, 20261008)
	battle._ai_thinking = true
	root.add_child(battle)
	await process_frame
	await process_frame
	var state := battle.gs
	var own := state.player(0)
	var enemy := state.player(1)
	# 两个不同式神均能合法升勾，连续输入的拦截必须来自演出节奏，而非规则碰巧拒绝。
	battle._on_unit_clicked(own.units[1], 0, 1)
	var count := state.command_log.size()
	_check(battle._input_locked() and battle._end_btn.disabled, "level-up immediately reserves its presentation beat")
	battle._on_end_turn()
	_check(state.current_player == 0 and state.command_log.size() == count, "Enter or click cannot skip a level-up animation")
	await create_timer(battle._presentation_remaining() + 0.05).timeout
	_check(not battle._input_locked() and not battle._end_btn.disabled, "controls resume automatically after the animation")
	for p in state.players:
		p.levelUpUsed = true
		for unit in p.units: unit.level = 3
	own.hand = [{"instanceId": "feel-brace-a", "definitionId": "brace"}, {"instanceId": "feel-brace-b", "definitionId": "brace"}]
	own.energy = 2
	enemy.units[0].front = 1
	battle._refresh()
	await create_timer(0.3).timeout
	var source := battle._unit_widget(str(own.units[0].uid))
	var defender := battle._unit_widget(str(enemy.units[0].uid))
	var reserve := battle._unit_widget(str(enemy.units[1].uid))
	battle._on_unit_clicked(own.units[0], 0, 0)
	var aim := battle._aim_context(defender.get_global_rect().get_center())
	_check(aim.get("valid", false) and aim.target == enemy.units[0].uid, "attack line snaps to the defending front unit")
	_check(not battle._aim_context(reserve.get_global_rect().get_center()).valid, "a reserve unit is marked as an invalid attack target")
	_check(not battle._aim_context(battle._enemy_plate.get_global_rect().get_center()).valid, "front-line defenders prevent aiming at the core")
	count = state.command_log.size()
	battle._on_unit_clicked(enemy.units[1], 1, 1)
	_check(state.command_log.size() == count and battle._selected_attacker == 0, "invalid targets give feedback without discarding the attack selection")
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	root.push_input(cancel)
	await process_frame
	_check(battle._selected_attacker < 0 and battle._aim_context(Vector2.ZERO).is_empty(), "right-click cancels the aim without executing an action")
	battle._on_hand_clicked(0, ContentLoader.card_def("brace"))
	_check(battle._aim_context(source.get_global_rect().get_center()).valid, "targeted spells point to a legal ally")
	_check(not battle._aim_context(defender.get_global_rect().get_center()).valid, "ally spells reject enemy targets")
	battle._on_unit_clicked(own.units[0], 0, 0)
	count = state.command_log.size()
	var energy := int(own.energy)
	var shield := int(own.units[0].shield)
	_check(battle._input_locked() and own.hand.size() == 1, "playing a card starts a short exclusive presentation")
	battle._on_hand_clicked(0, ContentLoader.card_def("brace"))
	battle._drop_command({"kind": "card", "hand": 0}, own.units[0].uid)
	battle._on_unit_clicked(own.units[0], 0, 0)
	battle._on_end_turn()
	_check(state.command_log.size() == count and int(own.energy) == energy and int(own.units[0].shield) == shield and own.hand.size() == 1, "repeated click, drag and keyboard paths cannot consume a second card during the beat")
	await create_timer(battle._presentation_remaining() + 0.05).timeout
	_check(battle._hand_row.get_child(0).enabled, "the remaining legal card is playable again after its predecessor lands")
	battle._on_unit_clicked(own.units[0], 0, 0)
	battle._on_unit_clicked(enemy.units[0], 1, 0)
	_check(own.attackUsed and battle._input_locked(), "clicking the defending target executes and presents a real attack")
	await create_timer(battle._presentation_remaining() + 0.1).timeout
	_check(source.visual_offset.length() < 0.1 and source.z_index == 0 and _portrait_count(battle) == 8, "entry, lunge, hit and recoil settle with eight stable portrait nodes")
	# 演出期间重开，旧的解锁定时器与浮字不得污染新对局。
	for unit in state.player(0).units: unit.level = 3
	own.attackUsed = false
	own.energy = 2
	battle._refresh()
	battle._drop_command({"kind": "unit", "unit": 0}, null)
	battle.setup(ALLY, FOE, 20261009)
	battle._ai_thinking = true
	await create_timer(1.0).timeout
	_check(not battle._input_locked() and battle.gs.command_log.is_empty() and battle._effects.get_child_count() == 0, "restarting clears presentation locks and invalidates delayed feedback from the old match")
	battle.queue_free()
	await process_frame
