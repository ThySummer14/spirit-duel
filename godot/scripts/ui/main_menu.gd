class_name MainMenuScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const UIWidgets := preload("res://scripts/ui/ui_widgets.gd")

const MIDDLE := 1
const FLOOR_LABELS := ["上层", "中层", "下层"]
const DECK_NAMES := ["鲤鱼巡游船", "中庭广场", "温泉庭院"]
const ART_PATH := "res://assets/scenery/shenqilou-panorama.png"
const DRAG_START := 16.0
const WHEEL_GAP_MS := 240

signal start_quick_match
signal lineup_selected(unit_ids: Array)
signal open_formation
signal open_codex
signal open_collection
signal open_settings
signal quit_requested
signal floor_changed(floor_index: int)

var lineup: Array = []
var floor_index := MIDDLE
var _camera_floor := float(MIDDLE):
	set(value):
		_camera_floor = value
		_position_camera()
var _world: Control
var _scenery: TextureRect
var _atmosphere: Control
var _edge_shade: TextureRect
var _decks: Array[Control] = []
var _floor_buttons: Array[Button] = []
var _floor_title: Label
var _lineup_names: Label
var _lineup_faces: HBoxContainer
var _preset_picker: OptionButton
var _tour_modal: Control
var _slide: Tween
var _pointer_down := false
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_floor := 0.0
var _last_wheel := -WHEEL_GAP_MS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build_world()
	_build_header()
	_build_floor_navigation()
	_layout_world()
	resized.connect(_layout_world)
	_show_floor(floor_index, false)
	Sfx.music("bgm_menu")


func _build_world() -> void:
	_world = Control.new()
	_world.name = "Shenqilou"
	_world.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_world)

	_scenery = TextureRect.new()
	_scenery.mouse_filter = MOUSE_FILTER_IGNORE
	_scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(ART_PATH): _scenery.texture = load(ART_PATH)
	_world.add_child(_scenery)
	_atmosphere = Control.new()
	_atmosphere.mouse_filter = MOUSE_FILTER_IGNORE
	_atmosphere.draw.connect(_draw_atmosphere)
	_world.add_child(_atmosphere)
	_build_edge_shade()

	for i in DECK_NAMES.size():
		var deck := Control.new()
		deck.mouse_filter = MOUSE_FILTER_IGNORE
		_world.add_child(deck)
		_decks.append(deck)
	_waypoint(_decks[0], "舟", "巡游船", "楼船夜景", Vector2(0.66, 0.54), _inspect_tour_ship)
	_waypoint(_decks[MIDDLE], "阵", "阵容", "编排出战式神与卡组", Vector2(0.255, 0.49), func(): open_formation.emit())
	_waypoint(_decks[MIDDLE], "录", "式神录", "查阅式神与卡牌", Vector2(0.23, 0.72), func(): open_codex.emit())
	var match_button := _waypoint(_decks[MIDDLE], "弈", "对战", "开始一场人机对弈", Vector2(0.72, 0.71), func(): start_quick_match.emit(), true)
	match_button.set_meta("action", "start_quick_match")
	_build_lineup_panel(_decks[MIDDLE])
	_waypoint(_decks[2], "卷", "百闻馆", "购买和开启秘闻卷", Vector2(0.77, 0.50), func(): open_collection.emit(), true)


func _layout_world() -> void:
	_world.size = Vector2(size.x, size.y * DECK_NAMES.size())
	# Keep each camera stop on an exact third of the painting, cropping only the sides.
	var art_width := maxf(size.x, size.y * 1.82)
	_scenery.position.x = (size.x - art_width) * 0.5
	_scenery.size = Vector2(art_width, _world.size.y)
	_atmosphere.size = _world.size
	_edge_shade.size = size
	for i in _decks.size():
		_decks[i].position.y = size.y * i
		_decks[i].size = size
	_position_camera()
	_atmosphere.queue_redraw()


func _position_camera() -> void:
	if _edge_shade == null: return
	_world.position.y = -_camera_floor * size.y
	_edge_shade.position.y = -_world.position.y


func _build_edge_shade() -> void:
	# Screen-fixed shading keeps deck names and utility controls readable while scrolling.
	_edge_shade = TextureRect.new()
	_edge_shade.mouse_filter = MOUSE_FILTER_IGNORE
	_edge_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.17, 0.82, 1.0])
	colors.colors = PackedColorArray([Color(0.02, 0.04, 0.06, 0.64), Color(0.02, 0.04, 0.06, 0), Color(0.02, 0.04, 0.06, 0), Color(0.02, 0.04, 0.06, 0.76)])
	var texture := GradientTexture2D.new()
	texture.gradient = colors
	texture.fill_to = Vector2.DOWN
	_edge_shade.texture = texture
	_world.add_child(_edge_shade)


func _process(_delta: float) -> void:
	_atmosphere.queue_redraw()


func _draw_atmosphere() -> void:
	var time := Time.get_ticks_msec() * 0.001
	for floor in DECK_NAMES.size():
		# Only draw the ambient lights in the camera's visible part of the ship.
		if absf(float(floor) - _camera_floor) >= 1.0: continue
		var origin_y := floor * size.y
		if _scenery.texture == null:
			_atmosphere.draw_rect(Rect2(0, origin_y, size.x, size.y), [Color("122a3c"), Color("284143"), Color("245052")][floor])
		for i in 18:
			var phase := float(i) * 7.15 + floor * 11.0
			var x := fposmod(i * 0.618, 1.0) * size.x + sin(time * 0.65 + phase) * 16.0
			var y := fposmod(i * 0.427 - time * (0.008 + 0.002 * (i % 4)), 1.0) * size.y
			var light := 0.3 + 0.18 * sin(time * 1.25 + phase)
			var color := Color("f9d998") if floor == MIDDLE else Color("c8e8dc")
			var point := Vector2(x, origin_y + y)
			_atmosphere.draw_circle(point, 4.0 + i % 3, Color(color, light * 0.13))
			_atmosphere.draw_circle(point, 1.0 + 0.3 * (i % 3), Color(color, light))


func _build_header() -> void:
	var top := HBoxContainer.new()
	top.mouse_filter = MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 29
	top.offset_right = -28
	top.offset_top = 18
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	var brand := VBoxContainer.new()
	brand.mouse_filter = MOUSE_FILTER_IGNORE
	brand.add_theme_constant_override("separation", 0)
	top.add_child(brand)
	brand.add_child(ThemeBuilder.outline(ThemeBuilder.title_label("蜃气楼", 36), 5, Color("172128")))
	brand.add_child(ThemeBuilder.outline(ThemeBuilder.label("灵枢战线", 12, Color("e2caa5")), 3, Color("172128")))
	var space := Control.new()
	space.mouse_filter = MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(space)
	var balance := ThemeBuilder.outline(ThemeBuilder.label("御札  %d" % int(CollectionStore.load_collection().balance), 15, Color("f5deb0")), 4)
	top.add_child(balance)
	for entry in [["设置", open_settings], ["返回旧版" if OS.has_feature("web") else "退出", quit_requested]]:
		var button := _small_button(entry[0], Vector2(78, 34))
		button.size_flags_vertical = SIZE_SHRINK_CENTER
		var action: Signal = entry[1]
		button.pressed.connect(func(): action.emit())
		top.add_child(button)


func _build_floor_navigation() -> void:
	var rail := VBoxContainer.new()
	rail.name = "FloorNavigation"
	rail.mouse_filter = MOUSE_FILTER_IGNORE
	rail.add_theme_constant_override("separation", 6)
	rail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	rail.offset_left = -92
	rail.offset_right = -26
	rail.offset_top = -66
	add_child(rail)
	for i in DECK_NAMES.size():
		var button := _small_button(FLOOR_LABELS[i], Vector2(66, 36))
		button.tooltip_text = DECK_NAMES[i]
		button.toggle_mode = true
		button.pressed.connect(_choose_floor.bind(i))
		rail.add_child(button)
		_floor_buttons.append(button)
	var footer := VBoxContainer.new()
	footer.mouse_filter = MOUSE_FILTER_IGNORE
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left = -175
	footer.offset_right = 175
	footer.offset_top = -78
	add_child(footer)
	_floor_title = ThemeBuilder.outline(ThemeBuilder.title_label("", 24), 5, Color("1b262b"))
	footer.add_child(_floor_title)
	var hint := ThemeBuilder.outline(ThemeBuilder.label("上下滑动 · 滚轮换层", 13, Color("efddbd")), 4, Color("1b262b"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(hint)


func _small_button(label: String, extent: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = extent
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", ThemeBuilder.panel(Color(0.045, 0.09, 0.12, 0.86), Color("796b58"), 5, 1))
	button.add_theme_stylebox_override("hover", ThemeBuilder.panel(Color("364448"), Color("dcbd86"), 5, 1))
	button.add_theme_stylebox_override("pressed", ThemeBuilder.panel(Color("604237"), Color("eed4a1"), 5, 1))
	return button


func _waypoint(deck: Control, glyph: String, title: String, hint: String, at: Vector2, action: Callable, highlighted := false) -> Button:
	var button := Button.new()
	button.name = title
	button.tooltip_text = hint
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	deck.add_child(button)
	button.anchor_left = at.x
	button.anchor_right = at.x
	button.anchor_top = at.y
	button.anchor_bottom = at.y
	button.offset_left = -60
	button.offset_right = 60
	button.offset_top = -34
	button.offset_bottom = 40
	var icon := Control.new()
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.position = Vector2(60, 24)
	button.add_child(icon)
	icon.draw.connect(func():
		var radius := 23.0 if highlighted else 20.0
		var rim := Color("ffe6ae") if button.is_hovered() or button.has_focus() else Color("c5b18b")
		var diamond := PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
		icon.draw_colored_polygon(diamond, Color("773d34") if highlighted else Color("24363a"))
		diamond.append(diamond[0])
		icon.draw_polyline(diamond, rim, 2.0, true)
	)
	button.mouse_entered.connect(func():
		Sfx.play("ui_hover", 0.35)
		icon.queue_redraw()
	)
	button.mouse_exited.connect(icon.queue_redraw)
	button.focus_entered.connect(icon.queue_redraw)
	button.focus_exited.connect(icon.queue_redraw)
	var symbol := ThemeBuilder.title_label(glyph, 19)
	symbol.mouse_filter = MOUSE_FILTER_IGNORE
	symbol.position = Vector2(36, 8)
	symbol.size = Vector2(48, 32)
	button.add_child(symbol)
	var caption := ThemeBuilder.outline(ThemeBuilder.title_label(title, 21), 5, Color("211e20"))
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.position = Vector2(0, 47)
	caption.size = Vector2(120, 28)
	button.add_child(caption)
	button.pressed.connect(func():
		if _dragging or _slide != null or deck != _decks[floor_index]: return
		Sfx.play("ui_click", 0.7)
		action.call()
	)
	return button


func _inspect_tour_ship() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 370
	var style := ThemeBuilder.panel(Color("172c36"), Color("b29872"), 8, 1)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	content.add_child(ThemeBuilder.title_label("鲤鱼巡游船", 27))
	var description := ThemeBuilder.label("鲤鱼船从上级客房旁出发，\n迎着月色巡过蜃气楼。", 17, Color("e8ddc7"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)
	var close := _small_button("继续游览", Vector2(96, 36))
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	content.add_child(close)
	_tour_modal = UIWidgets.show_modal(self, panel)
	close.pressed.connect(_tour_modal.get_meta("close"))


func _choose_floor(index: int) -> void:
	_show_floor(index)
	_floor_buttons[floor_index].set_pressed_no_signal(true)


func _show_floor(index: int, animate := true) -> void:
	var next_floor := clampi(index, 0, _decks.size() - 1)
	var changed := next_floor != floor_index
	floor_index = next_floor
	for i in _floor_buttons.size():
		_floor_buttons[i].set_pressed_no_signal(i == floor_index)
	_floor_title.text = "%s · %s" % [FLOOR_LABELS[floor_index], DECK_NAMES[floor_index]]
	if changed:
		Sfx.play("ui_click", 0.45)
		floor_changed.emit(floor_index)
	if _slide != null: _slide.kill()
	_slide = null
	if not animate or is_equal_approx(_camera_floor, float(floor_index)):
		_camera_floor = float(floor_index)
		_sync_deck_input()
		return
	_slide = create_tween()
	_slide.tween_property(self, "_camera_floor", float(floor_index), 0.53 if absf(_camera_floor - floor_index) > 1.15 else 0.39).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.finished.connect(func():
		_slide = null
		_sync_deck_input()
	)
	_sync_deck_input()


func _sync_deck_input() -> void:
	for i in _decks.size():
		var active := i == floor_index and not _dragging and _slide == null
		_decks[i].mouse_behavior_recursive = MOUSE_BEHAVIOR_INHERITED if active else MOUSE_BEHAVIOR_DISABLED
		_decks[i].focus_behavior_recursive = FOCUS_BEHAVIOR_INHERITED if active else FOCUS_BEHAVIOR_DISABLED


func _scroll_floor(step: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_wheel >= WHEEL_GAP_MS and not _dragging: _show_floor(floor_index + step)
	_last_wheel = now


func _input(event: InputEvent) -> void:
	if _world == null or is_queued_for_deletion() or is_instance_valid(_tour_modal) or _preset_picker.get_popup().visible: return
	# Touch uses Godot's mouse emulation, so a swipe and a desktop drag share one camera.
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll_floor(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_pointer_down = event.pressed
			if event.pressed:
				_press_position = event.position
			elif _dragging:
				var distance: float = event.position.y - _press_position.y
				var threshold := clampf(size.y * 0.10, 52.0, 88.0)
				_dragging = false
				_show_floor(floor_index - int(signf(distance)) if absf(distance) >= threshold else floor_index)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_down:
		var distance: Vector2 = event.position - _press_position
		if not _dragging and absf(distance.y) >= DRAG_START and absf(distance.y) > absf(distance.x):
			_dragging = true
			if _slide != null: _slide.kill()
			_slide = null
			_drag_start_floor = _camera_floor
			_sync_deck_input()
		if _dragging:
			var raw := _drag_start_floor - distance.y / maxf(1.0, size.y)
			var edge := clampf(raw, 0.0, DECK_NAMES.size() - 1)
			_camera_floor = edge + clampf((raw - edge) * 0.18, -0.03, 0.03)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture and absf(event.delta.y) > absf(event.delta.x):
		_scroll_floor(int(signf(event.delta.y)))
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_queued_for_deletion() or is_instance_valid(_tour_modal) or _preset_picker.get_popup().visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_show_floor(floor_index + (-1 if event.keycode == KEY_PAGEUP else 1))
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _pointer_down:
		_pointer_down = false
		if _dragging:
			_dragging = false
			_show_floor(floor_index)

func _build_lineup_panel(deck: Control) -> void:
	if not ContentLoader.valid_lineup(lineup): lineup = ContentLoader.recommended_lineup()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 26
	panel.offset_right = 394
	panel.offset_top = -124
	panel.offset_bottom = -20
	var sb := ThemeBuilder.panel(Color(0.035, 0.075, 0.09, 0.85), Color("98866c"), 5, 1)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	deck.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_lineup_faces = HBoxContainer.new()
	_lineup_faces.add_theme_constant_override("separation", 8)
	row.add_child(_lineup_faces)
	var presets := VBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(presets)
	presets.add_child(ThemeBuilder.label("出战阵容", 12, ThemeBuilder.PAPER))
	_preset_picker = OptionButton.new()
	_preset_picker.fit_to_longest_item = false
	_preset_picker.add_theme_font_size_override("font_size", 12)
	_preset_picker.add_item("当前阵容")
	_preset_picker.set_item_metadata(0, "")
	for pack in ContentLoader.pack_ids():
		if pack == "all": continue
		_preset_picker.add_item("%s · %d 位" % [ContentLoader.pack_label(pack), ContentLoader.units_in_pack(pack).size()])
		_preset_picker.set_item_metadata(_preset_picker.item_count - 1, pack)
	_preset_picker.item_selected.connect(_select_preset)
	presets.add_child(_preset_picker)
	_lineup_names = ThemeBuilder.label("", 12, ThemeBuilder.PAPER)
	_lineup_names.clip_text = true
	v.add_child(_lineup_names)
	_refresh_lineup()


func _select_preset(index: int) -> void:
	var pack := str(_preset_picker.get_item_metadata(index))
	if pack.is_empty(): return
	lineup = ContentLoader.recommended_lineup(pack)
	_refresh_lineup()
	lineup_selected.emit(lineup.duplicate())
	Sfx.play("ui_click", 0.7)


func _refresh_lineup() -> void:
	var names := PackedStringArray()
	for child in _lineup_faces.get_children():
		_lineup_faces.remove_child(child)
		child.queue_free()
	for uid in lineup:
		var unit := ContentLoader.unit_def(str(uid))
		names.append(str(unit.name))
		var face := UIWidgets.unit_token(unit, func(): open_formation.emit(), Vector2(42, 42), "diamond")
		face.custom_minimum_size = Vector2(42, 42)
		face.tooltip_text = str(unit.name) + " · 点击自选阵容"
		_lineup_faces.add_child(face)
	_lineup_names.text = " / ".join(names)
