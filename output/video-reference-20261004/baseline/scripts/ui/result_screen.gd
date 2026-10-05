class_name ResultScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
## Victory / defeat with seal-like stamp.

signal rematch
signal back_to_menu

var _victory := true
var _summary := ""
var _commands: Array = []


func setup(victory: bool, summary: String, commands: Array = []) -> void:
	_victory = victory
	_summary = summary
	_commands = commands


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

	var stamp_wrap := CenterContainer.new()
	var stamp := _make_stamp()
	stamp_wrap.add_child(stamp)
	col.add_child(stamp_wrap)

	var title := ThemeBuilder.title_label("胜 利" if _victory else "败 北", 40)
	title.add_theme_color_override("font_color", ThemeBuilder.GOLD_BRIGHT if _victory else ThemeBuilder.DANGER_SOFT)
	col.add_child(title)

	var summary := ThemeBuilder.dim_label(_summary, 14)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(480, 0)
	col.add_child(summary)

	if not _commands.is_empty():
		var cmd_box := PanelContainer.new()
		cmd_box.custom_minimum_size = Vector2(520, 140)
		cmd_box.add_theme_stylebox_override("panel", ThemeBuilder.panel(ThemeBuilder.INK_2, ThemeBuilder.RULE, 8, 1))
		var cv := VBoxContainer.new()
		cmd_box.add_child(cv)
		cv.add_child(ThemeBuilder.label("命令日志（%d）" % _commands.size(), 12, ThemeBuilder.GOLD))
		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = false
		rl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rl.custom_minimum_size = Vector2(0, 110)
		var lines := PackedStringArray()
		for i in mini(_commands.size(), 80):
			var c = _commands[i]
			lines.append("#%d %s p%s" % [i + 1, str(c.get("c", "?")), str(c.get("p", ""))])
		rl.text = "\n".join(lines)
		cv.add_child(rl)
		col.add_child(cmd_box)

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
	var color := ThemeBuilder.DANGER if _victory else ThemeBuilder.FOE
	var ring := PanelContainer.new()
	ring.custom_minimum_size = Vector2(120, 120)
	ring.pivot_offset = Vector2(60, 60)
	ring.rotation_degrees = -8.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(60)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	ring.add_theme_stylebox_override("panel", sb)
	var center := CenterContainer.new()
	var l := ThemeBuilder.label("胜" if _victory else "负", 48, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(l)
	ring.add_child(center)
	return ring
