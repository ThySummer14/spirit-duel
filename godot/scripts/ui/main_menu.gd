class_name MainMenuScreen
extends Control

const ThemeBuilder := preload("res://scripts/ui/theme_builder.gd")
## 灵枢战线 main menu — 墨夜和风

signal start_quick_match
signal open_formation
signal open_settings
signal quit_requested


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.INK_0
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var deco := _decorative_glow()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(deco)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var title := ThemeBuilder.title_label("灵枢战线", 52)
	title.add_theme_color_override("font_color", ThemeBuilder.GOLD_BRIGHT)
	col.add_child(title)

	var subtitle := ThemeBuilder.dim_label("Hyakumonogatari-style duel · 纵向切片", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	var seal := ThemeBuilder.chip("墨夜和风", ThemeBuilder.GOLD)
	var seal_wrap := CenterContainer.new()
	seal_wrap.add_child(seal)
	col.add_child(seal_wrap)

	col.add_child(ThemeBuilder.hline())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)

	for pair in [
		["快速对战", start_quick_match],
		["编成", open_formation],
		["设置", open_settings],
		["退出", quit_requested],
	]:
		var b := ThemeBuilder.rounded_rect_button(pair[0] as String, Vector2(280, 52))
		b.pressed.connect(func(): (pair[1] as Signal).emit())
		col.add_child(b)

	var hint := ThemeBuilder.dim_label("Enter 结束回合 · 1-9 出牌 · Tab 切换角色", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _decorative_glow() -> Control:
	var c := Control.new()
	c.draw.connect(func():
		var r := c.get_rect()
		var p := PackedVector2Array([
			Vector2(0, 0), Vector2(r.size.x, 0),
			Vector2(r.size.x, r.size.y * 0.22), Vector2(0, r.size.y * 0.22)
		])
		c.draw_colored_polygon(p, Color(0.08, 0.1, 0.16, 0.9))
		var p2 := PackedVector2Array([
			Vector2(0, r.size.y * 0.78), Vector2(r.size.x, r.size.y * 0.78),
			Vector2(r.size.x, r.size.y), Vector2(0, r.size.y)
		])
		c.draw_colored_polygon(p2, Color(0.05, 0.07, 0.12, 0.85))
	)
	return c
