extends SceneTree
## 截图各主界面，便于视觉验收。用法: Godot --path godot --script res://scripts/capture_ui.gd

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const MainMenuScreen := preload("res://scripts/ui/main_menu.gd")
const FormationScreen := preload("res://scripts/ui/formation_screen.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")
const CollectionScreen := preload("res://scripts/ui/collection_screen.gd")
const DeckBuilderScreen := preload("res://scripts/ui/deck_builder.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const ResultScreen := preload("res://scripts/ui/result_screen.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")
const MainScene := preload("res://scenes/main_menu.tscn")

var _root: Control
var _shot_dir := "user://shots"
var _fixture := ""


func _init() -> void:
	_fixture = VerifySupport.isolate_stores()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_shot_dir = args[0]
	var viewport_size := Vector2i(1280, 800)
	if args.size() > 1:
		var parts := args[1].split("x")
		if parts.size() == 2: viewport_size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	DisplayServer.window_set_size(viewport_size)
	DisplayServer.window_move_to_foreground()
	root.size = viewport_size
	root.gui_disable_input = true
	_root = Control.new()
	_root.theme = ThemeBuilder.build_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 窗口尺寸是物理像素；canvas_items 已把逻辑尺寸缩放，不能再按物理尺寸设最小值。
	_root.custom_minimum_size = Vector2(1280, 800)
	root.add_child(_root)
	if args.has("style"): _capture_style.call_deferred()
	else: _capture_all.call_deferred()


func _clear() -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.free()


func _shot(name: String) -> void:
	# 等待手牌布局、翻卡与回合横幅结束后抓稳定画面。
	await create_timer(1.4).timeout
	await process_frame
	await process_frame
	# macOS 上失焦窗口可能复用上一帧；验收必须抓取当前场景的真实渲染。
	RenderingServer.force_draw(false)
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_shot_dir, name]
	img.save_png(path)
	print("SHOT ", path)


func _capture_all() -> void:
	await process_frame
	# 1 menu
	_clear()
	var menu := MainMenuScreen.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(menu)
	await _shot("01-menu")

	# 2 formation
	_clear()
	var form := FormationScreen.new()
	form.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(form)
	form.set_preselect(["ember", "basalt", "lumen", "rime"])
	await _shot("02-formation")
	form._inspect_card(ContentLoader.card_def("flash-thrust"))
	await _shot("02b-card-inspector")

	# 3 deck builder
	_clear()
	var deck := DeckBuilderScreen.new()
	deck.setup("ember")
	deck.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(deck)
	await _shot("03-deck")

	# 4 codex
	_clear()
	var codex := CodexScreen.new()
	codex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(codex)
	await _shot("04-codex")

	# 5 collection
	_clear()
	var col := CollectionScreen.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(col)
	await _shot("05-collection")
	col._buy_btn.pressed.emit()
	col._open_btn.pressed.emit()
	await _shot("05b-sealed-cards")
	col._flip_reveal(0)
	await create_timer(0.45).timeout
	await _shot("05c-first-reveal")
	col._reveal_all_btn.pressed.emit()
	await _shot("05d-revealed-cards")
	col._finish_btn.pressed.emit()

	# 6 battle
	_clear()
	var battle := BattleScreen.new()
	battle.setup(["ember", "basalt", "lumen", "rime"], ["storm", "kongo", "frostblade", "ink"], 20260922, {}, {}, true)
	battle._ai_thinking = true
	battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(battle)
	battle._mulligan_selected = [0, 2]
	battle._render_opening_cards()
	await _shot("06a-opening-choice")
	battle.gs.confirm_opening([0, 2])
	await _shot("06-battle")
	battle._show_tooltip(UIWidgets.make_tooltip(battle.gs.hand_card_def(0, 0)))
	await _shot("06a-card-preview")
	battle._hide_tooltip()
	battle.gs.level_up(0, 1)
	battle.gs.basic_attack(0, 0)
	battle.gs.end_turn(0)
	battle.gs.level_up(1, 1)
	battle.gs.basic_attack(1, 1)
	await _shot("06b-front-lines")
	while battle.gs.player(0).hand.size() < 12: _inject(battle.gs, 0, "flash-thrust")
	battle._refresh()
	await _shot("06e-twelve-cards")
	battle._hand_row.get_child(5)._set_hover(true)
	await _shot("06f-hand-hover")

	_clear()
	battle = BattleScreen.new()
	battle.setup(["rime", "ember", "basalt", "lumen"], ["yaodaoji", "jutun-tongzi", "bingyong", "taohuayao"], 777004)
	battle._ai_thinking = true
	_root.add_child(battle)
	_inject(battle.gs, 0, "hoar-barrier")
	var attack := _inject(battle.gs, 1, "c10101")
	battle.gs.end_turn(0)
	battle.gs.level_up(1, 1)
	battle.gs.play_card(1, attack)
	await _shot("06c-response")

	_clear()
	battle = BattleScreen.new()
	battle.setup(["ink", "ember", "basalt", "lumen"], ["storm", "kongo", "frostblade", "rime"], 888001)
	battle._ai_thinking = true
	_root.add_child(battle)
	battle.gs.player(0).units[0].level = 2
	battle.gs.level_up(0, 1)
	var divination := _inject(battle.gs, 0, "index-page")
	battle.gs.play_card(0, divination)
	await _shot("06d-divination")

	# 7 result
	_clear()
	var result := ResultScreen.new()
	result.setup(true, "种子 20260922 · 回合 12 · 获得 300 御札", [{"c": "play_card", "p": 0, "t": 1, "a": {"card": "flash-thrust"}}, {"c": "assault", "p": 0, "t": 1, "a": {"bonus": 2}}, {"c": "end_turn", "p": 0, "t": 1}])
	result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(result)
	await _shot("07-result")
	_clear()
	var shell := MainScene.instantiate()
	_root.add_child(shell)
	shell._show_settings()
	await _shot("08-settings")
	_clear()
	# 视频风格验收使用已补齐立绘的经典式神，训练角色仍覆盖前面的规则场景。
	var classic := ContentLoader.recommended_lineup()
	form = FormationScreen.new()
	_root.add_child(form)
	form.set_preselect(classic)
	await _shot("09-classic-formation")
	_clear()
	battle = BattleScreen.new()
	battle.setup(classic, ["yingcao", "caitongzi", "xuetongzi", "yatiangou"], 20261006)
	battle._ai_thinking = true
	_root.add_child(battle)
	await _shot("10-classic-battle")
	if args_for_motion(): await _capture_motion(battle)
	_clear()
	await process_frame

	print("CAPTURE_DONE")
	VerifySupport.cleanup_stores(_fixture)
	quit(0)


func args_for_motion() -> bool:
	return OS.get_cmdline_user_args().has("motion")


func _capture_style() -> void:
	_root.add_child(MainMenuScreen.new())
	await _shot("01-menu")
	_clear()
	var form := FormationScreen.new()
	_root.add_child(form)
	form.set_preselect(["ember", "basalt", "lumen", "rime"])
	await _shot("02-formation")
	_clear()
	var classic := ContentLoader.recommended_lineup()
	form = FormationScreen.new()
	_root.add_child(form)
	form.set_preselect(classic)
	await _shot("09-classic-formation")
	_clear()
	var battle := BattleScreen.new()
	battle.setup(classic, ["yingcao", "caitongzi", "xuetongzi", "yatiangou"], 20261006)
	battle._ai_thinking = true
	_root.add_child(battle)
	await _shot("10-classic-battle")
	if args_for_motion(): await _capture_motion(battle)
	_clear()
	await process_frame
	VerifySupport.cleanup_stores(_fixture)
	print("CAPTURE_STYLE_DONE")
	quit(0)


func _viewport_click(face: Control) -> void:
	var point := face.get_global_transform_with_canvas() * (face.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)


func _capture_motion(battle: BattleScreen) -> void:
	var frames := _shot_dir.path_join("motion-frames")
	DirAccess.make_dir_recursive_absolute(frames)
	for player in battle.gs.players:
		player.levelUpUsed = true
		for unit in player.units:
			unit.level = 3
			unit.hp = 20
			unit.maxHp = 20
			unit.shield = 0
	# 无响应牌，使录像能持续展示一次完整出击与回位。
	battle.gs.player(1).hand.clear()
	battle.gs.player(1).units[0].front = 1
	# 测试场景的初始数值不是一次治疗，先建立快照再开始录制实际动作。
	battle._last_view = {}
	battle._refresh()
	await create_timer(battle._presentation_remaining() + 0.1).timeout
	await process_frame
	for face in battle._unit_widgets.values():
		if face.has_meta("flip_from"): face.remove_meta("flip_from")
	root.gui_disable_input = false
	var timings: Array = []
	var began := Time.get_ticks_msec()
	var began_frame := Engine.get_process_frames()
	var fixed_fps := 0.0
	var engine_args := OS.get_cmdline_args()
	var fixed_flag := engine_args.find("--fixed-fps")
	if fixed_flag >= 0 and fixed_flag + 1 < engine_args.size(): fixed_fps = float(engine_args[fixed_flag + 1])
	# Godot 可能不再把已消费的引擎参数交给脚本；显式用户参数与实际 delta 一起校验。
	if OS.get_cmdline_user_args().has("fps=25"):
		fixed_fps = 25.0
		if not is_equal_approx(_root.get_process_delta_time(), 1.0 / fixed_fps):
			push_error("fps=25 motion capture requires engine --fixed-fps 25")
			quit(1)
			return
	_viewport_click(battle._unit_widget(str(battle.gs.player(0).units[0].uid)))
	_viewport_click(battle._unit_widget(str(battle.gs.player(1).units[0].uid)))
	if battle.gs.command_log.is_empty() or battle.gs.command_log[-1].c != "basic_attack":
		push_error("Motion capture failed to attack through viewport input")
		quit(1)
		return
	for i in 64:
		if i == 34: battle._show_turn_banner(true)
		await create_timer(0.04).timeout
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		# 固定帧步进时使用模拟时间；GPU 回读/PNG 写盘不计入游戏演出速度。
		timings.append((Engine.get_process_frames() - began_frame) / fixed_fps if fixed_fps > 0 else (Time.get_ticks_msec() - began) / 1000.0)
		image.save_png(frames.path_join("%03d.png" % i))
		if i in [7, 13, 37, 41]: image.save_png(_shot_dir.path_join("11-motion-%02d.png" % i))
	var timing_file := FileAccess.open(frames.path_join("timings.json"), FileAccess.WRITE)
	timing_file.store_string(JSON.stringify(timings))
	timing_file.close()
	root.gui_disable_input = true
	print("MOTION_CAPTURE_OK frames=64 native_attack=1")
	print("MOTION_TIMING fixed_fps=", fixed_fps, " simulation_seconds=", timings[-1] - timings[0])


func _inject(gs, player_index: int, card_id: String) -> int:
	var p = gs.player(player_index)
	p.hand.append({"instanceId": "%s-shot%d" % [p.id, gs.next_card_id], "definitionId": card_id})
	gs.next_card_id += 1
	return p.hand.size() - 1
