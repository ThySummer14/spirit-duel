extends Control
## 卡面绘制：行动牌（含正文）、式神肖像（攻/命/勾玉/状态）与卡背。
## 只负责外观与悬停/受击等表现；规则与点击逻辑由所属界面处理。

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const PortraitLibrary := preload("res://scripts/ui/portrait_library.gd")
const BattleStatus := preload("res://scripts/ui/battle_status.gd")
const KeywordGlossary := preload("res://scripts/ui/keyword_glossary.gd")
static var _textures: Dictionary = {}

signal hover_changed(hovering: bool)

var data: Dictionary = {}
var current_turn := -1
var unit_mode := false
## 小头像用于场景入口与阵容菱形位，不携带战斗数值。
var portrait_only := false
var portrait_shape := "square"
var face_down := false
var selected := false
var enabled := true
## 可打出/可操作；光效同时读取实时支付与能力状态。
var playable := false
var note := ""
## -1 图鉴，0 己方，1 敌方
var side := -1
## 悬停时上浮缩放（手牌、名录）
var hover_lift := 0.0
var drag_payload: Dictionary = {}
var drop_check: Callable
var drop_action: Callable

# 表现层状态，供 Tween 驱动
var visual_offset := Vector2.ZERO:
	set(v):
		visual_offset = v
		queue_redraw()
var visual_scale := 1.0:
	set(v):
		visual_scale = v
		queue_redraw()
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
var hovered := false

var _texture: Texture2D
var _original_card: Texture2D
var _texture_path := ""
var _art_focus := Vector2(-1, -1)
var _font: Font
var _bold: Font
var _display: Font
var _hover_t := 0.0
var _hover_tween: Tween
var _para_cache_key := ""
var _para_lines: Array = []
var _para_size := 11


func _ready() -> void:
	_font = ThemeBuilder.sys_font()
	_bold = ThemeBuilder.bold_font()
	_display = ThemeBuilder.display_font()
	refresh_art()
	resized.connect(queue_redraw)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	set_process(playable or selected)


func refresh_art() -> void:
	_original_card = null
	if not unit_mode:
		var original := "res://assets/official/cards/%s.png" % str(data.get("id", ""))
		if ResourceLoader.exists(original):
			if not _textures.has(original): _textures[original] = load(original)
			_original_card = _textures[original]
	var unit := data if unit_mode else ContentLoader.unit_def(str(data.get("unitId", "")))
	if unit_mode and not unit.has("art"):
		unit = ContentLoader.unit_def(str(data.get("id", "")))
	var awakened: bool = data.get("awakened", false) or data.get("awakening", false) or data.get("type", "") == "awakening"
	var artwork := PortraitLibrary.artwork(unit, awakened)
	var path: String = artwork.path
	_art_focus = artwork.focus
	_texture_path = path
	if not _textures.has(path) and ResourceLoader.exists(path):
		_textures[path] = load(path)
	_texture = _textures.get(path)
	queue_redraw()


func _process(_delta: float) -> void:
	if playable or selected:
		queue_redraw()


func set_playable(value: bool) -> void:
	playable = value
	set_process(value or selected)
	queue_redraw()


## 由覆盖在卡面上的透明按钮转发悬停
func bind_button(button: BaseButton) -> void:
	button.mouse_entered.connect(_set_hover.bind(true))
	button.mouse_exited.connect(_set_hover.bind(false))


func _set_hover(value: bool) -> void:
	if hovered == value: return
	hovered = value
	hover_changed.emit(value)
	if _hover_tween != null: _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(func(t): _hover_t = t; queue_redraw(), _hover_t, 1.0 if value else 0.0, 0.12)


# ——————————————————————————— 绘制 ———————————————————————————

func _draw() -> void:
	if _font == null or size.x < 5:
		return
	var lift := hover_lift * _hover_t
	var s := visual_scale * (1.0 + 0.04 * _hover_t * signf(hover_lift))
	draw_set_transform(visual_offset + Vector2(0, -lift) + size * (1.0 - s) * 0.5, 0.0, Vector2(s, s))
	if face_down:
		_draw_back()
	elif unit_mode:
		if portrait_only: _draw_portrait()
		else: _draw_unit()
	else:
		_draw_card()
	if flash > 0.01:
		draw_style_box(_box(Color(1, 0.96, 0.9, flash * 0.65), Color.TRANSPARENT, _radius(), 0), Rect2(Vector2.ZERO, size))
	draw_set_transform(Vector2.ZERO)


func hit_test(point: Vector2) -> bool:
	var lift := hover_lift * _hover_t
	var factor := visual_scale * (1.0 + 0.04 * _hover_t * signf(hover_lift))
	var offset := visual_offset + Vector2(0, -lift) + size * (1.0 - factor) * 0.5
	# 原位置保留在范围中，让指针停在下缘时不会因牌面抬起而反复退出。
	return Rect2(Vector2.ZERO, size).has_point(point) or Rect2(offset, size * factor).has_point(point)


func _has_point(point: Vector2) -> bool:
	return hit_test(point)


func _radius() -> int:
	return int(clampf(size.x * 0.07, 4, 12))


func _box(bg: Color, border: Color, radius: int, bw: int, shadow: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow > 0.0:
		sb.shadow_color = Color(0, 0, 0, shadow)
		sb.shadow_size = int(clampf(size.x * 0.06, 3, 10))
		sb.shadow_offset = Vector2(0, 3)
	return sb


func _glow(color: Color, strength: float, spread: float) -> void:
	var r := _radius()
	for i in 4:
		var grow := spread * (1.0 - i / 4.0)
		var sb := _box(Color.TRANSPARENT, Color(color.r, color.g, color.b, strength * (0.12 + i * 0.12)), r + int(grow), 2)
		sb.draw_center = false
		draw_style_box(sb, Rect2(-Vector2.ONE * grow, size + Vector2.ONE * grow * 2))


func _pulse() -> float:
	return 0.65 + 0.35 * sin(Time.get_ticks_msec() / 260.0)


func play_aura_kind() -> String:
	if face_down or not enabled or not playable: return ""
	if unit_mode:
		return "inspired" if not portrait_only and BattleStatus.Combat.has(data, "inspired") else ""
	if data.get("payment", {}).get("usesInstant", false) or data.get("payment", {}).get("coinFirstFree", false): return "instant"
	return "inspired" if data.get("inspiredSupport", false) else ""


func _draw_play_aura(kind: String, rectangular: bool = false) -> void:
	if kind.is_empty(): return
	var color := Color("43b8ff") if kind == "instant" else Color("ffcd42")
	var spread := clampf(size.x * 0.07, 5.0, 13.0)
	for i in range(4, 0, -1):
		var grow := spread * i / 4.0
		var tint := Color(color, (0.045 + 0.018 * _pulse()) * (5 - i))
		if _original_card != null and not unit_mode:
			_original_rim(tint, grow * 0.45)
		elif rectangular:
			var box := _box(Color.TRANSPARENT, tint, _radius() + int(grow), 2)
			box.draw_center = false
			draw_style_box(box, Rect2(-Vector2.ONE * grow, size + Vector2.ONE * grow * 2))
		else: _arch_rim(tint, 2.0 + grow * 0.6, -grow * 0.45)
	# 错开寿命的细焰沿卡边上升；无随机数、节点或纹理分配。
	var seconds := Time.get_ticks_msec() * 0.001
	for i in 26:
		var seed_value := i * 0.618034
		var age := fposmod(seconds * (0.55 + fposmod(seed_value, 0.37)) + seed_value, 1.0)
		var edge := i % 4
		var along := fposmod(i * 0.381966, 1.0)
		var base := Vector2(0 if edge == 0 else size.x, size.y * along)
		if edge >= 2:
			base = Vector2(size.x * along, (0.035 * size.y if edge == 2 else size.y))
		var outward := -1.0 if base.x < size.x * 0.5 else 1.0
		var rise := size.y * (0.13 + fposmod(seed_value, 0.10))
		var pos := base + Vector2(outward * (2 + age * spread * 0.65), -age * rise)
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for j in 7:
			var t := j / 6.0
			points.append(pos + Vector2(outward * sin(t * PI + seconds * 2.0 + i) * spread * 0.28, -t * rise * 0.40))
			colors.append(Color(color, sin(age * PI) * sin(t * PI) * 0.48))
		draw_polyline_colors(points, colors, maxf(1.0, spread * 0.55), true)
		for j in colors.size(): colors[j] = Color(color.lightened(0.6), colors[j].a * 0.8)
		draw_polyline_colors(points, colors, maxf(0.65, spread * 0.13), true)


func _draw_art(rect: Rect2, tint: Color = Color.WHITE) -> void:
	if _texture == null:
		draw_rect(rect, Color("1d2333"))
		return
	draw_texture_rect_region(_texture, rect, art_source_rect(rect.size), tint)


## 顶部异形轮廓使用纹理 UV 裁切；不让矩形插画伸出拱顶。
func _art_polygon(points: PackedVector2Array, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if _texture == null:
		draw_colored_polygon(points, Color("455364"))
		return
	var source := art_source_rect(rect.size)
	var uv := PackedVector2Array()
	for point in points:
		uv.append((source.position + (point - rect.position) / rect.size * source.size) / _texture.get_size())
	draw_polygon(points, PackedColorArray([tint]), uv, _texture)


func _arch(bottom: float = -1.0, inset: float = 0.0) -> PackedVector2Array:
	var w := size.x - inset * 2
	var h := size.y if bottom < 0 else bottom
	return PackedVector2Array([
		Vector2(inset, inset + size.y * 0.075), Vector2(inset + w * 0.18, inset + size.y * 0.035),
		Vector2(inset + w * 0.48, inset), Vector2(inset + w * 0.76, inset + size.y * 0.025),
		Vector2(size.x - inset, inset + size.y * 0.07), Vector2(size.x - inset, h - inset), Vector2(inset, h - inset)])


func _arch_rim(color: Color, width: float = 2.0, inset: float = 0.0) -> void:
	var points := _arch(-1, inset)
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _draw_portrait() -> void:
	var points := PackedVector2Array()
	if portrait_shape == "circle":
		for i in 48:
			points.append(size * 0.5 + Vector2.from_angle(TAU * i / 48.0) * minf(size.x, size.y) * 0.47)
	elif portrait_shape == "diamond":
		points = PackedVector2Array([Vector2(size.x * 0.5, 2), Vector2(size.x - 2, size.y * 0.5), Vector2(size.x * 0.5, size.y - 2), Vector2(2, size.y * 0.5)])
	else:
		points = PackedVector2Array([Vector2(2, 2), Vector2(size.x - 2, 2), size - Vector2(2, 2), Vector2(2, size.y - 2)])
	_art_polygon(points, Rect2(Vector2.ZERO, size))
	points.append(points[0])
	draw_polyline(points, ThemeBuilder.GOLD_BRIGHT if selected else Color("b7bbc4"), 3 if selected else 1.5, true)
	if hovered: draw_polyline(points, Color("ecddf7"), 2.5, true)


## 同一立绘在式神肖像和横向牌图中使用各自比例，按角色焦点保留脸部。
func art_source_rect(target_size: Vector2) -> Rect2:
	if _texture == null: return Rect2()
	var source := _texture.get_size()
	var ratio := maxf(target_size.x, 1.0) / maxf(target_size.y, 1.0)
	var crop := Vector2(source.y * ratio, source.y) if source.x / source.y > ratio else Vector2(source.x, source.x / ratio)
	var offset := (source - crop) / 2
	if _art_focus.x >= 0:
		offset = Vector2(clampf(source.x * _art_focus.x - crop.x / 2, 0, source.x - crop.x), clampf(source.y * _art_focus.y - crop.y / 2, 0, source.y - crop.y))
	else:
		offset.y *= 0.55 # 保留旧 SVG 的裁切位置。
	return Rect2(offset, crop)


func _vgradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _text(pos: Vector2, text: String, fs: int, color: Color, font: Font = null, width: float = -1, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color(0, 0, 0, 0.85)) -> void:
	var f := _font if font == null else font
	if outline > 0:
		draw_string_outline(f, pos, text, align, width, fs, outline, outline_color)
	draw_string(f, pos, text, align, width, fs, color)


func _center_text(y: float, text: String, fs: int, color: Color, font: Font = null, outline := 0) -> void:
	_text(Vector2(4, y), text, fs, color, font, size.x - 8, HORIZONTAL_ALIGNMENT_CENTER, outline)


func _number_font(value: String, preferred: int, width: float) -> int:
	var fs := preferred
	while fs > 1 and _bold.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width - 2:
		fs -= 1
	return fs


## 勾玉：圆首弯尾
func _magatama(c: Vector2, r: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * 0.5 + PI * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(c + Vector2(-r * 0.15, -r * 1.05))
	pts.append(c + Vector2(r * 0.75, -r * 1.55))
	pts.append(c + Vector2(r * 0.95, -r * 0.6))
	for i in range(0, 7):
		var a := -PI * 0.5 + PI * 0.5 * i / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var col := color if filled else Color(color.r, color.g, color.b, 0.0)
	draw_colored_polygon(pts, Color(0.05, 0.06, 0.1, 0.75) if not filled else col)
	pts.append(pts[0])
	draw_polyline(pts, Color(color, 0.95 if filled else 0.6), maxf(1.0, r * 0.22), true)
	draw_circle(c + Vector2(r * 0.1, -r * 0.05), r * 0.3, Color(0.08, 0.06, 0.04, 0.8) if filled else Color(color, 0.35))


## 鬼火费用球
func _cost_orb(c: Vector2, r: float, cost: int) -> void:
	draw_circle(c, r * 1.35, Color(0.4, 0.78, 1.0, 0.18))
	var flame := PackedVector2Array([c + Vector2(-r * 0.78, -r * 0.55), c + Vector2(-r * 0.2, -r * 1.75), c + Vector2(r * 0.1, -r * 1.1), c + Vector2(r * 0.55, -r * 1.55), c + Vector2(r * 0.8, -r * 0.5)])
	draw_colored_polygon(flame, Color("3c7fd6"))
	draw_circle(c, r, Color("163a6e"))
	draw_circle(c, r * 0.86, Color("2e6bc0"))
	draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.4, Color(0.75, 0.9, 1.0, 0.25))
	draw_arc(c, r, 0, TAU, 32, Color("a8dcff"), maxf(1.0, r * 0.12), true)
	var fs := int(r * 1.3)
	_text(c + Vector2(-r, fs * 0.36), str(cost), fs, Color.WHITE, _bold, r * 2, HORIZONTAL_ALIGNMENT_CENTER, maxi(2, int(r * 0.35)), Color("0b2140"))


## 圆形数值徽记（攻击 / 生命）
func _stat_badge(c: Vector2, r: float, value: String, fill: Color, rim: Color, text_color := Color.WHITE) -> void:
	draw_circle(c + Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.45))
	draw_circle(c, r, fill.darkened(0.25))
	draw_circle(c, r * 0.82, fill)
	draw_arc(c, r, 0, TAU, 28, rim, maxf(1.0, r * 0.14), true)
	var fs := _number_font(value, int(r * 1.25), r * 3)
	_text(c + Vector2(-r * 1.5, fs * 0.36), value, fs, text_color, _bold, r * 3, HORIZONTAL_ALIGNMENT_CENTER, maxi(2, int(r * 0.32)), Color(0, 0, 0, 0.8))


func _draw_back() -> void:
	var w := size.x
	var h := size.y
	draw_style_box(_box(Color("18323c"), Color("9eb9ae"), 2, 1, 0.25), Rect2(Vector2.ZERO, size))
	_vgradient(Rect2(2, 2, w - 4, h - 4), Color("496674"), Color("173342"))
	var moon := Vector2(w * 0.5, h * 0.27)
	for i in range(5, 0, -1):
		draw_circle(moon, w * (0.21 + i * 0.028), Color(0.95, 1.0, 0.76, 0.035))
	draw_circle(moon, w * 0.29, Color("eaf3ce"))
	draw_circle(moon + Vector2(w * 0.08, w * 0.08), w * 0.25, Color("567982"))
	# 月下青海波，细线沿卡背斜向交错。
	for i in 12:
		var y := h * 0.54 + i * h * 0.045
		draw_line(Vector2(2, y), Vector2(w - 2, minf(h - 3, y + h * 0.22)), Color(0.71, 0.87, 0.75, 0.36), maxf(0.7, w * 0.009), true)
		if y < h * 0.82:
			draw_arc(Vector2(w * 0.1, y + h * 0.23), w * 0.78, -PI * 0.58, -PI * 0.08, 24, Color(0.72, 0.86, 0.76, 0.25), 1, true)
	if note != "": _note_band(h * 0.9)


func _note_band(y: float) -> void:
	var fs := int(clampf(size.x * 0.075, 9, 13))
	draw_rect(Rect2(0, y - fs - 4, size.x, fs + 10), Color(0.03, 0.04, 0.08, 0.88))
	_center_text(y + 1, note, fs, ThemeBuilder.GOLD_BRIGHT, _bold)


func _draw_card() -> void:
	if _original_card != null:
		_draw_original_card()
		return
	var w := size.x
	var h := size.y
	var accent := ContentLoader.rarity_color(str(data.get("rarity", "common")))
	var mini := w < 90
	var pad := maxf(2.0, w * 0.025)
	var outline := _arch()
	var aura := play_aura_kind()
	_draw_play_aura(aura)
	# 原视频中的拱顶卡框、青灰银边和大幅插画。
	if aura.is_empty() and (selected or (playable and enabled)):
		for i in range(4, 0, -1):
			_arch_rim(Color(0.84, 0.88, 0.76, 0.05 + 0.03 * _pulse()), 2.0 + i * 2)
	draw_colored_polygon(outline, Color("767580"))
	var art_h := h * (0.66 if mini else 0.60)
	var art := Rect2(pad, pad, w - pad * 2, art_h - pad)
	_art_polygon(_arch(art_h, pad), art, Color.WHITE if enabled else Color(0.88, 0.89, 0.92))
	# 宣纸上沿呈弧形，卡名直接写在纸上。
	var paper_y := art_h - h * 0.018
	var paper := PackedVector2Array([Vector2(pad, paper_y + h * 0.025), Vector2(w * 0.26, paper_y), Vector2(w * 0.5, paper_y - h * 0.012), Vector2(w * 0.75, paper_y), Vector2(w - pad, paper_y + h * 0.025), Vector2(w - pad, h - pad), Vector2(pad, h - pad)])
	draw_colored_polygon(paper, Color("e6e8de"))
	for i in 6:
		draw_line(Vector2(pad + 3, paper_y + 10 + i * (h - paper_y - 15) / 6), Vector2(w - pad - 3, paper_y + 11 + i * (h - paper_y - 15) / 6), Color(0.38, 0.5, 0.47, 0.025), 1)
	var name_fs := int(clampf(w * 0.10, 9, 22))
	_center_text(paper_y + name_fs * 1.1, str(data.get("name", "?")), name_fs, Color("343943"), _display)
	# 勾玉费用与等级纹样位于上缘两侧。
	var orb_r := clampf(w * 0.07, 5, 14)
	var cost := int(data.get("payment", {}).get("cost", data.get("cost", 0)))
	for i in maxi(1, cost):
		_magatama(Vector2(pad + orb_r * 0.7 + i * orb_r * 1.1, h * 0.12), orb_r, Color("dadbae") if enabled else Color("a5acaa"), true)
	if cost == 0: _center_cost_zero(Vector2(pad + orb_r, h * 0.12), orb_r)
	_draw_card_marks(pad)
	var level := int(data.get("level", 1))
	for i in level:
		_gem(Vector2(w - pad - 7 - i * 8, h * 0.075), clampf(w * 0.028, 2, 5), Color("a2c9bb"))
	_gem(Vector2(w - pad - 7, paper_y + name_fs * 0.75), clampf(w * 0.027, 2, 5), accent)
	var bonus: Dictionary = data.get("awakeningBonus", {})
	if not bonus.is_empty():
		var labels: Array[String] = []
		if int(bonus.get("attack", 0)) != 0: labels.append("%+d力量" % int(bonus.attack))
		if int(bonus.get("hp", 0)) != 0: labels.append("%+d生命" % int(bonus.hp))
		_center_text(paper_y - 5, "  ".join(labels), int(clampf(w * 0.075, 9, 16)), Color("f2ddb1"), _bold, 3)
	if mini:
		_center_text(h - pad - 5, str(data.get("typeLabel", "")).left(2), 8, Color("616575"), _font)
	else:
		var body := Rect2(pad + w * 0.035, paper_y + name_fs * 1.5, w - pad * 2 - w * 0.07, h - paper_y - name_fs * 1.5 - maxf(15, h * 0.075))
		_draw_rules(body, str(data.get("text", "")))
		var owner := ContentLoader.unit_def(str(data.get("unitId", "")))
		_center_text(h - pad - 4, "%s · %s" % [owner.get("name", ""), str(data.get("typeLabel", ""))], int(clampf(w * 0.055, 7, 11)), Color("727785"), _font)
	_arch_rim(Color("aaa8b8"), 2)
	_arch_rim(Color(0.83, 0.85, 0.85, 0.55), 1, pad)
	if not aura.is_empty(): _arch_rim(Color("9aeaff") if aura == "instant" else Color("ffe89a"), 1.4)
	_finish_card()


func original_card_rect() -> Rect2:
	if _original_card == null: return Rect2(Vector2.ZERO, size)
	var scaled := _original_card.get_size() * minf(size.x / _original_card.get_width(), size.y / _original_card.get_height())
	return Rect2((size - scaled) * 0.5, scaled)


func _original_rim(color: Color, spread: float) -> void:
	var rect := original_card_rect()
	for i in 8:
		draw_texture_rect(_original_card, Rect2(rect.position + Vector2.from_angle(TAU * i / 8.0) * spread, rect.size), false, color)


func original_stat_changes() -> String:
	if data.has("currentCardStats"): return str(data.currentCardStats)
	var base := ContentLoader.card_def(str(data.get("id", "")))
	if data.get("type") == "combat" and int(data.get("value", 0)) != int(base.get("value", 0)):
		return "当前力量 %+d" % int(data.value)
	return ""


func _draw_original_card() -> void:
	var aura := play_aura_kind()
	_draw_play_aura(aura)
	if selected or (aura.is_empty() and playable and enabled):
		_original_rim(Color("e8dfb2", 0.6 + _pulse() * 0.2), 2.5)
	# 完整等比绘制，保留 PNG 透明边缘及每种牌型的原版轮廓。
	draw_texture_rect(_original_card, original_card_rect(), false, Color.WHITE if enabled else Color(0.70, 0.72, 0.77))
	if data.has("payment") or int(data.get("cost", 1)) != 1:
		_cost_orb(Vector2(size.x * 0.85, size.y * 0.10), clampf(size.x * 0.075, 5, 14), int(data.get("payment", {}).get("cost", data.get("cost", 1))))
	_draw_card_marks(maxf(2.0, size.x * 0.025))
	var changes := original_stat_changes()
	if not changes.is_empty():
		var fs := int(clampf(size.x * 0.085, 9, 16))
		var y := size.y * 0.57
		draw_style_box(_box(Color("25393f"), Color("f2d58c"), 3, 1), Rect2(3, y - fs, size.x - 6, fs + 7))
		_center_text(y + 1, changes, fs, Color("f2d58c"), _bold)
	var replacement: Array = data.get("effectReplacementText", [])
	if not replacement.is_empty():
		var paper := Rect2(size.x*0.09,size.y*0.66,size.x*0.82,size.y*0.29)
		draw_style_box(_box(Color("e6e7de"), Color("a8ab98"), 2, 1), paper)
		var fs := int(clampf(size.x*0.085,9,16))
		for i in replacement.size():
			_center_text(paper.position.y + fs*1.6 + i*(fs+5), str(replacement[i]), fs, Color("25393f"), _bold)
	if note != "": _note_band(size.y * 0.91)


func status_marks() -> Array:
	return BattleStatus.unit_marks(data, current_turn)


func _draw_card_marks(pad: float) -> void:
	var keywords: Array = data.get("keywords", [])
	var instant := keywords.any(func(k): return str(k).to_lower() == "instant")
	var payment: Dictionary = data.get("payment", {})
	var tags: Array = []
	if instant:
		var available: bool = payment.get("usesInstant", false)
		tags.append(["instant", "瞬发" if payment.is_empty() else (("瞬发·发动" if payment.get("applied", false) else "瞬发·可用") if available else "瞬发·已用" if payment.instantUsed else "瞬发·待机"), Color("9ee8cd") if payment.is_empty() or available else Color("a6aab4")])
	elif payment.get("usesSwift",false):tags.append(["swift-card","疾速·消耗出击",Color("9ed5e8")])
	elif not payment.is_empty() and int(payment.cost) == 0: tags.append(["free", "免鬼火", Color("cce5ca")])
	if not str(data.get("autoResponse", "")).is_empty() or data.get("timing", "main") == "response": tags.append(["response", "响应", Color("ccb3e7")])
	if data.get("enhanced", false): tags.append(["enhanced", "已增强", Color("f2d58c")])
	if data.get("inspiredSupport", false): tags.append(["inspired", "昂扬", Color("ffda70")])
	var fs := int(clampf(size.x * 0.075, 8, 14))
	for i in tags.size():
		var tag: Array = tags[i]
		var width := minf(size.x - pad * 2, fs * str(tag[1]).length() + fs * 2.2)
		var rect := Rect2(pad, size.y * 0.205 + i * (fs + 7), width, fs + 5)
		draw_style_box(_box(Color("25393f"), Color(tag[2], 0.65), 3, 1), rect)
		BattleStatus.draw_symbol(self, rect.position + Vector2(fs * 0.65, rect.size.y * 0.5), fs * 0.45, tag[0], tag[2])
		_text(rect.position + Vector2(fs * 1.4, fs + 1), tag[1], fs, tag[2], _bold)


func _draw_status_badge(rect: Rect2, mark: Dictionary) -> void:
	var color: Color = mark.color
	draw_circle(rect.get_center(), rect.size.x * 0.51, Color("17232f"))
	draw_arc(rect.get_center(), rect.size.x * 0.51, 0, TAU, 24, color, 1.2, true)
	if mark.id == "overflow":
		_text(rect.position + Vector2(-2, rect.size.y * 0.73), mark.label, 11, color, _bold, rect.size.x + 4, HORIZONTAL_ALIGNMENT_CENTER, 1)
		return
	BattleStatus.draw_symbol(self, rect.get_center(), rect.size.x * 0.29, mark.id, color)
	if int(mark.value) >= 0:
		var at := rect.end + Vector2(-3, -2)
		draw_circle(at, 7, Color("18202b"))
		_text(at + Vector2(-11, 4), str(mark.value), _number_font(str(mark.value), 10, 22), Color.WHITE, _bold, 22, HORIZONTAL_ALIGNMENT_CENTER, 1)


func _center_cost_zero(at: Vector2, radius: float) -> void:
	_text(at + Vector2(-radius, radius * 0.4), "0", int(radius * 1.25), Color("e9eaca"), _bold, radius * 2, HORIZONTAL_ALIGNMENT_CENTER, 1)


func _finish_card() -> void:
	# 不可用牌保持插画可辨，使用费用灰色与轻遮罩表达状态。
	if not enabled: draw_colored_polygon(_arch(), Color(0.14, 0.16, 0.22, 0.09))
	if note != "": _note_band(size.y * 0.91)
	if selected: _arch_rim(Color("e8dfb2"), 3)


func _gem(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c]), color.lightened(0.4))


func _keyword_names(keywords: Array) -> String:
	var out: PackedStringArray = []
	for k in keywords:
		var name := KeywordGlossary.label(str(k))
		if name != "": out.append(name)
		if out.size() >= 2: break
	return "·".join(out)


## 规则正文：逐字号试排，保证完整落在文本框内
func _draw_rules(rect: Rect2, text: String) -> void:
	if text == "" or rect.size.x < 10: return
	var key := "%s|%d|%d" % [text, int(rect.size.x), int(rect.size.y)]
	if key != _para_cache_key:
		_para_cache_key = key
		var max_fs := int(clampf(size.x * 0.082, 9, 15))
		var min_fs := mini(max_fs, 8)
		for fs in range(max_fs, min_fs - 1, -1):
			_para_size = fs
			_para_lines = _wrap(text, rect.size.x, fs)
			if _para_lines.size() * (fs + _line_gap(fs)) - _line_gap(fs) <= rect.size.y:
				break
	var fs := _para_size
	var max_lines := maxi(1, int((rect.size.y + _line_gap(fs)) / (fs + _line_gap(fs))))
	var color := Color("3a3022") if enabled else Color("5a554c")
	for i in mini(_para_lines.size(), max_lines):
		var line: String = _para_lines[i]
		if i == max_lines - 1 and _para_lines.size() > max_lines:
			line = line.left(maxi(0, line.length() - 1)) + "…"
		_text(rect.position + Vector2(0, fs + i * (fs + _line_gap(fs)) - 1), line, fs, color)


func _line_gap(fs: int) -> int:
	return maxi(2, int(fs * 0.3))


func _wrap(text: String, width: float, fs: int) -> Array:
	var lines: Array = []
	var line := ""
	for ch in text:
		if ch == "\n":
			lines.append(line)
			line = ""
			continue
		if line != "" and _font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			# 避头标点：不让标点落在行首
			if "，。；：、）」』！？".contains(ch):
				line += ch
				lines.append(line)
				line = ""
				continue
			lines.append(line)
			line = ""
		line += ch
	if line != "": lines.append(line)
	return lines


func _draw_unit() -> void:
	var w := size.x
	var h := size.y
	var r := _radius()
	var knocked := int(data.get("knockout", 0)) > 0 or (data.has("hp") and int(data.get("hp", 1)) <= 0 and data.has("uid"))
	var frame := ThemeBuilder.ALLY if side == 0 else (ThemeBuilder.FOE if side == 1 else ContentLoader.unit_color(data))
	var aura := play_aura_kind()
	_draw_play_aura(aura, true)
	if selected:
		_glow(ThemeBuilder.GOLD_BRIGHT, _pulse(), 10)
	elif playable and aura.is_empty():
		_glow(Color("a0d5ff"), _pulse(), 6)
	if int(data.get("shield", 0)) > 0:
		_glow(Color("7cc0ff"), 0.9, 5)
	draw_style_box(_box(Color("101119"), frame.darkened(0.1), r, 2, 0.55), Rect2(Vector2.ZERO, size))
	var pad := maxf(2.5, w * 0.03)
	var art := Rect2(pad, pad, w - pad * 2, h - pad * 2)
	var tint := Color.WHITE
	if knocked: tint = Color(0.38, 0.38, 0.42)
	elif not enabled: tint = Color(0.6, 0.6, 0.66)
	_draw_art(art, tint)
	_vgradient(Rect2(art.position.x, art.end.y - h * 0.42, art.size.x, h * 0.42), Color(0.04, 0.04, 0.07, 0.0), Color(0.04, 0.04, 0.07, 0.63))
	_vgradient(Rect2(art.position.x, art.position.y, art.size.x, h * 0.2), Color(0.04, 0.04, 0.07, 0.16), Color(0.04, 0.04, 0.07, 0.0))
	if data.get("awakened", false):
		var aw := _box(Color.TRANSPARENT, Color(ThemeBuilder.TYPE_AWAKEN, 0.8), maxi(2, r - 2), 1)
		aw.draw_center = false
		draw_style_box(aw, art)
	# 勾玉
	var level := int(data.get("level", 0))
	var mr := clampf(w * 0.045, 3.0, 6.5)
	var max_level := int(ContentLoader.rules().get("maxUnitLevel", 3))
	if data.has("uid") or level > 0:
		for i in max_level:
			_magatama(Vector2(pad + mr * 1.9 + i * mr * 2.9, pad + mr * 2.9), mr, ThemeBuilder.GOLD_BRIGHT, i < level)
	# 名字
	var name_fs := int(clampf(w * 0.12, 10, 20))
	var stat_r := clampf(w * 0.12, 9, 19)
	if side >= 0:
		var flag_x := w - 13
		draw_rect(Rect2(flag_x, h * 0.32, 19, h * 0.42), Color("746354") if side == 0 else Color("655975"))
		var unit_name := str(data.get("name", "?"))
		for i in mini(unit_name.length(), 5):
			_text(Vector2(flag_x + 3, h * 0.32 + 14 + i * 13), unit_name[i], 11, ThemeBuilder.PAPER, _display, -1, HORIZONTAL_ALIGNMENT_LEFT, 1)
	else:
		_center_text(h - pad - stat_r * 2.1, str(data.get("name", "?")), name_fs, ThemeBuilder.PAPER, _display, 2)
	# 攻 / 命
	var atk := int(data.get("attack", 0))
	var hp := int(data.get("hp", data.get("maxHp", 0)))
	var max_hp := int(data.get("maxHp", hp))
	var base_atk := int(data.get("baseAttack", atk))
	_stat_badge(Vector2(pad + stat_r * 1.05, h - pad - stat_r * 1.0), stat_r, str(atk), Color("4a7856"), Color("d9edc2"), Color("f1ffe9") if atk <= base_atk else Color("b6ffb8"))
	_stat_badge(Vector2(w - pad - stat_r * 1.05, h - pad - stat_r * 1.0), stat_r, str(hp), Color("a8303a"), Color("f2a3a0"), Color.WHITE if hp >= max_hp else Color("ffc2b5"))
	var shield := int(data.get("shield", 0))
	if shield > 0:
		var sc := Vector2(w - pad - stat_r * 1.05, h - pad - stat_r * 3.05)
		var sr := stat_r * 0.78
		var pts := PackedVector2Array([sc + Vector2(-sr, -sr * 0.9), sc + Vector2(sr, -sr * 0.9), sc + Vector2(sr, sr * 0.1), sc + Vector2(0, sr * 1.1), sc + Vector2(-sr, sr * 0.1)])
		draw_colored_polygon(pts, Color("2f6fb0"))
		pts.append(pts[0])
		draw_polyline(pts, Color("bfe3ff"), 1.5, true)
		var shield_fs := _number_font(str(shield), int(sr * 1.25), sr * 3)
		_text(sc + Vector2(-sr * 1.5, sr * 0.45), str(shield), shield_fs, Color.WHITE, _bold, sr * 3, HORIZONTAL_ALIGNMENT_CENTER, 2, Color("0d2440"))
	var marks := status_marks()
	for mark in marks:
		if mark.id == "countdown" and mark.active:
			_countdown_badge(Vector2(w - pad - 9, pad + 13), clampf(w * 0.105, 9, 14), int(mark.value))
	for badge in BattleStatus.badge_layout(marks, size):
		_draw_status_badge(badge.rect, badge.mark)
	if knocked:
		draw_style_box(_box(Color(0.05, 0.04, 0.09, 0.55), Color.TRANSPARENT, r, 0), Rect2(Vector2.ZERO, size))
		var kfs := int(clampf(w * 0.17, 12, 26))
		_center_text(h * 0.72, "幽魂" if data.get("samuraiGhost",false) else ("永久气绝" if data.get("catCannotRevive",false) else "气绝"), kfs, Color("e8e2ee"), _display, 4)
		var turns := int(data.get("knockout", 0))
		if turns>0 or data.get("catCannotRevive",false) or data.get("samuraiCannotRevive",false):
			var counter := Vector2(w * 0.5, h * 0.40)
			BattleStatus.draw_symbol(self, counter, clampf(w * 0.27, 22, 36), "knockout", Color("9470c4"))
			_text(counter + Vector2(-25, 10), "∞" if data.get("catCannotRevive",false) or data.get("samuraiCannotRevive",false) else str(turns), int(clampf(w * 0.30, 24, 38)), Color("fff8d9"), _bold, 50, HORIZONTAL_ALIGNMENT_CENTER, 3)
	if note != "":
		_note_band(h * 0.6)
	if selected:
		var sb := _box(Color.TRANSPARENT, ThemeBuilder.GOLD_BRIGHT, r, 3)
		sb.draw_center = false
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
	elif hovered:
		var sb := _box(Color.TRANSPARENT, Color(1, 0.95, 0.8, 0.7), r, 2)
		sb.draw_center = false
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


# ——————————————————————————— 拖放 ———————————————————————————

func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty(): return null
	var preview := get_script().new() as Control
	preview.data = data
	preview.unit_mode = unit_mode
	preview.side = side
	preview.current_turn = current_turn
	preview.size = size * 1.05
	preview.custom_minimum_size = size * 1.05
	preview.modulate.a = 0.9
	preview.rotation = -0.06
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -size * 0.52
	set_drag_preview(holder)
	modulate.a = 0.35
	return drag_payload.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0


func _can_drop_data(_at_position: Vector2, payload: Variant) -> bool:
	return payload is Dictionary and drop_check.is_valid() and drop_check.call(payload)


func _drop_data(_at_position: Vector2, payload: Variant) -> void:
	if drop_action.is_valid(): drop_action.call(payload)


func _countdown_badge(center: Vector2, radius: float, remaining: int) -> void:
	# Pink hourglass silhouette visible in the reference recording. The number
	# comes from the rule timer; the renderer never advances it itself.
	var pts := PackedVector2Array()
	for point in [Vector2(-1, -1.25), Vector2(1, -1.25), Vector2(0.8, -0.83), Vector2(0.35, 0), Vector2(0.8, 0.83), Vector2(1, 1.25), Vector2(-1, 1.25), Vector2(-0.8, 0.83), Vector2(-0.35, 0), Vector2(-0.8, -0.83)]:
		pts.append(center + point * radius)
	draw_colored_polygon(pts, Color("b85f8d"))
	pts.append(pts[0])
	draw_polyline(pts, Color("683e5f"), 2, true)
	for direction in [-1, 1]:
		draw_line(center + Vector2(-radius, direction * radius * 1.25), center + Vector2(radius, direction * radius * 1.25), Color("d69bb8"), 2, true)
	_text(center + Vector2(-radius * 1.4, radius * 0.66), str(remaining), int(radius * 1.9), Color("f6e3db"), _bold, radius * 2.8, HORIZONTAL_ALIGNMENT_CENTER, 2, Color("503543"))
