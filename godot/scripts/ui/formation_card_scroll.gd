extends ScrollContainer
## 横向卡池。拖动以牌面跟手为准，纵向拖牌仍交给 Godot 的拖放。

const DRAG_THRESHOLD := 14.0
var _pressed := false
var _dragging := false
var _press_at := Vector2.ZERO
var _start_scroll := 0
var suppress_click := false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion() or get_viewport().gui_is_dragging():
		_pressed = false
		return
	if event is InputEventMouseButton:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO, size).has_point(point)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = inside
				_press_at = event.position
				_start_scroll = scroll_horizontal
			else:
				_pressed = false
				if _dragging:
					_dragging = false
					set_deferred("suppress_click", false)
		elif event.pressed and inside and event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_LEFT else -1
			scroll_horizontal += direction * roundi(72.0 * clampf(event.factor, 1.0, 4.0))
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
			scroll_horizontal = _start_scroll - roundi(local_offset.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture and absf(event.delta.x) > absf(event.delta.y):
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, size).has_point(point):
			scroll_horizontal -= roundi(event.delta.x * 36.0)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pressed = false
		_dragging = false
		suppress_click = false
