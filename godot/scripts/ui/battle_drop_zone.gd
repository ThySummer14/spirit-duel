extends Container
## 战场行：准备区横带或前线阵台。拖拽进行中若可放置则发光提示。

const RESERVE_STEP := 0.145
const RESERVE_COLUMNS := [-2.0, -1.0, 1.0, 2.0]

var can_drop: Callable
var on_drop: Callable
## "reserve" 横带 / "front" 阵台
var style := "reserve"
var title := ""
var enemy := false
var portrait_size := Vector2.ZERO
var _stagger := 0.0
var _drag_ok := false
var _hover_ok := false
var _font: Font


func _ready() -> void:
	_font = preload("res://scripts/ui/theme_builder.gd").medium_font()
	resized.connect(queue_redraw)


func arrange(area: Rect2, extent: Vector2, stagger := 0.0) -> void:
	position = area.position
	size = area.size
	portrait_size = extent
	_stagger = stagger
	for child in get_children():
		if child.has_meta("unit_index"): child.custom_minimum_size = extent
	queue_sort()
	queue_redraw()


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
	var slot := Rect2((size - portrait_size) * 0.5, portrait_size)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	var gold := Color(1.0, 0.91, 0.70, 0.50 + 0.22 * pulse)
	draw_rect(slot, Color(0.08, 0.06, 0.11, 0.30 if _hover_ok else 0.18))
	draw_rect(slot, Color(gold, 0.30 + 0.22 * pulse), false, 1.0)
	for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner: Vector2 = slot.get_center() + direction * slot.size * 0.5
		draw_polyline(PackedVector2Array([corner - Vector2(direction.x, 0) * 14.0, corner, corner - Vector2(0, direction.y) * 14.0]), gold, 2.0, true)
	draw_string(_font, Vector2(0, size.y * 0.5 + 5), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("f3e6cb"))


func _sort_portraits() -> void:
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
			pos.x += size.x * RESERVE_STEP * RESERVE_COLUMNS[index % RESERVE_COLUMNS.size()]
			var outside := index % 4 in [0, 3]
			pos.y = _stagger if outside == enemy else 0.0
		fit_child_in_rect(child, Rect2(pos, card_size))


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and can_drop.is_valid() and can_drop.call(data)
	if ok != _hover_ok:
		_hover_ok = ok
		queue_redraw()
	return ok


func _drop_data(_pos: Vector2, data: Variant) -> void:
	if on_drop.is_valid(): on_drop.call(data)
