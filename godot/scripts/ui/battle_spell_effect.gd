extends Control
## 局部笔刷、纸纹与粒子。仅活跃时绘制，结束自动释放，不持有 GameState。
const Cues := preload("res://scripts/ui/battle_effect_cues.gd")
const TRAVEL := 0.18
const TAIL := 0.42
var family := "arcane"
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var elapsed := 0.0
var travel := true
var radius := 58.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 效果先于伤害数字加入同一层；负 z_index 会把它排到场景背景后面。
	set_meta("spell_effect", true)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= TRAVEL + TAIL:
		queue_free()
		set_process(false)
	else: queue_redraw()

func _draw() -> void:
	var colors := Cues.palette(family)
	var ink: Color = colors[0]
	var light: Color = colors[1]
	if elapsed < TRAVEL:
		if travel and origin.distance_to(destination) > 8.0: _draw_trail(ink, light)
		return
	var t := clampf((elapsed - TRAVEL) / TAIL, 0.0, 1.0)
	var alpha := sin(PI * pow(t, 0.55))
	var r := radius * (0.5 + t * 0.7)
	draw_set_transform(destination)
	match family:
		"slash": _slash(r, alpha, ink, light, t)
		"fire": _flame(r, alpha, ink, light, t)
		"ice": _ice(r, alpha, ink, light, t)
		"wind": _wind(r, alpha, ink, light, t)
		"thunder": _thunder(r, alpha, ink, light, t)
		"heal", "petal": _petals(r, alpha, ink, light, t)
		"shield": _shield(r, alpha, ink, light, t)
		"awaken", "form", "realm": _mandala(r, alpha, ink, light, t)
		"ink", "seal": _paper_seal(r, alpha, ink, light, t)
		"resource": _sparks(r, alpha, ink, light, t)
		_: _mandala(r, alpha * 0.75, ink, light, t)
	draw_set_transform(Vector2.ZERO)

func _draw_trail(ink: Color, light: Color) -> void:
	var t := clampf(elapsed / TRAVEL, 0.0, 1.0)
	var direction := destination - origin
	var tip := origin.lerp(destination, t * t * (3.0 - 2.0 * t))
	var tail := origin.lerp(tip, 0.55)
	draw_line(tail, tip, Color(ink, 0.25), 13.0, true)
	draw_line(tail, tip, Color(ink, 0.85), 4.0, true)
	draw_line(tail.lerp(tip, 0.5), tip, Color(light, 0.95), 1.7, true)
	for i in 4:
		var at := tip - direction.normalized() * (i * 9.0)
		draw_circle(at, 3.5 - i * 0.6, Color(light, 0.7 - i * 0.13))

func _slash(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 3:
		var off := Vector2((i - 1) * 13.0, (i - 1) * 10.0)
		var pts := PackedVector2Array([off + Vector2(-r, r * 0.7), off + Vector2(r * (0.25 + t), -r * 0.65), off + Vector2(r * 0.45, -r * 0.13)])
		draw_colored_polygon(pts, Color(ink, a * 0.6))
		draw_line(pts[0], pts[1], Color(light, a), 2.0, true)
	_sparks(r, a * 0.65, ink, light, t)

func _flame(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 7:
		var angle := TAU * i / 7.0
		var base := Vector2.from_angle(angle) * r * 0.35
		var rise := r * (0.65 + sin(i * 1.7) * 0.25)
		var pts := PackedVector2Array([base + Vector2(-9, 12), base + Vector2(-13, -rise * 0.4), base + Vector2(5 * sin(i + t * 3), -rise), base + Vector2(12, -rise * 0.25), base + Vector2(9, 12)])
		draw_colored_polygon(pts, Color(ink, a * 0.7))
		draw_line(base, base + Vector2(0, -rise * 0.62), Color(light, a), 3, true)
	_sparks(r, a, ink, light, t)

func _ice(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 6:
		var v := Vector2.from_angle(TAU * i / 6.0 + 0.15)
		var n := v.orthogonal()
		var inner := v * r * 0.2
		var tip := v * r
		var pts := PackedVector2Array([inner, v * r * 0.6 + n * 11, tip, v * r * 0.6 - n * 11])
		draw_colored_polygon(pts, Color(ink, a * 0.55))
		draw_line(inner, tip, Color(light, a), 2.5, true)
		draw_line(v * r * 0.57, v * r * 0.4 + n * 14, Color(light, a * 0.7), 1.4, true)
		draw_line(v * r * 0.57, v * r * 0.4 - n * 14, Color(light, a * 0.7), 1.4, true)
	draw_arc(Vector2.ZERO, r * 0.5, t, TAU + t, 36, Color(ink, a * 0.35), 2, true)

func _wind(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 4:
		var pts := PackedVector2Array()
		for j in 22:
			var angle := TAU * i / 4.0 + j * 0.095 + t * 2.5
			pts.append(Vector2.from_angle(angle) * r * (0.25 + j / 28.0))
		draw_polyline(pts, Color(ink, a * 0.35), 8, true)
		draw_polyline(pts, Color(light, a), 1.7, true)
		var end := pts[-1]
		draw_colored_polygon(PackedVector2Array([end, end + Vector2(-11, -20), end + Vector2(3, -27), end + Vector2(8, -7)]), Color(ink, a))

func _thunder(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 3:
		var x := (i - 1) * 26.0
		var pts := PackedVector2Array([Vector2(x + 12, -r), Vector2(x - 7, -r * 0.3), Vector2(x + 9, -r * 0.18), Vector2(x - 17, r * 0.65)])
		draw_polyline(pts, Color(ink, a * 0.3), 11, true)
		draw_polyline(pts, Color(light, a), 2.4, true)
	_sparks(r, a, ink, light, t)

func _petals(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	var center := Vector2(0, -r * 0.08)
	for i in 5:
		var v := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5 + t * 0.2)
		var n := v.orthogonal()
		var petal := PackedVector2Array([center, center + v * r * 0.28 - n * r * 0.16, center + v * r * 0.59 - n * r * 0.1, center + v * r * 0.7, center + v * r * 0.59 + n * r * 0.1, center + v * r * 0.28 + n * r * 0.16])
		draw_colored_polygon(petal, Color(ink, a * 0.8))
		draw_line(center + v * 7, center + v * r * 0.53, Color(light, a), 1.7, true)
	draw_circle(center, 6, Color(light, a))
	for i in 10:
		var v := Vector2.from_angle(TAU * i / 10.0 + t * 0.7)
		var at := v * r * (0.75 + t * 0.35) + Vector2(0, -t * 23)
		draw_circle(at, 2.5 + sin(i * 2) * 1.2, Color(light if i % 2 else ink, a * 0.8))

func _shield(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	var s := r * 0.72
	var pts := PackedVector2Array([Vector2(-s * 0.7, -s), Vector2(s * 0.7, -s), Vector2(s * 0.85, s * 0.25), Vector2(0, s), Vector2(-s * 0.85, s * 0.25)])
	draw_colored_polygon(pts, Color(ink, a * 0.18))
	pts.append(pts[0])
	draw_polyline(pts, Color(light, a), 2.8, true)
	draw_line(Vector2(0, -s * 0.58), Vector2(0, s * 0.65), Color(ink, a), 2, true)
	draw_arc(Vector2.ZERO, r, -PI * 0.7 + t, PI * 0.7 + t, 36, Color(ink, a * 0.65), 2, true)

func _mandala(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	var sides := 8 if family == "awaken" else 6
	var pts := PackedVector2Array()
	for i in sides: pts.append(Vector2.from_angle(TAU * i / sides + t * 0.22) * r * 0.67)
	pts.append(pts[0])
	draw_polyline(pts, Color(ink, a), 2.4, true)
	draw_arc(Vector2.ZERO, r * 0.84, 0, TAU, 48, Color(light, a * 0.8), 1.5, true)
	for i in sides:
		var v := Vector2.from_angle(TAU * i / sides + t * 0.22)
		draw_line(v * r * 0.36, v * r * 0.98, Color(light, a), 1.5, true)
		var n := v.orthogonal()
		draw_colored_polygon(PackedVector2Array([v * r, v * r * 1.12 + n * 3, v * r * 1.24, v * r * 1.12 - n * 3]), Color(ink, a))

func _paper_seal(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 3:
		var at := Vector2((i - 1) * 26, -t * 17 + abs(i - 1) * 8)
		draw_set_transform(destination + at, (i - 1) * 0.24)
		draw_rect(Rect2(-9, -r * 0.52, 18, r * 0.9), Color(light, a * 0.58))
		for j in 4:
			var y := -r * 0.42 + j * 11
			draw_line(Vector2(-5, y), Vector2(4, y + 3), Color(ink, a), 2, true)
			draw_line(Vector2(1, y), Vector2(-2, y + 8), Color(ink, a), 1.5, true)
	draw_set_transform(destination)

func _sparks(r: float, a: float, ink: Color, light: Color, t: float) -> void:
	for i in 12:
		var angle := TAU * i / 12.0 + 0.1
		var at := Vector2.from_angle(angle) * r * (0.4 + t * 0.7)
		var len := 3.5 + (i % 3) * 2
		draw_line(at - Vector2(len, 0), at + Vector2(len, 0), Color(ink, a * 0.7), 1.6, true)
		draw_line(at - Vector2(0, len), at + Vector2(0, len), Color(light, a), 1.6, true)
