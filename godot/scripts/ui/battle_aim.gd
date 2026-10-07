extends Control
## 目标指引只绘制连线；合法性与目标命中仍由战场和规则层决定。
var origin := Vector2.ZERO
var endpoint := Vector2.ZERO
var valid := false
var over_target := false
var hint := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var color := Color("a4edcf") if valid else (Color("ee998e") if over_target else Color("eddba5"))
	var delta := endpoint - origin
	if delta.length() < 12.0: return
	var bend := minf(90.0, delta.length() * 0.18)
	var mid := (origin + endpoint) * 0.5 + Vector2(0, -bend)
	var points := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		points.append(origin * (1.0 - t) * (1.0 - t) + mid * 2.0 * t * (1.0 - t) + endpoint * t * t)
	draw_polyline(points, Color(0.03, 0.07, 0.12, 0.65), 8.0, true)
	draw_polyline(points, Color(color, 0.85), 2.5, true)
	var direction := (endpoint - points[30]).normalized()
	var perpendicular := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([endpoint, endpoint - direction * 16.0 + perpendicular * 7.0, endpoint - direction * 16.0 - perpendicular * 7.0]), color)
	draw_circle(origin, 4.0, color)
	if over_target:
		draw_arc(endpoint, 22.0, 0, TAU, 40, Color(color, 0.75), 2.0, true)
	if valid and not hint.is_empty():
		var font := ThemeBuilder.sys_font()
		var extent := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var at := endpoint + Vector2(-extent.x * 0.5, -48)
		at.x = clampf(at.x, 12, maxf(12, size.x - extent.x - 12))
		draw_style_box(ThemeBuilder.glass(0.94, color, 6), Rect2(at + Vector2(-8, -22), extent + Vector2(16, 10)))
		draw_string(font, at, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e9f7eb"))
