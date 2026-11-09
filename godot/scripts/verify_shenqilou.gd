extends SceneTree
## 主城楼层、手势与入口共用实际的 Viewport 输入路径。

const Main := preload("res://scenes/main_menu.tscn")
const Menu := preload("res://scripts/ui/main_menu.gd")
const Battle := preload("res://scripts/ui/battle_screen.gd")
const Collection := preload("res://scripts/ui/collection_screen.gd")
const Formation := preload("res://scripts/ui/formation_screen.gd")
const Codex := preload("res://scripts/ui/codex_screen.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Support := preload("res://scripts/verify_support.gd")

var checks := 0
var failures := 0
var capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, context: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(context)


func _position_of(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


func _move(point: Vector2, relative := Vector2.ZERO, pressed := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	if pressed: event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _button(point: Vector2, pressed: bool, index := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = index
	event.pressed = pressed
	root.push_input(event, true)


func _click(control: Control) -> void:
	var point := _position_of(control)
	_move(point)
	_button(point, true)
	_button(point, false)
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)


func _settle(menu: Menu, floor_index: int) -> void:
	await create_timer(0.57).timeout
	_check(menu.floor_index == floor_index and is_equal_approx(menu._camera_floor, float(floor_index)), "the camera snaps to deck %d" % floor_index)
	_check(is_equal_approx(menu._world.position.y, -menu.size.y * floor_index), "the artwork and deck share the snapped camera position")
	for i in menu._floor_buttons.size():
		_check(menu._floor_buttons[i].button_pressed == (i == floor_index), "only the current deck is highlighted")
		_check((menu._decks[i].mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED) == (i == floor_index), "only the visible deck accepts pointer input")


func _capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	RenderingServer.force_draw(false)
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "save native %s capture" % name)


func _run() -> void:
	var stores := Support.isolate_stores()
	await process_frame
	if not OS.get_cmdline_user_args().is_empty():
		capture_dir = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 800)
	if not capture_dir.is_empty(): DisplayServer.window_set_size(root.size)
	var main := Main.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var menu: Menu = main._current
	_check(menu.floor_index == Menu.MIDDLE and menu._scenery.texture != null, "a fresh lobby opens on the lit courtyard with the panorama")
	_check(menu._scenery.size.y == menu.size.y * 3.0, "one continuous image covers the three floors")
	await _capture("middle")

	# 滚轮惯性事件只能从中庭跳到相邻一层。
	var center := _position_of(menu)
	for i in 5: _button(center, true, MOUSE_BUTTON_WHEEL_UP)
	await _settle(menu, 0)
	await _capture("upper")
	_button(center, true, MOUSE_BUTTON_WHEEL_UP)
	await _settle(menu, 0)
	await _click(menu._decks[0].get_node("巡游船"))
	_check(is_instance_valid(menu._tour_modal), "the tour boat opens its own inspectable scene")
	_button(center, true, MOUSE_BUTTON_WHEEL_DOWN)
	_check(menu.floor_index == 0, "scrolling over a modal stays on its current deck")
	_key(KEY_ESCAPE)
	await create_timer(0.23).timeout
	_check(not is_instance_valid(menu._tour_modal), "Esc closes the tour boat panel")

	await _click(menu._floor_buttons[1])
	await _settle(menu, 1)
	var duel := menu._decks[1].get_node("对战") as Control
	var start := _position_of(duel)
	var drag := Vector2(0, -150)
	_move(start)
	_button(start, true)
	_move(start + drag, drag, true)
	_check(menu._camera_floor > 1.0 and menu._camera_floor < 2.0, "a vertical drag moves through the same painting before release")
	_button(start + drag, false)
	await _settle(menu, 2)
	_check(main._current == menu, "a swipe starting on the duel marker does not start a match")
	await _capture("lower")
	await _click(menu._decks[2].get_node("百闻馆"))
	_check(main._current is Collection, "the lower deck bookshop opens the existing collection")
	main._current.back_requested.emit()
	await process_frame
	menu = main._current
	_check(menu.floor_index == 2 and is_equal_approx(menu._camera_floor, 2.0), "returning from collection restores the lower deck")
	_key(KEY_PAGEUP)
	await _settle(menu, 1)

	var preset := 1
	menu._preset_picker.select(preset)
	menu._preset_picker.item_selected.emit(preset)
	_check(SaveStore.get_lineup() == menu.lineup and menu.lineup.size() == 4, "selecting a deck preset still saves the lineup")
	await _click(menu._decks[1].get_node("阵容"))
	_check(main._current is Formation, "the middle deck opens the existing formation")
	main._current.back_requested.emit()
	await process_frame
	menu = main._current
	await _click(menu._decks[1].get_node("式神录"))
	_check(main._current is Codex, "the middle deck opens the existing codex")
	main._current.back_requested.emit()
	await process_frame
	menu = main._current

	root.size = Vector2i(1600, 740)
	if not capture_dir.is_empty(): DisplayServer.window_set_size(root.size)
	await process_frame
	await process_frame
	_check(is_equal_approx(menu._world.position.y, -menu.size.y), "resizing keeps the camera aligned to the current deck")
	await _capture("middle-wide")
	await _click(menu._decks[1].get_node("对战"))
	_check(main._current is Battle and main._quick, "duel enters the existing quick battle from the middle deck")
	main.queue_free()
	await process_frame
	Support.cleanup_stores(stores)
	Support.cleanup_audio()
	await process_frame
	print("SHENQILOU checks=%d failures=%d" % [checks, failures])
	if failures == 0: print("SHENQILOU_OK")
	quit(0 if failures == 0 else 1)
