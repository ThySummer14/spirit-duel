extends Container
## 五张秘闻围绕月纹仪式展开，翻开后回正便于阅读。

var burst := 0.0:
	set(value):
		burst = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(1050, 404)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN: return
	var n := get_child_count()
	for i in n:
		var face := get_child(i) as Control
		var centered := i - (n - 1) * 0.5
		var x := size.x * 0.5 + centered * 195 - face.custom_minimum_size.x * 0.5
		var y := 22.0 + absf(centered) * 30
		fit_child_in_rect(face, Rect2(Vector2(x, y), face.custom_minimum_size))
		face.pivot_offset = face.size * 0.5
		face.rotation = deg_to_rad(centered * 9) if face.face_down else 0.0
		face.z_index = 5 - int(absf(centered))


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.66)
	draw_set_transform(center, 0, Vector2(1, 0.25))
	for i in 5:
		draw_arc(Vector2.ZERO, 310 + i * 25, 0, TAU, 96, Color(0.56, 0.65, 1, 0.08 + burst * 0.06), 3, true)
	draw_set_transform(Vector2.ZERO)
	for i in 44:
		var at := Vector2(size.x * (0.06 + fposmod(i * 0.618, 0.88)), size.y * fposmod(i * 0.271, 1))
		draw_circle(at, 1.2 + (i % 3) * 0.5, Color(0.65, 0.74, 1, 0.21))
	if burst > 0:
		for i in 26:
			var direction := Vector2.from_angle(i * TAU / 26)
			draw_line(center + direction * (40 + 70 * (1 - burst)), center + direction * (130 + 160 * (1 - burst)), Color(0.77, 0.84, 1, burst * 0.65), 2, true)
