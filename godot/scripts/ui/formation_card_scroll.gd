extends ScrollContainer
## 手势使用系统滚动方向和连续位移；按住横拖跟手，纵向拖牌交给 Godot。

const DRAG_THRESHOLD := 10.0
const PRECISE_PAN_SCALE := 1.0 / 0.03
var _pressed := false
var _dragging := false
var _press_at := Vector2.ZERO
var _start_scroll := 0.0
var _position := 0.0
var _web_input: JavaScriptObject
var _web_callback: JavaScriptObject
var _page_tween: Tween
var suppress_click := false


func _ready() -> void:
	get_h_scroll_bar().value_changed.connect(func(value):
		if absf(value - _position) > 1.0: _position = value
	)
	if OS.has_feature("web"):
		_web_input = JavaScriptBridge.get_interface("formationInput")
		if _web_input != null:
			_web_callback = JavaScriptBridge.create_callback(_on_web_wheel)
			_web_input.onWheel = _web_callback


func _exit_tree() -> void:
	if _web_input != null: _web_input.onWheel = null


func _inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * point)


func _on_web_wheel(args: Array) -> void:
	if not is_visible_in_tree() or get_viewport().gui_is_dragging(): return
	if get_tree().get_nodes_in_group("formation_inspector").any(func(node): return node.is_visible_in_tree()): return
	var viewport_size := get_viewport().get_visible_rect().size
	var point := Vector2(float(args[0]), float(args[1])) * viewport_size
	if not _inside(point): return
	var dx := float(args[2]) * viewport_size.x
	var dy := float(args[3]) * viewport_size.x
	var delta := dx if absf(dx) > absf(dy) else dy
	if bool(args[4]) and is_zero_approx(dx): delta = dy
	var local_delta := get_global_transform_with_canvas().basis_xform_inv(Vector2(delta, 0)).x
	_scroll_by(local_delta)
	_web_input.handled = true


func _set_scroll_position(value: float) -> void:
	var bar := get_h_scroll_bar()
	_position = clampf(value, 0.0, maxf(0.0, bar.max_value - bar.page))
	scroll_horizontal = roundi(_position)


func _scroll_by(delta: float) -> void:
	if _page_tween != null: _page_tween.kill()
	if absf(scroll_horizontal - _position) > 1.0: _position = scroll_horizontal
	_set_scroll_position(_position + delta)


func page_by(direction: int) -> void:
	if _page_tween != null: _page_tween.kill()
	var bar := get_h_scroll_bar()
	var target := clampf(scroll_horizontal + direction * size.x * 0.75, 0.0, maxf(0.0, bar.max_value - bar.page))
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_method(_set_scroll_position, float(scroll_horizontal), target, 0.22)


func _input(event: InputEvent) -> void:
	if get_tree().get_nodes_in_group("formation_inspector").any(func(node): return node.is_visible_in_tree()): return
	if not is_visible_in_tree() or is_queued_for_deletion() or get_viewport().gui_is_dragging():
		_pressed = false
		return
	if event is InputEventMouseButton:
		var inside := _inside(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = inside
				_press_at = event.position
				_start_scroll = scroll_horizontal
				if inside and _page_tween != null: _page_tween.kill()
			else:
				_pressed = false
				if _dragging:
					_dragging = false
					get_viewport().set_input_as_handled()
					set_deferred("suppress_click", false)
		elif event.pressed and inside and event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1 if event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_UP] else 1
			_scroll_by(direction * 40.0 * event.factor)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressed:
		var displacement: Vector2 = event.position - _press_at
		if not _dragging and displacement.length() >= DRAG_THRESHOLD:
			if absf(displacement.y) >= absf(displacement.x):
				_pressed = false
				return
			_dragging = true
			suppress_click = true
		if _dragging:
			var local_offset := get_global_transform_with_canvas().basis_xform_inv(displacement)
			_set_scroll_position(_start_scroll - local_offset.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture and _inside(event.position):
		var delta: float = event.delta.x if absf(event.delta.x) > absf(event.delta.y) else event.delta.y
		_scroll_by(delta * PRECISE_PAN_SCALE)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pressed = false
		_dragging = false
		suppress_click = false
