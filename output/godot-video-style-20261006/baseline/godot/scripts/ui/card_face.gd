extends Control
## 卡面绘制：行动牌（含正文）、式神肖像（攻/命/勾玉/状态）与卡背。
## 只负责外观与悬停/受击等表现；规则与点击逻辑由所属界面处理。

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const ContentLoader := preload("res://scripts/content_loader.gd")
const PortraitLibrary := preload("res://scripts/ui/portrait_library.gd")
const KeywordGlossary := preload("res://scripts/ui/keyword_glossary.gd")
static var _textures: Dictionary = {}

signal hover_changed(hovering: bool)

var data: Dictionary = {}
var unit_mode := false
var face_down := false
var selected := false
var enabled := true
## 可打出/可操作时的呼吸光
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
	var unit := data if unit_mode else ContentLoader.unit_def(str(data.get("unitId", "")))
	if unit_mode and not unit.has("art"):
		unit = ContentLoader.unit_def(str(data.get("id", "")))
	var awakened: bool = data.get("awakened", false) or data.get("type", "") == "awakening"
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
		_draw_unit()
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


func _draw_art(rect: Rect2, tint: Color = Color.WHITE) -> void:
	if _texture == null:
		draw_rect(rect, Color("1d2333"))
		return
	draw_texture_rect_region(_texture, rect, art_source_rect(rect.size), tint)


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
	var fs := int(r * 1.25)
	_text(c + Vector2(-r * 1.5, fs * 0.36), value, fs, text_color, _bold, r * 3, HORIZONTAL_ALIGNMENT_CENTER, maxi(2, int(r * 0.32)), Color(0, 0, 0, 0.8))


func _draw_back() -> void:
	var w := size.x
	var h := size.y
	draw_style_box(_box(Color("16223a"), Color("c9a45e"), _radius(), maxi(1, int(w * 0.025)), 0.4), Rect2(Vector2.ZERO, size))
	var inset := Rect2(Vector2.ONE * w * 0.07, size - Vector2.ONE * w * 0.14)
	_vgradient(inset, Color("1f3356"), Color("101a2e"))
	for i in 6:
		draw_arc(Vector2(w * 0.5, h * 0.84), w * (0.12 + i * 0.075), PI, TAU, 32, Color(0.85, 0.75, 0.5, 0.13), 1.0, true)
	var moon := Vector2(w * 0.5, h * 0.42)
	draw_circle(moon, w * 0.27, Color(0.95, 0.85, 0.55, 0.08))
	draw_circle(moon, w * 0.2, Color("e9d6a0"))
	draw_circle(moon + Vector2(w * 0.08, -w * 0.06), w * 0.18, Color("1c2d4c"))
	for i in 5:
		var p := Vector2(w * (0.2 + 0.15 * i), h * (0.16 + 0.05 * ((i * 7) % 3)))
		draw_circle(p, maxf(0.8, w * 0.012), Color(1, 0.92, 0.7, 0.6))
	var sb := _box(Color.TRANSPARENT, Color(0.85, 0.7, 0.4, 0.5), maxi(2, _radius() - 3), 1)
	sb.draw_center = false
	draw_style_box(sb, inset)
	if note != "":
		_note_band(h * 0.86)


func _note_band(y: float) -> void:
	var fs := int(clampf(size.x * 0.075, 9, 13))
	draw_rect(Rect2(0, y - fs - 4, size.x, fs + 10), Color(0.03, 0.04, 0.08, 0.88))
	_center_text(y + 1, note, fs, ThemeBuilder.GOLD_BRIGHT, _bold)


func _draw_card() -> void:
	var w := size.x
	var h := size.y
	var rarity := str(data.get("rarity", "common"))
	var accent := ContentLoader.rarity_color(rarity)
	var type_color := ContentLoader.type_color(str(data.get("type", "")))
	var mini := w < 90
	var pad := maxf(3.0, w * 0.04)
	var r := _radius()
	if selected:
		_glow(ThemeBuilder.GOLD_BRIGHT, _pulse(), 9)
	elif playable and enabled:
		_glow(Color("7de3b5"), _pulse(), 8)
	draw_style_box(_box(Color("14131b"), accent.darkened(0.15), r, 2 if w >= 100 else 1, 0.5), Rect2(Vector2.ZERO, size))
	var art_h := h * (0.66 if mini else 0.5)
	var art := Rect2(pad, pad, w - pad * 2, art_h)
	_draw_art(art, Color.WHITE if enabled else Color(0.5, 0.5, 0.56))
	_vgradient(Rect2(art.position.x, art.end.y - art_h * 0.34, art.size.x, art_h * 0.34), Color(0.08, 0.075, 0.1, 0.0), Color(0.08, 0.075, 0.1, 0.92))
	# 卡名
	var name_fs := int(clampf(w * 0.098, 9, 19))
	_center_text(art.end.y - name_fs * 0.35, str(data.get("name", "?")), name_fs, ThemeBuilder.PAPER, _display, 3)
	# 费用 + 勾玉需求
	var orb_r := clampf(w * 0.095, 7, 15)
	_cost_orb(Vector2(pad + orb_r * 0.95, pad + orb_r * 1.05), orb_r, int(data.get("cost", 0)))
	var level := int(data.get("level", 1))
	var mr := clampf(w * 0.032, 2.5, 5.0)
	var mx := w - pad - mr * 1.6
	if level > 0:
		draw_style_box(_box(Color(0.03, 0.04, 0.07, 0.72), Color.TRANSPARENT, int(mr * 2), 0), Rect2(mx - (level - 1) * mr * 2.8 - mr * 1.9, pad + 2, (level - 1) * mr * 2.8 + mr * 3.8, mr * 4.6))
	for i in level:
		_magatama(Vector2(mx - i * mr * 2.8, pad + mr * 3.0), mr, ThemeBuilder.GOLD_BRIGHT, true)
	if mini:
		var strip := Rect2(pad, art.end.y + 2, w - pad * 2, h - art.end.y - pad - 2)
		draw_rect(strip, type_color.darkened(0.55))
		_center_text(strip.position.y + strip.size.y * 0.5 + 4, str(data.get("typeLabel", "")).left(2), int(clampf(w * 0.13, 8, 11)), type_color.lightened(0.4), _bold)
		_finish_card()
		return
	# 类型条
	var strip_h := clampf(w * 0.105, 12, 20)
	var strip_y := art.end.y + 1
	draw_rect(Rect2(pad, strip_y, w - pad * 2, strip_h), Color(type_color.r, type_color.g, type_color.b, 0.22))
	draw_rect(Rect2(pad, strip_y, 3, strip_h), type_color)
	var tfs := int(clampf(w * 0.068, 8, 12))
	var type_text := str(data.get("typeLabel", ""))
	if data.get("keywords") is Array and not (data.keywords as Array).is_empty():
		type_text += " · " + _keyword_names(data.keywords)
	_text(Vector2(pad + 7, strip_y + strip_h * 0.5 + tfs * 0.38), type_text, tfs, type_color.lightened(0.45), _bold, w - pad * 2 - 30)
	_gem(Vector2(w - pad - strip_h * 0.55, strip_y + strip_h * 0.5), strip_h * 0.3, accent)
	# 正文
	var body := Rect2(pad + 1, strip_y + strip_h + 3, w - pad * 2 - 2, h - strip_y - strip_h - pad - 4)
	draw_style_box(_box(Color("ece4cf") if enabled else Color("b9b3a3"), Color.TRANSPARENT, maxi(2, r - 3), 0), body)
	_draw_rules(body.grow(-maxf(3.0, w * 0.035)), str(data.get("text", "")))
	_finish_card()


func _finish_card() -> void:
	if not enabled:
		draw_style_box(_box(Color(0.03, 0.035, 0.06, 0.38), Color.TRANSPARENT, _radius(), 0), Rect2(Vector2.ZERO, size))
	if note != "":
		_note_band(size.y * (0.66 if size.x < 90 else 0.5) + maxf(3.0, size.x * 0.04) - 2)
	if selected:
		var sb := _box(Color.TRANSPARENT, ThemeBuilder.GOLD_BRIGHT, _radius(), 3)
		sb.draw_center = false
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


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
	if selected:
		_glow(ThemeBuilder.GOLD_BRIGHT, _pulse(), 10)
	elif playable:
		_glow(Color("7de3b5"), _pulse(), 8)
	if int(data.get("shield", 0)) > 0:
		_glow(Color("7cc0ff"), 0.9, 5)
	draw_style_box(_box(Color("101119"), frame.darkened(0.1), r, 2, 0.55), Rect2(Vector2.ZERO, size))
	var pad := maxf(2.5, w * 0.03)
	var art := Rect2(pad, pad, w - pad * 2, h - pad * 2)
	var tint := Color.WHITE
	if knocked: tint = Color(0.38, 0.38, 0.42)
	elif not enabled: tint = Color(0.6, 0.6, 0.66)
	_draw_art(art, tint)
	_vgradient(Rect2(art.position.x, art.end.y - h * 0.42, art.size.x, h * 0.42), Color(0.04, 0.04, 0.07, 0.0), Color(0.04, 0.04, 0.07, 0.95))
	_vgradient(Rect2(art.position.x, art.position.y, art.size.x, h * 0.2), Color(0.04, 0.04, 0.07, 0.55), Color(0.04, 0.04, 0.07, 0.0))
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
	_center_text(h - pad - stat_r * 2.1, str(data.get("name", "?")), name_fs, ThemeBuilder.PAPER, _display, 3)
	# 攻 / 命
	var atk := int(data.get("attack", 0))
	var hp := int(data.get("hp", data.get("maxHp", 0)))
	var max_hp := int(data.get("maxHp", hp))
	var base_atk := int(data.get("baseAttack", atk))
	_stat_badge(Vector2(pad + stat_r * 1.05, h - pad - stat_r * 1.0), stat_r, str(atk), Color("b9822c"), Color("f2d38c"), Color("fff3cf") if atk <= base_atk else Color("b6ffb8"))
	_stat_badge(Vector2(w - pad - stat_r * 1.05, h - pad - stat_r * 1.0), stat_r, str(hp), Color("a8303a"), Color("f2a3a0"), Color.WHITE if hp >= max_hp else Color("ffc2b5"))
	var shield := int(data.get("shield", 0))
	if shield > 0:
		var sc := Vector2(w - pad - stat_r * 1.05, h - pad - stat_r * 3.05)
		var sr := stat_r * 0.78
		var pts := PackedVector2Array([sc + Vector2(-sr, -sr * 0.9), sc + Vector2(sr, -sr * 0.9), sc + Vector2(sr, sr * 0.1), sc + Vector2(0, sr * 1.1), sc + Vector2(-sr, sr * 0.1)])
		draw_colored_polygon(pts, Color("2f6fb0"))
		pts.append(pts[0])
		draw_polyline(pts, Color("bfe3ff"), 1.5, true)
		_text(sc + Vector2(-sr * 1.5, sr * 0.45), str(shield), int(sr * 1.25), Color.WHITE, _bold, sr * 3, HORIZONTAL_ALIGNMENT_CENTER, 2, Color("0d2440"))
	# 状态徽记（右上竖排）
	var badges: Array = []
	for pair in [["frozen", "晕", Color("9d82d4")], ["charge", "充", Color("4fb6c9")], ["armorBreak", "破", Color("d9733a")], ["brittle", "裂", Color("c95f7a")]]:
		if int(data.get(pair[0], 0)) > 0: badges.append([pair[1], int(data[pair[0]]), pair[2]])
	if data.get("unyielding", false): badges.append(["屈", 0, Color("d9b56a")])
	var bs := clampf(w * 0.17, 12, 22)
	for i in mini(badges.size(), 4):
		var b: Array = badges[i]
		var rect := Rect2(w - pad - bs - 1, pad + 2 + i * (bs + 2), bs, bs)
		draw_style_box(_box(Color(b[2]).darkened(0.35), Color(b[2]).lightened(0.3), int(bs * 0.3), 1), rect)
		var label := str(b[0]) if int(b[1]) <= 1 else "%s%d" % [b[0], int(b[1])]
		var fs := int(bs * (0.62 if label.length() == 1 else 0.48))
		_text(Vector2(rect.position.x - 4, rect.position.y + bs * 0.5 + fs * 0.38), label, fs, Color.WHITE, _bold, bs + 8, HORIZONTAL_ALIGNMENT_CENTER, 2, Color(0, 0, 0, 0.6))
	if knocked:
		draw_style_box(_box(Color(0.05, 0.04, 0.09, 0.55), Color.TRANSPARENT, r, 0), Rect2(Vector2.ZERO, size))
		var kfs := int(clampf(w * 0.17, 12, 26))
		_center_text(h * 0.47, "气绝", kfs, Color("e8e2ee"), _display, 4)
		var turns := int(data.get("knockout", 0))
		if turns > 0:
			_center_text(h * 0.47 + kfs, "%d 回合后归队" % turns, int(kfs * 0.5), Color("cfc6dc"), _font, 3)
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
