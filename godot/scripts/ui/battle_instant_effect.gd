extends Control
## 支付后的一次性额度提示。只接收展示数据，不读取或改写规则状态。
const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
const Status := preload("res://scripts/ui/battle_status.gd")
const DURATION := 0.72
const MINT := Color("9ee8cd")
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var caption_offset := Vector2(16, -24)
var cost := 0
var elapsed := 0.0
var _caption: PanelContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("instant_feedback", true)
	_caption = PanelContainer.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263f43")
	style.border_color = Color(MINT, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_caption.add_theme_stylebox_override("panel", style)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 1)
	var title := ThemeBuilder.bold_label("瞬发发动 · 本次 %d 鬼火" % cost, 13, MINT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(title)
	var detail := ThemeBuilder.label("本回合额度已用", 11, Color("d0dfd9"))
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(detail)
	_caption.add_child(lines)
	add_child(_caption)
	_update_caption()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		set_process(false)
		return
	_update_caption()
	queue_redraw()

func _update_caption() -> void:
	var fade := clampf(elapsed / 0.08, 0.0, 1.0) * clampf((DURATION - elapsed) / 0.18, 0.0, 1.0)
	_caption.modulate.a = fade
	_caption.position = destination + caption_offset + Vector2(0, -5 * clampf(elapsed / DURATION, 0.0, 1.0))

func _draw() -> void:
	# A short thread joins the played hand/source to the shared allowance.
	var travel := clampf(elapsed / 0.20, 0.0, 1.0)
	if travel < 1.0:
		var points := PackedVector2Array()
		for i in 20:
			var t := lerpf(maxf(0.0, travel - 0.24), travel, i / 19.0)
			points.append(origin.lerp(destination, t) + Vector2(0, -sin(PI * t) * 34))
		draw_polyline(points, Color(MINT, 0.2), 7, true)
		draw_polyline(points, Color(MINT, 0.85), 1.6, true)
	var t := clampf(elapsed / DURATION, 0.0, 1.0)
	var alpha := clampf(elapsed / 0.08, 0.0, 1.0) * (1.0 - t)
	var radius := 12 + 20 * t
	for i in 3:
		var angle := TAU * i / 3.0 + t * 1.2
		draw_arc(destination, radius, angle, angle + 1.35, 20, Color(MINT, alpha * 0.7), 1.5, true)
	Status.draw_symbol(self, destination, 9, "instant", Color(MINT, alpha))
