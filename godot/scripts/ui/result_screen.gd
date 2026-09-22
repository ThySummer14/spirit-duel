class_name ResultScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
## Victory / defeat with seal-like stamp.

signal rematch
signal back_to_menu

var _victory := true
var _summary := ""


func setup(victory: bool, summary: String) -> void:
	_victory = victory
	_summary = summary


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_0
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var stamp := _make_stamp()
	col.add_child(stamp)

	var title := ThemeBuilder.title_label("胜 利" if _victory else "败 北", 40)
	title.add_theme_color_override("font_color", ThemeBuilder.GOLD_BRIGHT if _victory else ThemeBuilder.DANGER_SOFT)
	col.add_child(title)

	var summary := ThemeBuilder.dim_label(_summary, 14)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(480, 0)
	col.add_child(summary)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	col.add_child(h)
	var again := ThemeBuilder.rounded_rect_button("再战一局", Vector2(200, 48))
	again.pressed.connect(func(): rematch.emit())
	h.add_child(again)
	var menu := ThemeBuilder.rounded_rect_button("回到主菜单", Vector2(200, 48))
	menu.pressed.connect(func(): back_to_menu.emit())
	h.add_child(menu)

	# stamp drop-in
	stamp.pivot_offset = stamp.size / 2.0
	stamp.scale = Vector2(1.6, 1.6)
	stamp.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.35)


func _make_stamp() -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(160, 160)
	var color := ThemeBuilder.DANGER if _victory else ThemeBuilder.FOE
	var ring := PanelContainer.new()
	ring.custom_minimum_size = Vector2(150, 150)
	ring.set_anchors_preset(Control.PRESET_CENTER)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(75)
	ring.add_theme_stylebox_override("panel", sb)
	box.add_child(ring)
	var l := ThemeBuilder.label("胜" if _victory else "负", 56, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(l)
	# rotated stamp feel
	box.rotation_degrees = -8.0
	return box
