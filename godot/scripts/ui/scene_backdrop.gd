extends Control
## Original vector scenery, inspired by the recording's port / moonlit card table.

var scene := "port"
## 0..1 压暗程度，让前景控件更易读
var dim := 0.0
## 0..1 四周暗角强度
var vignette := 0.35
var tint := Color.WHITE
## 漂浮光点数量（0 关闭）
var motes := 0
var mote_color := Color(1.0, 0.86, 0.55)
var _background: Texture2D
var _mote_layer: Control

func _ready() -> void:
	var path := "res://assets/scenery/%s.png" % scene
	if scene == "battle": path = "res://assets/scenery/battle-pond-v2.png"
	elif scene == "port": path = "res://assets/scenery/port-town-v2.png"
	if ResourceLoader.exists(path): _background = load(path)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	if motes > 0:
		_mote_layer = Control.new()
		_mote_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mote_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_mote_layer.draw.connect(_draw_motes)
		add_child(_mote_layer)

func _process(_delta: float) -> void:
	if _mote_layer != null and is_visible_in_tree():
		_mote_layer.queue_redraw()

## 缓慢上浮的灯火光点：位置完全由时间推导，无需逐帧状态
func _draw_motes() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in motes:
		var seed_x := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var seed_s := fposmod(sin(i * 78.233) * 12345.678, 1.0)
		var speed := 8.0 + seed_s * 16.0
		var y := size.y + 20.0 - fposmod(t * speed + seed_x * size.y * 1.7, size.y + 40.0)
		var x := seed_x * size.x + sin(t * (0.3 + seed_s * 0.4) + i) * 22.0
		var life := clampf(1.0 - absf(y / size.y - 0.5) * 1.6, 0.0, 1.0)
		var r := 1.2 + seed_s * 2.2
		var a := life * (0.25 + 0.35 * (0.5 + 0.5 * sin(t * 1.7 + i * 2.1)))
		_mote_layer.draw_circle(Vector2(x, y), r * 3.0, Color(mote_color, a * 0.15))
		_mote_layer.draw_circle(Vector2(x, y), r, Color(mote_color, a))

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	if _background != null:
		var source := _background.get_size()
		var scale_factor := maxf(size.x / source.x, size.y / source.y)
		var drawn := source * scale_factor
		var shade := 1.0 - dim
		draw_texture_rect(_background, Rect2((size - drawn) / 2, drawn), false, Color(tint.r * shade, tint.g * shade, tint.b * shade))
		_draw_vignette()
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 800))
	match scene:
		"battle": _battle()
		"table": _table()
		"summon": _summon()
		_: _port()

func _port() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("122d39"))
	draw_circle(Vector2(660, 170), 57, Color("e3dfb2"))
	draw_circle(Vector2(682, 149), 54, Color("122d39"))
	for i in 28:
		var x := float((i * 191 + 17) % 1280)
		var y := float((i * 71 + 30) % 290)
		draw_circle(Vector2(x, y), 1.3, Color("7b9995"))
	for i in 7:
		var y := 245.0 + i * 23
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.3, 0.58, 0.58, 0.12), 12)
	draw_rect(Rect2(0, 345, 1280, 455), Color("172c34"))
	for i in 20:
		var y := 367.0 + i * 19
		draw_line(Vector2(420 - i * 16, y), Vector2(890 + i * 16, y), Color(0.5, 0.7, 0.66, 0.09), 2)
	_building(Vector2(15, 198), Vector2(280, 310), 3)
	_building(Vector2(890, 112), Vector2(325, 380), 4)
	_building(Vector2(125, 355), Vector2(330, 230), 2)
	_building(Vector2(812, 342), Vector2(380, 255), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(370, 780), Vector2(905, 780), Vector2(776, 480), Vector2(532, 480)]), Color("4c4d43"))
	for i in 10:
		var y := 495.0 + i * 30
		var s := (y - 480) / 300
		draw_line(Vector2(532 - 162 * s, y), Vector2(776 + 129 * s, y), Color("74705a"), 2)
	for side in [-1, 1]:
		for i in 6:
			var x: float = 640.0 + side * (170 + i * 40)
			var y := 491.0 + i * 42
			draw_line(Vector2(x, y), Vector2(x, y + 95), Color("39362d"), 5)
			_lantern(Vector2(x, y), 12 + i * 2)
	draw_rect(Rect2(0, 700, 1280, 100), Color(0.04, 0.07, 0.12, 0.74))

func _building(origin: Vector2, span: Vector2, floors: int) -> void:
	draw_rect(Rect2(origin, span), Color("4a3a32"))
	var step := span.y / floors
	for floor_index in floors:
		var y := origin.y + floor_index * step
		draw_rect(Rect2(origin.x + 8, y + 12, span.x - 16, step - 18), Color("745641"))
		for j in 7:
			var x := origin.x + 17 + j * (span.x - 34) / 7
			draw_rect(Rect2(x, y + 22, (span.x - 65) / 7, step - 38), Color("bba273"))
			draw_line(Vector2(x + 8, y + 22), Vector2(x + 8, y + step - 16), Color("65503a"), 3)
		var roof := PackedVector2Array([Vector2(origin.x - 25, y + 17), Vector2(origin.x + 24, y - 7), Vector2(origin.x + span.x - 24, y - 7), Vector2(origin.x + span.x + 25, y + 17)])
		draw_colored_polygon(roof, Color("204a4a"))
		draw_polyline(roof, Color("ab8a56"), 3)
		for j in 3:
			_lantern(Vector2(origin.x + 37 + j * span.x / 3, y + 30), 8)

func _lantern(pos: Vector2, radius: float) -> void:
	draw_circle(pos, radius * 2.3, Color(0.95, 0.69, 0.32, 0.06))
	draw_circle(pos, radius * 1.5, Color(0.98, 0.71, 0.33, 0.12))
	draw_style_box(_box(Color("e2ba7b"), radius * 0.3), Rect2(pos - Vector2(radius, radius * 1.2), Vector2(radius * 2, radius * 2.4)))
	draw_line(pos + Vector2(0, radius * 1.2), pos + Vector2(0, radius * 1.7), Color("b4714f"), 2)

func _battle() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("426e86"))
	for ring in range(15, 0, -1):
		draw_circle(Vector2(660, 340), ring * 33, Color(0.75, 0.88, 0.89, 0.018))
	for i in 14:
		var t := float(i) / 13
		var p := Vector2(150 + t * 980, 405 + sin(t * TAU) * 155)
		draw_circle(p, 28 + sin(t * PI) * 27, Color(0.85, 0.9, 0.88, 0.16))
	for i in 6:
		var p := Vector2(555 + (i % 3) * 70, 280 + (i / 3) * 65)
		draw_circle(p, 70, Color(0.89, 0.88, 0.88, 0.18))
	draw_arc(Vector2(1090, 360), 243, 1.6, 4.5, 64, Color(0.8, 0.91, 0.87, 0.3), 3, true)
	draw_arc(Vector2(220, 440), 200, -1.4, 1.4, 64, Color(0.8, 0.91, 0.87, 0.2), 3, true)
	for i in 16:
		var p := Vector2(float((i * 173 + 30) % 1280), float((i * 97 + 45) % 650))
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(12, -4), p + Vector2(7, 5)]), Color(0.9, 0.64, 0.43, 0.5))
	draw_rect(Rect2(0, 0, 1280, 48), Color(0.04, 0.12, 0.2, 0.58))
	draw_rect(Rect2(0, 650, 1280, 150), Color(0.02, 0.09, 0.16, 0.72))

func _table() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("242637"))
	for i in 9:
		var x := i * 160.0
		draw_rect(Rect2(x, 80, 145, 510), Color("2d2b3b"))
		draw_rect(Rect2(x + 7, 90, 131, 485), Color("343044"), false, 2)
		draw_line(Vector2(x, 330), Vector2(x + 145, 330), Color("565064"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 800), Vector2(1280, 800), Vector2(1090, 585), Vector2(190, 585)]), Color("343547"))
	for i in 8:
		draw_line(Vector2(i * 190, 800), Vector2(280 + i * 105, 585), Color("545161"), 1)
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.035, 0.035, 0.09, 0.22))

func _summon() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("101d32"))
	for i in 30:
		var x := float((i * 137 + 51) % 1280)
		var y := float((i * 83 + 70) % 710)
		_lantern(Vector2(x, y), 3 + i % 4)
	for r in [125, 190, 265]:
		draw_arc(Vector2(640, 350), r, 0, TAU, 96, Color(0.45, 0.73, 0.93, 0.18), 2, true)

func _draw_vignette() -> void:
	if vignette <= 0.0: return
	var edge := Color(0.01, 0.015, 0.035, vignette)
	var clear := Color(0.01, 0.015, 0.035, 0.0)
	var band := minf(size.x, size.y) * 0.32
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - band, band), Vector2(band, band)]), PackedColorArray([edge, edge, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(band, h - band), Vector2(w - band, h - band), Vector2(w, h)]), PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(band, band), Vector2(band, h - band), Vector2(0, h)]), PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - band, h - band), Vector2(w - band, band)]), PackedColorArray([edge, edge, clear, clear]))

func _box(color: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	return box
