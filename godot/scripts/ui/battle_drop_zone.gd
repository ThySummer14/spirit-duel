extends HBoxContainer
## 战场行：准备区横带或前线阵台。拖拽进行中若可放置则发光提示。

var can_drop: Callable
var on_drop: Callable
## "reserve" 横带 / "front" 阵台
var style := "reserve"
var title := ""
var accent := Color(0.85, 0.7, 0.4)
var _drag_ok := false
var _hover_ok := false
var _font: Font


func _ready() -> void:
	_font = preload("res://scripts/ui/theme_builder.gd").medium_font()
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var payload = get_viewport().gui_get_drag_data()
		_drag_ok = payload is Dictionary and can_drop.is_valid() and can_drop.call(payload)
		set_process(_drag_ok)
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_drag_ok = false
		_hover_ok = false
		set_process(false)
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT and _hover_ok:
		_hover_ok = false
		queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if style == "front":
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.07)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.28)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(18)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var c := size * 0.5
		draw_arc(c, minf(size.x, size.y) * 0.42, 0, TAU, 64, Color(accent, 0.16), 1.0, true)
		if get_child_count() == 0 or (get_child_count() == 1 and get_child(0) is Label):
			draw_string(_font, Vector2(0, size.y - 12), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(accent, 0.55))
	else:
		var mid := size.y * 0.5
		var col := Color(accent.r, accent.g, accent.b, 0.09)
		draw_polygon(PackedVector2Array([Vector2(size.x * 0.04, mid - size.y * 0.42), Vector2(size.x * 0.96, mid - size.y * 0.42), Vector2(size.x, mid), Vector2(size.x * 0.96, mid + size.y * 0.42), Vector2(size.x * 0.04, mid + size.y * 0.42), Vector2(0, mid)]),
			PackedColorArray([col, col, Color(col, 0.0), col, col, Color(col, 0.0)]))
		draw_line(Vector2(size.x * 0.1, mid + size.y * 0.47), Vector2(size.x * 0.9, mid + size.y * 0.47), Color(accent, 0.18), 1.0, true)
	if _drag_ok:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)
		var glow := StyleBoxFlat.new()
		glow.draw_center = true
		glow.bg_color = Color(0.5, 0.95, 0.75, 0.08 + (0.1 if _hover_ok else 0.0))
		glow.border_color = Color(0.55, 1.0, 0.8, 0.45 + 0.4 * pulse)
		glow.set_border_width_all(2)
		glow.set_corner_radius_all(18)
		glow.anti_aliasing = true
		draw_style_box(glow, r.grow(2))


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and can_drop.is_valid() and can_drop.call(data)
	if ok != _hover_ok:
		_hover_ok = ok
		queue_redraw()
	return ok


func _drop_data(_pos: Vector2, data: Variant) -> void:
	if on_drop.is_valid(): on_drop.call(data)
