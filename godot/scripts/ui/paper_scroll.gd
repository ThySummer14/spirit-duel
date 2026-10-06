extends PanelContainer
## 编组桌上的八格宣纸卷，随容器宽度折叠；子控件仍使用正常容器布局。

func _ready() -> void:
	var margin := StyleBoxEmpty.new()
	margin.content_margin_left = 26
	margin.content_margin_right = 26
	margin.content_margin_top = 18
	margin.content_margin_bottom = 16
	add_theme_stylebox_override("panel", margin)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0: return
	var x0 := 21.0
	var span := (size.x - 42) / 8.0
	for i in 8:
		var x := x0 + i * span
		var fold := 4.0 if i % 2 == 0 else -3.0
		var paper := PackedVector2Array([Vector2(x, 10 + fold), Vector2(x + span, 10 - fold), Vector2(x + span, size.y - 10 + fold), Vector2(x, size.y - 10 - fold)])
		draw_colored_polygon(paper, Color("e5e1d8") if i % 2 == 0 else Color("f1ede3"))
		draw_line(Vector2(x, 14 + fold), Vector2(x, size.y - 12 - fold), Color(0.49, 0.46, 0.47, 0.24), 1, true)
		var center := Vector2(x + span * 0.5, size.y * 0.5)
		draw_arc(center, minf(span * 0.30, size.y * 0.25), 0, TAU, 32, Color(0.62, 0.39, 0.46, 0.09), 3, true)
	for x in [12.0, size.x - 12]:
		draw_line(Vector2(x, 5), Vector2(x, size.y - 5), Color("bdb4a9"), 13, true)
		draw_line(Vector2(x - 2, 6), Vector2(x - 2, size.y - 6), Color("ece8d9"), 4, true)
