extends Container
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
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_portraits()
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
	# 空前线平时保持池面留白，拖牌时才显示可放置阵台。
	if not _drag_ok: return
	var c := size * 0.5
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)
	draw_circle(c, minf(size.x, size.y) * 0.46, Color(0.61, 0.87, 0.97, 0.07 + (0.1 if _hover_ok else 0)))
	draw_arc(c, minf(size.x, size.y) * 0.46, 0, TAU, 48, Color(0.7, 0.92, 1, 0.35 + pulse * 0.35), 2, true)
	draw_string(_font, Vector2(0, size.y * 0.5 + 5), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("e4f3df"))


func _sort_portraits() -> void:
	var enemy := bool(get_meta("enemy", false))
	for child in get_children():
		if not child is Control: continue
		if not child.has_meta("unit_index"):
			fit_child_in_rect(child, Rect2(Vector2.ZERO, size))
			continue
		var card_size: Vector2 = child.custom_minimum_size
		var index := int(child.get_meta("unit_index", 0))
		var pos := (size - card_size) * 0.5
		if style == "reserve":
			# 按式神原槽位排布，出入前线时其余肖像不会跳位。
			var centers := [0.14, 0.37, 0.63, 0.86]
			pos.x = size.x * centers[index % 4] - card_size.x * 0.5
			var down := index % 2 == (0 if enemy else 1)
			pos.y = 30.0 if down else 0.0
		fit_child_in_rect(child, Rect2(pos, card_size))


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and can_drop.is_valid() and can_drop.call(data)
	if ok != _hover_ok:
		_hover_ok = ok
		queue_redraw()
	return ok


func _drop_data(_pos: Vector2, data: Variant) -> void:
	if on_drop.is_valid(): on_drop.call(data)
