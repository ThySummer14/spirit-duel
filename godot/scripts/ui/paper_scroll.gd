extends PanelContainer
## 八格牌卷，浅纸承托卡面，细折线区分槽位。

func _ready() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("dce0d4")
	paper.border_color = Color("9bada2")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(4)
	paper.shadow_color = Color(0.02, 0.06, 0.07, 0.25)
	paper.shadow_size = 8
	paper.shadow_offset = Vector2(0, 4)
	paper.content_margin_left = 18
	paper.content_margin_right = 18
	paper.content_margin_top = 14
	paper.content_margin_bottom = 14
	add_theme_stylebox_override("panel", paper)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0: return
	var span := (size.x - 36) / 8.0
	for i in range(1, 8):
		var x := 18 + i * span
		draw_line(Vector2(x, 18), Vector2(x, size.y - 18), Color(0.28, 0.36, 0.33, 0.13), 1, true)
	for x in [5.0, size.x - 5]:
		draw_line(Vector2(x, 9), Vector2(x, size.y - 9), Color("97a69a"), 3, true)
		draw_line(Vector2(x + 1, 9), Vector2(x + 1, size.y - 9), Color("edf0e5"), 1, true)
